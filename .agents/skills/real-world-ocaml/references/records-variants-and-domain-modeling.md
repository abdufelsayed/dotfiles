# Records, Variants, and Domain Modeling

## Core judgment

Use OCaml's type system to make illegal states hard to represent and missing cases hard to ignore. Records, variants, module abstraction, and pattern matching are not separate from the design. They are the design.

The common agent mistake is flattening everything into a record of primitive fields and `option`s, then reconstructing domain rules with comments and runtime checks. Real World OCaml style pushes the distinctions into the type.

## What agents get wrong

- They use `bool` flags for modes, states, or outcomes.
- They use sentinel strings and magic integers instead of variants.
- They flatten alternative-specific data into one oversized record.
- They expose record fields publicly even when invariants matter.
- They overuse functional updates and miss newly added fields.
- They add mutation because the model is awkward, not because the state is truly owned and evolving.
- They reach for polymorphic variants by default and lose useful compiler errors.

## Records are product types

Use a record when a value has several facts at once.

```ocaml
type service_info =
  { service_name : string
  ; port : int
  ; protocol : string
  }
```

A record is good for structured parsed data, configuration, immutable snapshots, and state bundles where field names matter.

Prefer a record over an anonymous tuple when positions have domain meaning:

```ocaml
type endpoint =
  { host : string
  ; port : int
  }
```

## Variants are sum types

Use a variant when a value is one of several alternatives.

```ocaml
type color =
  | Basic of basic_color
  | Bold of basic_color
  | RGB of int * int * int
  | Gray of int
```

Variants are the right tool for states, commands, results, AST nodes, protocol message kinds, and modes. If code keeps asking "which kind is this?", it probably wants a variant.

## First question: product or sum?

Ask whether the value is:

- several fields at once: record
- one case out of several: variant
- common fields plus case-specific payloads: both

Bad:

```ocaml
type job =
  { state : string
  ; started_at : Time_ns.t option
  ; finished_at : Time_ns.t option
  ; exit_code : int option
  ; error_message : string option
  }
```

This allows nonsense like a "finished" job with no finish time.

Better:

```ocaml
type job =
  | Queued of { enqueued_at : Time_ns.t }
  | Running of { started_at : Time_ns.t; pid : int }
  | Finished of { finished_at : Time_ns.t; exit_code : int }
  | Failed of { finished_at : Time_ns.t; error_message : string }
```

Now each state carries exactly the data it needs.

## Do not encode states as booleans

Bad:

```ocaml
type user =
  { name : string
  ; is_admin : bool
  ; is_suspended : bool
  }
```

Two booleans silently define four combinations, some of which may not make sense.

Better:

```ocaml
type account_state = Active | Suspended
type role = Admin | Regular

type user =
  { name : string
  ; state : account_state
  ; role : role
  }
```

Booleans are fine for real yes/no facts. They are poor stand-ins for lifecycle or policy.

## Put case-specific data in constructors

When data belongs only to one case, attach it to that constructor.

```ocaml
type event =
  | Connected of { session_id : string; user : string }
  | Heartbeat of { session_id : string; status_message : string }
  | Disconnected of { session_id : string; reason : string option }
```

Inline records are especially good when field names help readability and the payload does not need to exist as a separate named record type.

Tiny payloads can stay tupled:

```ocaml
| RGB of int * int * int
```

But named fields beat unlabeled tuples once the payload stops being obvious:

```ocaml
| Logon of { user : string; credentials : string }
```

## Combine records and variants on purpose

A common real design is shared fields plus alternative-specific details.

```ocaml
module Common = struct
  type t =
    { session_id : string
    ; time : Time_ns.t
    }
end

type details =
  | Logon of { user : string; credentials : string }
  | Heartbeat of { status_message : string }
  | Log_entry of { important : bool; message : string }

type message = Common.t * details
```

This is often better than repeating shared fields in every record or flattening every possible payload into one giant structure.

## Hide representations when invariants matter

Expose concrete records and constructors only when callers should depend on their exact shape. Otherwise, use `type t` in the `.mli` and provide constructors, validators, accessors, and transition functions.

Good abstraction candidates:

- validated identifiers
- normalized paths
- nonempty collections
- records with cross-field invariants
- state machines with guarded transitions

If arbitrary construction would violate invariants, do not expose the raw shape.

## Warning 9 should usually be on

Record patterns are irrefutable, but they can be incomplete.

```ocaml
let to_string { service_name; port; protocol } =
  Printf.sprintf "%s %d/%s" service_name port protocol
```

If a `comment` field is added later, this still compiles unless warning 9 is enabled. RWO-style advice:

- enable warning 9 during development
- write `; _` only when you intentionally want to ignore future fields

Intentional ignore:

```ocaml
let to_string { service_name; port; protocol; _ } = ...
```

## Field punning is usually good

Use field punning and label punning when the domain names are already right.

```ocaml
let create_service_info ~service_name ~port ~protocol ~comment =
  { service_name; port; protocol; comment }
```

This is clearer than restating the same identifier on both sides. Do not rename meaningful fields just to make punning possible.

## Reused field names need module discipline

OCaml can disambiguate fields by type, but humans still have to read the code. If several records share fields like `session_id` and `time`, separate them by modules or add type annotations where needed.

```ocaml
module Heartbeat = struct
  type t =
    { session_id : string
    ; time : Time_ns.t
    ; status_message : string
    }
end

let session_id (t : Heartbeat.t) = t.session_id
```

If a human reader has to simulate the type checker to know which record is in play, the design is too clever.

## Functional update is concise and slightly dangerous

Functional update is great for local immutable tweaks:

```ocaml
let register_heartbeat t hb =
  { t with last_heartbeat_time = hb.Heartbeat.time }
```

But it does not force reconsideration when new fields are added. If `last_heartbeat_status` appears later, the code above still compiles and may silently miss work.

Use functional update when unchanged fields should truly stay untouched. Prefer explicit reconstruction when adding a field should force every update site to think again.

## Mutation belongs to owned evolving state

Mutable fields are for state that actually changes over time and is clearly owned by one layer.

Reasonable:

```ocaml
type running_sum =
  { mutable sum : float
  ; mutable sum_sq : float
  ; mutable samples : int
  }
```

Questionable:

```ocaml
type request =
  { mutable user : user option
  ; mutable path : string
  ; mutable authenticated : bool
  }
```

If many fields mutate independently across the codebase, the model or the ownership boundary may be wrong. Prefer immutable snapshots across module boundaries.

## First-class fields are advanced but useful

If the repo already uses `ppx_fields_conv` or `fieldslib`, generated accessors and `Field.t` values are worth using for generic tooling: tables, sorting, pretty-printing, selection UIs, and field-driven transformations.

Do not add that machinery just to avoid writing `fun x -> x.user` once. Use it where generic record operations are a real pattern.

## Catch-all matches weaken variant design

Bad:

```ocaml
let oldschool_color_to_int = function
  | Basic c -> basic_color_to_int c
  | _ -> basic_color_to_int White
```

This works today and hides tomorrow's missing cases. If a variant matters to your domain model, enumerate constructors so the compiler can guide refactors.

## Recursive variants are how OCaml models trees

Do not encode tree- or language-like data as records with string tags and optional child fields.

Good:

```ocaml
type 'a expr =
  | Base of 'a
  | Const of bool
  | And of 'a expr list
  | Or of 'a expr list
  | Not of 'a expr
```

Bad:

```ocaml
type expr =
  { kind : string
  ; children : expr list
  ; literal : bool option
  }
```

Use recursive variants and pattern matching directly.

## State machines should usually be variants

If transitions are part of the problem, variants usually beat mutable records with mode flags.

```ocaml
type connection =
  | Connecting of { retries : int }
  | Open of { peer : endpoint }
  | Closed of { reason : string }
```

Then expose transitions:

```ocaml
val on_open : endpoint -> connection -> connection
val on_error : string -> connection -> connection
```

This makes impossible transitions harder to express by accident.

## Prefer ordinary variants by default

Polymorphic variants are powerful, but they are not the default recommendation for production OCaml written by agents. Ordinary variants usually win because they produce clearer types, better errors, stronger typo detection, and simpler refactors.

Use polymorphic variants when:

- you need lightweight local variants without a named type
- you intentionally share tags across related APIs
- the interface is genuinely open or extensible
- the codebase already uses them heavily

## If you use polymorphic variants, annotate aggressively

Catch-all plus polymorphic variants is a bug magnet.

Bad:

```ocaml
let is_positive = function
  | `Int x -> Ok (x > 0)
  | `Float x -> Ok (x > 0.)
  | _ -> Error "unknown"
```

This accepts misspellings like `` `Floot`` without a useful type error.

Safer practice:

- declare exact types in the `.mli`
- add explicit annotations in the `.ml`
- avoid catch-all cases
- use narrowing patterns like `#color` when sharing tag subsets

Pragmatic rule: if ordinary variants would work, prefer ordinary variants.

## Review checklist

- Can the type make an illegal state unrepresentable?
- Is a `bool`, `string`, or `int` really standing in for a richer domain type?
- Should this be a variant instead of a record with many `option` fields?
- Are shared fields separated cleanly from alternative-specific payloads?
- Should the representation stay abstract in the `.mli`?
- Would warning 9 catch an important record refactor here?
- Are functional updates hiding fields that future changes should reconsider?
- Is mutation local, owned, and justified?
- Are catch-all matches weakening the type checker?
- Would an ordinary variant be simpler than a polymorphic variant here?
