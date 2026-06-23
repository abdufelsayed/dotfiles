# Concurrency, IO, And Effects
## Core Judgment
Follow the repository's concurrency model first. Async, Lwt, and Eio are different ecosystems with different assumptions about IO, cancellation, error propagation, and lifetime management. They are not interchangeable style choices.
Default rules:
- keep pure/domain code separate from scheduler-bound IO
- do not mix runtimes casually
- do not block the scheduler or event loop
- define cancellation and cleanup with the operation, not after the happy path works
For greenfield OCaml 5 direct-style apps, Eio is often a strong choice. For existing codebases, staying inside the current Async or Lwt stack is usually the right engineering call.

## First Pass: Identify The Runtime
Before editing IO code, inspect:
- `dune` and `*.opam` dependencies
- return types like `'a Deferred.t`, `'a Lwt.t`, or direct-style Eio APIs
- entrypoints such as `Command.async`, `Scheduler.go`, `Lwt_main.run`, `Eio_main.run`
- local helpers for clocks, pipes, sockets, subprocesses, and cancellation
Do not add Eio to an Async codebase just because the syntax looks nicer. Do not wrap Lwt inside Async inside Eio unless the repo already has an explicit interop boundary.

## Keep Effects At The Edge
The best concurrency code is often code you managed not to make concurrent.
Preferred layering:
- pure parsing, validation, and transformations in ordinary functions
- narrow boundary modules for filesystem, network, clock, subprocess, env
- orchestration code in Async, Lwt, or Eio that composes those boundaries
Bad:
```ocaml
let classify_user path =
  let%bind text = Reader.file_contents path in
  return (business_logic text)
```
when `business_logic` then reaches into IO, logging, and mutable state.
Better:
- `load_user : path -> string Deferred.t`
- `parse_user : string -> User.t Or_error.t`
- `classify_user : User.t -> Classification.t`
This keeps most code testable without schedulers and makes concurrency local to the boundary.

## Async, Lwt, And Eio: Different Defaults
### Async
Use:
- `Deferred.t`
- `Reader`, `Writer`, `Tcp`, `Clock`, `Pipe`
- `let%bind` / `let%map` or `>>=` / `>>|`
- `Command.async` or explicit scheduler entrypoints in executables
Important RWO lessons:
- `bind` sequences deferred work
- `map` is for pure post-processing
- `Ivar` and `upon` are low-level and easy to misuse
- `Pipe` gives backpressure-aware streaming
- `Deferred.any` can implement timeouts that stop waiting without actually canceling the work

### Lwt
Use:
- `'a Lwt.t`
- `Lwt_io`, `Lwt_unix`, `Lwt_process`, or repo-local wrappers
- `let*`, `Lwt.bind`, and `Lwt_result` where the codebase uses them
- `Lwt_main.run` only at the executable boundary
If the repo speaks `Lwt_result`, do not bounce between exceptions, plain `Lwt`, and ad hoc tuples for the same API.

### Eio
Use:
- direct style in fibers
- `Switch.run` for scoped resources
- structured cancellation
- `Eio_main.run` at the top-level entrypoint
Remember that Eio fibers are not system threads and not domains. CPU-parallel work is a separate design question.

## Blocking IO Boundaries
In promise or event-loop systems, blocking calls are poison unless the runtime or repo provides a safe escape hatch.
Red flags inside Async or Lwt paths:
- `In_channel.read_all`
- blocking DNS or process APIs
- synchronous sleeps
- CPU-heavy loops on the event-loop thread
- synchronous file hashing in request handlers
RWO explicitly contrasts `In_channel.read_all` with Async's `Reader.file_contents`. Follow that instinct everywhere: use scheduler-aware IO primitives inside scheduler code.
Good:
```ocaml
let count_lines filename =
  Reader.file_contents filename
  >>| fun text -> List.length (String.split_lines text)
```
Bad:
```ocaml
let count_lines filename =
  let text = In_channel.read_all filename in
  return (List.length (String.split_lines text))
```
The bad version pretends to be async while blocking first.

## Scheduler Entrypoints Belong At The Top Level
Keep runtime startup and shutdown at the executable boundary.
Typical forms:
- Async: `Command.async ... |> Command_unix.run` or explicit `never_returns (Scheduler.go ())`
- Lwt: `let () = Lwt_main.run (main ())`
- Eio: `let () = Eio_main.run main`
Do not call `Lwt_main.run`, `Scheduler.go`, or `Eio_main.run` in library code. Libraries should return the runtime's effect type, not try to own the runtime.
This matters especially for CLI code: let `Command.async` or the repo's wrapper manage the loop instead of manually nesting runtime startup inside handlers.

## Cancellation Is Part Of The API
Any long-lived or IO-bound operation should answer:
- can it be canceled?
- what happens to in-flight resources on cancellation?
- does timeout stop the underlying work or only stop waiting for it?
- what error or result does cancellation produce?
RWO's timeout example is the important warning.
Naive:
```ocaml
Deferred.any
  [ timeout_result
  ; get_definition word
  ]
```
This can return `"Timed out"` while the network request keeps running and holding resources.
Better pattern:
- create an interrupt or abort signal
- race timeout against the real operation
- make the timeout path trigger real cancellation
That is the difference between "I stopped waiting" and "the work stopped".

## Cleanup Must Survive Timeout And Cancellation
Concurrency bugs often show up as resource bugs:
- sockets left open after timeout
- pipes never closed
- subprocess readers abandoned
- detached fibers still mutating shared state
Attach cleanup to the runtime's structured primitive:
- Async: `Monitor.protect`, runtime-aware resource helpers, explicit pipe shutdown
- Lwt: `Lwt.finalize`
- Eio: `Switch.run`
Do not assume a passing success-path test proves the timeout path is safe. Test cancellation directly.

## Fire-And-Forget Is Usually A Smell
Detached background work needs an ownership story:
- who started it?
- who observes failures?
- when does it stop?
- does shutdown wait for it?
In Async, `don't_wait_for` is not a free pass. In Eio, a `Switch` often gives the ownership structure you actually want.
If you cannot answer the four questions above, do not launch background work yet.

## Pipes, Streams, And Backpressure
Use stream primitives when data is incremental, not as a fashionable substitute for lists.
RWO's `Pipe.transfer` example is the right mental model:
- producer writes incrementally
- consumer reads incrementally
- the runtime enforces backpressure
Use `Pipe` or equivalent abstractions for network bodies, logs, subprocess output, and producer-consumer pipelines. Prefer the runtime's backpressure mechanism over manual queue growth.

## Bound Parallelism
Concurrency is not the same thing as launching everything at once.
Bound parallelism for:
- file walks
- network fan-out
- subprocess bursts
- CPU-heavy transforms
Unbounded `Deferred.all`, `Lwt_list.map_p`, or ad hoc fiber spawning over user-sized collections can blow up file descriptors, sockets, memory, and rate limits.
If the repo already has a limiter, throttle, or pool abstraction, use it. Otherwise add one near the boundary instead of smearing batching logic throughout the codebase.

## Errors Across Concurrency Boundaries
Stay consistent with the repo's error style:
- Async often uses exceptions plus monitors internally, then typed results at API edges
- Lwt code may use exceptions, `Lwt_result`, or explicit results
- Eio code often uses exceptions plus structured scopes, then translates at boundaries
Do not swallow async exceptions with broad catches. Catch specific failure classes and preserve context. Also do not reduce every failure to `"Unexpected failure"` if the code already knows timeout vs parse failure vs connection reset.

## Mutable State, Threads, And Domains
Fibers and promises remove some shared-state hazards, not all of them.
Be careful with:
- refs updated from callbacks
- mutable caches shared across requests
- hash tables with multiple concurrent writers
- bridges to thread pools or domains
For OCaml 5 specifically:
- Eio fibers are structured concurrency
- domains are for CPU parallelism
- do not introduce domains casually into code that was only designed for scheduler concurrency
Document ownership or synchronization whenever mutable state has more than one active writer.

## Command-Line Programs And Concurrency
CLI parsing belongs here because many runtime entrypoints live in executables.
For Base/Core + Async, the default shape is:
```ocaml
let () =
  Command.async
    ~summary:"Fetch data"
    (let%map_open.Command path = anon ("path" %: string) in
     fun () -> run path)
  |> Command_unix.run
```
That is better than manual scheduler startup bolted on after parsing. The same principle applies in Lwt and Eio: parse flags, build a typed handler, and let the executable own the runtime.

## Good And Bad Examples
Bad timeout wrapper:
```ocaml
let fetch_with_timeout req =
  Deferred.any
    [ after (sec 1.) >>| fun () -> Error `Timeout
    ; fetch req
    ]
```
if `fetch` keeps running after timeout.
Better:
```ocaml
let fetch_with_timeout req =
  let interrupt = Ivar.create () in
  choose
    [ choice (after (sec 1.)) (fun () ->
          Ivar.fill interrupt ();
          Error `Timeout)
    ; choice (fetch ~interrupt:(Ivar.read interrupt) req) Fn.id
    ]
```
Bad layering:
```ocaml
let handle_request req =
  let body = In_channel.read_all req.path in
  ...
```
inside Async, Lwt, or Eio code.

## Review Heuristics
Ask:
- Which runtime owns this path?
- Does any call block the scheduler?
- Does timeout cancel the work or only the wait?
- Who owns this background task?
- Is backpressure explicit?
- Is pure logic separated from IO orchestration?
Red flags:
- mixing Async, Lwt, and Eio in one module
- hidden `*_blocking` calls in async handlers
- unbounded parallel fan-out
- detached tasks with no owner
- cleanup that runs only on success
- runtime entrypoints in library code

## Editing Checklist
- identify the runtime before changing IO code
- keep pure code outside scheduler-bound modules
- use runtime-native IO primitives
- define timeout and cancellation semantics explicitly
- pair acquisition and cleanup lexically
- add backpressure or concurrency limits where needed
- keep runtime startup at the executable boundary

## Verification
- test success, failure, timeout, and cancellation
- confirm timed-out work is actually canceled where possible
- verify no blocking calls remain in async or fiber paths
- test stream and pipeline closure behavior
