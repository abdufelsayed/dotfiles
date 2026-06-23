---
summary: Function signatures, labeled and optional arguments, argument order, currying, partial application, pipelines, callbacks, builders, and wrapper forwarding.
load_when:
  - Task designs or changes function signatures, labeled/optional arguments, argument order, currying, partial application, pipelines, callbacks, builders, or wrapper forwarding.
skip_when:
  - Task is purely internal branch logic with stable APIs.
search_terms:
  - optional arguments
  - ?arg
  - labels
  - pipeline
  - partial application
  - eta expansion
  - call site
---
# Functions, Labels, and API Shape

## Core judgment

Design OCaml functions from the call site backward. Agents often write signatures that mirror implementation convenience instead of usage. Real World OCaml style does the opposite: make the common call obvious, then implement to match.

Treat currying, labels, optional arguments, and argument order as semantic API choices. They control whether callers can pipe values naturally, partially apply helpers, and let the type checker catch mistakes.

## What agents get wrong

- They leave multiple `string`, `int`, or `bool` arguments unlabeled.
- They tuple arguments that are not conceptually one value.
- They put an incidental parameter first and ruin `|>` pipelines.
- They use optional arguments to hide important policy.
- They rewrite wrappers with copied defaults instead of forwarding `?arg`.
- They forget that labeled argument order still matters in higher-order types.

## Start with real calls

Sketch three representative calls before freezing a signature.

Bad:

```ocaml
val substring : string -> int -> int -> string

let user = substring line 12 8
```

Better:

```ocaml
val substring : string -> pos:int -> len:int -> string

let user = substring line ~pos:12 ~len:8
```

If the call site reads like documentation, the shape is probably close.

## Currying is the default

Prefer curried functions unless the argument really is one value.

Good:

```ocaml
let abs_diff x y = Int.abs (x - y)
let dist_from_3 = abs_diff 3
```

Bad:

```ocaml
let abs_diff (x, y) = Int.abs (x - y)
```

Tuple arguments are for values that travel together as one object, not for ordinary multi-argument APIs. Use a tuple when the pair is the domain:

```ocaml
let area (width, height) = width * height
```

## Argument order is behavior

Curried APIs are easy to specialize, so parameter order controls what specialization feels natural.

Default heuristics:

1. Put the primary data subject in the first positional slot when callers will pipe with `|>`.
2. Put configuration and callbacks behind labels.
3. Put the most commonly specialized argument early if partial application is a main use case.
4. Keep sibling APIs consistent.

Good:

```ocaml
files
|> List.filter ~f:is_ocaml_source
|> List.map ~f:Filename.basename
```

Bad:

```ocaml
let filter_files ~f files = List.filter files ~f
```

That wrapper adds no value and invents a fresh calling convention.

## Use labels where they buy clarity

Labels are valuable for:

- long argument lists
- repeated primitive types
- booleans
- callbacks
- public builders and configuration-heavy functions

Good:

```ocaml
val create :
  path:string ->
  retries:int ->
  follow_symlinks:bool ->
  on_error:(Error.t -> unit) ->
  t
```

Bad:

```ocaml
val create : string -> int -> bool -> (Error.t -> unit) -> t
```

Labels are not a substitute for naming. If every argument needs a label just to explain what the function does, the function name or surrounding types may be wrong.

## Reuse stable label vocabulary

Follow local and ecosystem conventions when they fit:

- `~f`
- `~init`
- `~compare`
- `~equal`
- `~default`
- `~on_error`
- `~key`
- `~data`

Do not drift between `~func`, `~fn`, and `~f` across one module without a reason. Agents often create accidental dialect forks.

## Higher-order functions still care about label order

Direct calls with labels can reorder arguments. Function types cannot.

```ocaml
let apply_to_pair f (first, second) = f ~first ~second
let divide ~first ~second = first / second
let quotient = apply_to_pair divide (8, 2)
```

This works because the helper expects the same label order. A helper that calls `f ~second ~first` expects a different function type. Keep label order stable across wrappers and adapters.

## Optional arguments are for real defaults

Optional arguments are good when:

- there is an obvious safe default
- most callers should not have to mention the option
- omission improves readability
- the option extends a public API without breaking old callers

Good:

```ocaml
let read_file ?(strip_newline = false) path = ...
```

Questionable:

```ocaml
let parse ?(allow_legacy = true) ?(trust_input = false) text = ...
```

If the choice matters to correctness or policy, keep it explicit, often with a variant or labeled required argument.

## Forward optional arguments

If a wrapper preserves behavior, pass `?arg` through instead of restating defaults.

Good:

```ocaml
let concat ?sep a b = ...

let uppercase_concat ?sep a b =
  concat ?sep (String.uppercase_ascii a) b
```

Bad:

```ocaml
let uppercase_concat ?(sep = "") a b =
  concat ~sep (String.uppercase_ascii a) b
```

The bad version duplicates policy and silently diverges if the wrapped default changes.

## Optional arguments and partial application

Optional arguments are erased once the first positional argument after them is supplied.

```ocaml
let concat ?(sep = "") x y = x ^ sep ^ y
let prepend_hash = concat "# "
```

`prepend_hash` no longer accepts `~sep`. If you want later callers to still choose the option after specializing one positional argument, place the optional argument after that position:

```ocaml
let concat x ?(sep = "") y = x ^ sep ^ y
```

Choose optional-argument placement intentionally. It affects the resulting API shape, not just the parser.

## Use `function` for compact one-argument matches

Good:

```ocaml
let some_or_default default = function
  | Some x -> x
  | None -> default
```

Use `function` when the function really is one match. Do not force it into longer logic where a named argument improves clarity.

## Eta expansion is sometimes the right fix

A tiny wrapper can help when you need to:

- preserve a specific labeled shape
- pin an inferred type
- avoid weak type variable trouble around partial application and mutable state

Example:

```ocaml
let apply parser input = parser input
```

Do this when the compiler needs help, not as automatic style.

## Pipelines and `@@`

Use `|>` to show data flow. Use `@@` when it removes parentheses without harming readability.

Good:

```ocaml
path
|> String.split ~on:':'
|> List.dedup_and_sort ~compare:String.compare
|> List.iter ~f:print_endline
```

Also fine:

```ocaml
validate @@ parse @@ read_file path
```

Do not contort function order just to make one operator look clever.

## Good and bad mini-patterns

Bad:

```ocaml
val schedule : string -> string -> bool -> job
```

Good:

```ocaml
val schedule :
  queue:string ->
  command:string ->
  retry_on_failure:bool ->
  job
```

Bad:

```ocaml
let parse ?strict text = ...
```

when strictness is semantically important.

Better:

```ocaml
type mode = Strict | Lenient
val parse : mode -> string -> t
```

## Review checklist

- Are representative call sites readable without opening the implementation?
- Do same-typed arguments need labels?
- Is currying helping specialization, or is there a real tuple-shaped value?
- Is the first positional argument the right one for `|>`?
- Does every optional argument have a true public default?
- Are wrappers forwarding `?arg` instead of copying defaults?
- Are higher-order helpers preserving label order?
- Does the `.mli` read like a usable contract on its own?
