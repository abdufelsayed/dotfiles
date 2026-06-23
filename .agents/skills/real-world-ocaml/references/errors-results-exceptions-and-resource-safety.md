# Errors, Results, Exceptions, And Resource Safety
## Core Judgment
In OCaml, error handling is API design. Pick the failure mechanism that matches the caller's job and keep that choice stable inside the boundary:
- `option` for benign absence
- `('a, 'e) result` for expected failure the caller should branch on
- `Or_error.t` for Base/Core code that wants structured, composable errors quickly
- exceptions for bugs, violated invariants, impossible states, or deliberately exceptional boundary failures
The common agent mistake is to mix these arbitrarily: `None` for parse errors, surprise exceptions in public APIs, or `Or_error.t` threaded through pure helpers that cannot actually recover.

## Quick Decision Rules
Use these defaults unless the repo already has stronger conventions:
| Situation | Preferred form |
| --- | --- |
| Lookup may miss | `'a option` |
| Validation, parse, config, network, or IO failure | `result` or `Or_error.t` |
| Internal helper where failure is impossible by construction | exception or `_exn` helper |
| Public library API with recoverable failure | `result` or `Or_error.t` |
| Programmer bug or broken invariant | exception |
| CLI or server top level | translate into one reporting policy |
If you are unsure, expose typed failure at the public boundary and allow local internals to use exceptions where that simplifies code under trusted invariants.

## `option`: Only For Ordinary Absence
Good:
```ocaml
val find_user : t -> User_id.t -> User.t option
```
Bad:
```ocaml
val load_config : string -> Config.t option
```
`load_config` can fail because the file is missing, malformed, unreadable, or semantically invalid. Collapsing all of that into `None` throws away exactly the information the caller needs.
Use `option` only when all of these hold:
- absence is an ordinary case
- no useful diagnostics are needed
- callers do not need to distinguish failure causes
- there is no recovery choice beyond "present or absent"

## `result` And `Or_error`
Use custom `result` when the error space is part of the domain:
```ocaml
type load_error =
  | Missing_file of string
  | Parse_error of string
  | Unsupported_version of int

val load : string -> (Config.t, load_error) result
```
Use `Or_error.t` when the codebase already speaks Base/Core and the main needs are composition, context tagging, and readable rendering:
```ocaml
let port_of_string s =
  Or_error.try_with (fun () -> Int.of_string s)
  |> Or_error.tag_arg "invalid port" s String.sexp_of_t
```
High-signal helpers:
- `Or_error.try_with`
- `Error.tag`
- `Error.tag_arg`
- `Or_error.error_s`
- `%message`
Wrap where you still know the missing context: filename, field name, request id, remote endpoint, subsystem, user input.
Good:
```ocaml
let load_config path =
  Or_error.try_with (fun () -> Sexp.load_sexp_conv_exn path Config.t_of_sexp)
  |> Or_error.tag_arg "failed to load config" path String.sexp_of_t
```
Bad:
```ocaml
let load_config path =
  try Ok (Sexp.load_sexp_conv_exn path Config.t_of_sexp) with
  | exn -> Error (Error.of_string (Exn.to_string exn))
```
The bad version destroys structure and often loses location detail.

## Exceptions: Use Them Deliberately
Exceptions are appropriate for:
- bugs and violated invariants
- impossible states
- internal control flow under trusted preconditions
- top-level fatal paths where the program will report and exit
They are usually a poor public interface for recoverable failure. If a function can fail during ordinary use and the caller might want to recover, do not make surprise exceptions the only API.
In Base/Core-style code, follow the visible naming contract when possible:
- `find` returns `option`
- `find_exn` raises
- `ok_exn` converts a typed failure to a raising form
Good split:
```ocaml
val parse : string -> Parsed.t Or_error.t
val parse_exn : string -> Parsed.t
```
Prefer implementing the raising form from the typed form rather than the reverse.

## Where The Error Boundary Should Live
A strong default architecture is:
1. parse or IO layer catches and annotates external failures
2. domain layer works on validated values or explicit typed errors
3. top-level command or server handler converts failures into logs, exit codes, or responses
Do not thread raw parser or filesystem exceptions through the whole domain model. Also do not monadify every tiny helper if only one outer layer can recover.

## Preserve Context Aggressively
Most hard production failures are not obscure because the root exception is complicated; they are obscure because nobody kept the context.
Weak:
```ocaml
Error "unexpected token"
```
Better:
```ocaml
Or_error.error_s
  [%message
    "failed to parse rule"
      (filename : string)
      (line : int)
      (token : string)]
```
Avoid the opposite failure mode too: giant ad hoc strings with no structure. If the repo uses `Error.t`, keep errors structured until the final rendering layer.

## Backtraces
Backtraces are for debugging exceptional failures, not for replacing ordinary error handling.
Practical guidance:
- do not optimize them away in normal application code
- preserve the original exception when wrapping
- be careful about catch-and-reraise patterns that destroy the useful stack
- use typed results for validation, config, or parse failures instead of relying on stacks to explain user-facing errors
`raise_notrace` exists, but it is for narrow performance-sensitive cases, not default application style. If you need to inspect the most recent exception in Base-style code, `Backtrace.Exn.most_recent ()` can help at the catch site.

## Resource Safety: Cleanup Must Be Lexical
Bad:
```ocaml
let load path =
  let ic = In_channel.create path in
  let data = parse_channel ic in
  In_channel.close ic;
  data
```
If `parse_channel` raises, the file descriptor leaks.
Good:
```ocaml
let load path =
  In_channel.with_file path ~f:(fun ic ->
    parse_channel ic)
```
If no `with_*` helper exists, use `Exn.protect` or `Fun.protect`:
```ocaml
let load path =
  let ic = In_channel.create path in
  Exn.protect
    ~f:(fun () -> parse_channel ic)
    ~finally:(fun () -> In_channel.close ic)
```
Prefer `with_*` helpers when available. They document lifetime policy directly and are harder to misuse.

## Cleanup Policy On Failure
Two things can fail:
1. the main operation
2. cleanup
Usually the primary failure should remain primary. Cleanup failure can be logged or attached separately, but should not casually overwrite the real reason the operation failed.

## Finalizers Are Backup, Not Normal Cleanup
GC finalizers are not prompt or deterministic. Use them only as a last resort for low-level wrappers that need leak mitigation. They are not a substitute for lexical scoping around files, sockets, subprocesses, or temporary resources.
For normal agent edits:
- prefer `with_*`
- prefer `protect` or `finalize`
- prefer `Switch.run` in Eio
- do not rely on the GC to close important resources "eventually"

## Async, Lwt, And Eio Cleanup
Match cleanup to the runtime:
- Async: `Monitor.protect`, runtime-aware resource helpers
- Lwt: `Lwt.finalize`
- Eio: `Switch.run`
The principle does not change: attach cleanup to the same lexical scope as acquisition, and test timeout or cancellation paths, not just ordinary exceptions.
Async shape:
```ocaml
let use_file path =
  Monitor.protect
    ~finally:(fun () -> cleanup ())
    (fun () ->
       let%bind contents = Reader.file_contents path in
       ...)
```
Eio shape:
```ocaml
let run env =
  Eio.Switch.run @@ fun sw ->
  let flow = open_flow ~sw env in
  use_flow flow
```

## Good And Bad Boundary Patterns
Bad public API:
```ocaml
val read_user : string -> User.t
```
when it performs IO or parsing that can fail in ordinary use.
Better:
```ocaml
val read_user : string -> User.t Or_error.t
```
Bad internal style:
```ocaml
let run x =
  step1 x >>= step2 >>= step3
```
when `step1`..`step3` are pure helpers and only the outer boundary can fail. Validate once, convert to a trusted value, and keep internal logic direct.

## Review Heuristics
Ask:
- Is absence actually ordinary, or is `option` hiding a real failure?
- Is the public API honest about what may raise?
- Is boundary context preserved?
- Are acquire, use, and release visibly paired?
- Does cleanup run on exception and cancellation?
Red flags:
- `try ... with _ ->`
- `failwith` in reusable library paths
- flattening all exceptions to strings immediately
- sentinel values instead of typed failures
- cleanup after use instead of around use

## Editing Checklist
- classify the failure: absence, validation, external failure, bug, or cancellation
- choose the narrowest useful representation
- expose recoverable failure at public boundaries
- preserve source exception and add context
- keep `_exn` variants visibly named
- keep cleanup lexical
- test both failure and cleanup paths

## Verification
- test success and failure cases
- verify signatures communicate recoverable failure honestly
- test malformed input, missing files, and permission-denied paths where relevant
- inject exceptions or timeouts to confirm cleanup actually runs
