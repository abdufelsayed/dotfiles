---
summary: Modules, signatures, .mli contracts, abstract/private types, module layout, nested modules, aliases, open, include, public APIs, and Dune visibility.
load_when:
  - Task touches .mli, public APIs, abstract/private types, module layout, nested modules, aliases, open, include, signature design, module boundaries, or Dune visibility.
skip_when:
  - Task is local implementation-only code and does not affect exposed names or representation.
search_terms:
  - .mli
  - type t
  - private
  - abstract
  - include
  - open
  - module alias
  - public modules
---
# Modules, Signatures, And Interfaces

## Core Judgment

In real OCaml code, modules are the main architecture tool. Files define modules, signatures define contracts, and `.mli` files decide what the rest of the repo is allowed to know. Code stays refactorable when representations, dependencies, and helper APIs do not leak across those boundaries.

## Files Are Modules, So File Layout Is API Design

Every `.ml` file creates a module.

```ocaml
(* user_name.ml *)
type t = string
let of_string s = String.trim s
```

This file does not just store code. It defines `User_name`. That means renaming a file renames a module path; moving a file may change wrapping, packaging, or install visibility; splitting one file into two introduces a boundary; merging files removes one. Do not treat file moves as cosmetic cleanup in OCaml.

A useful OCaml file usually owns one of these: a domain type and its operations, a protocol boundary, a backend implementation, a shared signature or `Intf`, or a small internal algorithm with a crisp name. Smelly files include `util.ml`, `helpers.ml`, `common.ml`, and `misc.ml`. Those names do not describe a boundary; they accumulate unrelated code and make dependencies hard to reason about.

Bad:

```ocaml
module Util = struct
  let read_file = ...
  let compare_user = ...
  let json_field = ...
  let retry = ...
end
```

Better:

```ocaml
module User = struct
  module Id = struct
    type t = ...
    let compare = ...
  end
end

module Retry_policy = struct
  type t = ...
  let should_retry = ...
end
```

If a helper is truly generic, prove it by reuse and stable semantics. Otherwise keep it local to the owning module.

## `.mli` Is The Contract

For public modules, read the `.mli` before the `.ml`. The interface tells you which names are public, which types are abstract, which constructors are hidden, which nested modules are exported, and which invariants callers are expected to rely on. Then read the `.ml` to see how the contract is implemented.

Without an `.mli`, callers can couple to record fields, variant constructors, helper functions, and implementation-only nested modules. With an `.mli`, you expose only what should survive refactors. If public behavior changes, update both files.

If there is no `.mli`, do not assume the module is public. Many repos intentionally leave private modules interface-free.

## Abstract Types Are A Refactoring Tool

Make a type abstract when callers should not depend on its representation.

Bad public interface:

```ocaml
type t = { user : string; token : string; expires_at : Time_ns.t }
```

Better:

```ocaml
type t

val create : user:string -> token:string -> expires_at:Time_ns.t -> t
val user : t -> string
val expires_at : t -> Time_ns.t
val is_expired : now:Time_ns.t -> t -> bool
```

Now the module can validate construction, change representation, add cached fields, or stop exposing sensitive data directly. Use abstraction when invariants matter, construction should be controlled, the representation may change, or the value carries sensitive or capability-like data. Do not make everything abstract by reflex; concrete types are fine when the data shape itself is the API.

A common pattern is abstract type plus smart constructors:

```ocaml
(* session_id.mli *)
type t
val of_string : string -> t option
val to_string : t -> string
```

```ocaml
(* session_id.ml *)
type t = string

let of_string s =
  if String.length s >= 16 then Some s else None

let to_string t = t
```

If callers cannot construct invalid values directly, invariants get stronger. Use private types in signatures when callers may inspect but not freely construct:

```ocaml
type t = private string
```

## Nested Modules, Aliases, `open`, And `include`

Nested modules are good when they encode real substructure: `User.Id`, `Config.File`, `Backend.Sqlite`, `Rpc.Request`, `Parser_state.Intf`. They are not good as a dumping ground for "small related things."

Good:

```ocaml
module User = struct
  module Id = struct
    type t = int
    let compare = Int.compare
  end

  type t =
    { id : Id.t
    ; name : string
    }
end
```

Ask: if this nested module were top-level, would its name still be good? If not, the nesting may be hiding a weak abstraction.

Module aliases are cheap and useful when they shorten stable paths or give a clear local handle to a nested namespace:

```ocaml
module Rpc = My_company_protocol.Rpc
module Id = User.Id
```

Good alias use shortens repeated long paths and clarifies domain names at the top of a file. Bad alias use obscures package origin, aliases many modules for no reason, or re-exports the alias publicly without intent.

Broad `open` changes name resolution for the rest of a scope. Prefer explicit qualification, then local opens, then expression opens, and only then file-wide `open` when the repo clearly wants it.

Good:

```ocaml
let normalize path =
  String.(path |> strip |> lowercase)
```

Also good:

```ocaml
let parse s =
  let open Parser_result in
  bind (tokenize s) ~f:build
```

Risky:

```ocaml
open Parser_result
open Helpers
open More_helpers
```

In Base/Core repos, file-wide `open Base` or `open Core` may be standard. Respect that, but do not add new broad opens casually.

`include` is powerful and easy to abuse. Use it when it expresses intentional interface or implementation reuse, not when it papers over weak boundaries.

Good:

```ocaml
module type S = sig
  type t
  include Comparable.S with type t := t
  val to_string : t -> string
end
```

Less good:

```ocaml
include A
include B
include C
include D
```

If the combined API only makes sense after reading four parents, the interface is too indirect.

## Signature Design

A strong signature names the main type clearly, reveals operations callers need, hides representations callers should not depend on, keeps dependency requirements narrow, and makes invariants obvious. A weak signature mirrors the implementation mechanically, leaks helper functions, exposes backend details in portable APIs, or grows because "it might be useful."

Ask:

- what must callers know?
- what should remain swappable?
- what breaks if I expose this now?

Expose the minimum stable truth.

## Internal Boundaries And Dune Boundaries

Mature OCaml repos often separate public and internal APIs with `private_modules`, `Foo_intf.ml`, nested `Intf` modules, carefully used `Import` modules, or package-private libraries. These patterns exist to avoid duplication and centralize contracts. Use them when several implementations share a signature, one library exports several modules with the same shape, or a functor input/output type needs one home. Do not create extra `Intf` layers unless repetition or consistency truly justifies them.

Module cycles usually mean the boundary is wrong. Fix them by extracting a smaller shared type, depending on an abstract signature instead of a full implementation, moving common concepts lower, or passing capabilities explicitly. Do not solve cycles by stuffing helpers into `Common`.

A module's location and Dune stanza determine whether it is public, wrapped, installable, or allowed to depend on certain libraries. Before adding a module, ask whether it belongs in this library, should be private, should be nested instead, or forces a dependency that belongs higher up. Often the right answer is "internal library, not public one."

## Small Good/Bad Examples

### Good: abstract API with meaningful operations

```ocaml
(* rate_limit.mli *)
type t

val create : window:Time_ns.Span.t -> limit:int -> t
val allow : now:Time_ns.t -> key:string -> t -> bool
val reset : t -> unit
```

Why it is good: representation is hidden, invariants stay owned by the module, and callers see meaningful operations instead of internal machinery.

### Bad: concrete leak plus helper sprawl

```ocaml
(* rate_limit.mli *)
type bucket =
  { mutable count : int
  ; mutable started_at : Time_ns.t
  }

type t = (string, bucket) Hashtbl.t

val create : ...
val touch_bucket : ...
val ensure_bucket : ...
val reset_bucket : ...
```

Why it is bad: mutable internals become public contract, helper names expose implementation structure, and swapping data structures later becomes expensive.

## Agent Checklist

- Read `.mli` before `.ml`.
- Decide whether the change is public or internal.
- Check whether the main type should stay abstract.
- Avoid new grab-bag helper modules.
- Prefer nested modules only for real subdomains.
- Keep `open` as narrow as possible.
- Use `include` deliberately and trace where names come from.
- Confirm the owning Dune stanza and package boundary.
- Update docs/tests when public API behavior changes.

## Default Recommendations
- Prefer modules over objects for most architectural boundaries.
- Prefer abstract types over exposed mutable internals.
- Prefer local opens over broad opens.
- Prefer domain names over helper dumps.
- Prefer a small, explicit signature over a clever indirect one.

Good module design makes future edits cheaper.
