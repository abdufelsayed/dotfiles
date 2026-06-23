---
summary: Collection choice, comparators, maps, sets, hashtables, equality, hashing, duplicate keys, and deterministic iteration.
load_when:
  - Task touches Map, Set, Hashtbl, association lists, equality, ordering, hashing, comparator witnesses, duplicate keys, or deterministic iteration.
skip_when:
  - Task is ordinary list recursion or a Dune-only edit.
search_terms:
  - Comparator.Make
  - Map.empty
  - Hashtbl.create
  - Poly.compare
  - duplicate keys
  - deterministic output
---
# Collections, comparators, maps, and hashtables

## Core judgment

Choose collections by semantics first, then by performance and convenience.

- association lists for tiny, local, obvious key/value data
- `Map` for persistent keyed data with deterministic ordering
- `Set` for uniqueness and set algebra
- `Hashtbl` for owned mutable indexes, caches, and accumulation

In Base/Core code, explicit comparators and explicit equality are not ceremony. They are how the type system helps prevent "these values happen to compare somehow" from becoming a bug.

## Start with the semantic question

Before choosing a collection, ask:

1. Do I need persistence or mutation?
2. Does key ordering matter?
3. Is deterministic traversal part of the behavior?
4. Is duplicate-key behavior meaningful?
5. Does the key type have a real equality and ordering story?

If you cannot answer those, you are not ready to pick between `Map` and `Hashtbl`.

## Association lists are for small, local data

Association lists are fine when:

- the list is tiny
- lookup is not hot
- keeping code simple matters more than asymptotics
- duplicates are meaningful or intentionally last-write-wins

Example:

```ocaml
open Base

let headers =
  [ "content-type", "application/json"
  ; "accept", "application/json"
  ]

let content_type =
  List.Assoc.find headers ~equal:String.equal "content-type"
```

That is good enough for small local metadata.

Bad escalation:

- adding an elaborate `Map` for three entries used once

Bad underreaction:

- keeping a growing hot-path symbol table as an association list because the original version was small

## Use `Map` for persistent ordered state

`Map` is usually the default when you need:

- immutable updates
- deterministic traversal
- merges, folds, diffs, or range-like ordered operations
- reviewable output order

Classic RWO example:

```ocaml
open Base

type t = (string, int, String.comparator_witness) Map.t

let empty = Map.empty (module String)

let touch t key =
  let count = Option.value (Map.find t key) ~default:0 in
  Map.set t ~key ~data:(count + 1)
```

Good reasons for `Map`:

- printing stable reports
- symbol tables with persistent snapshots
- config/state updates passed through pure code
- collecting results during transformations

If you later print or diff the collection, `Map` often saves you work by making order deterministic.

## Use `Set` for uniqueness, not `Map unit`

If the data is just membership, use `Set`.

```ocaml
let supported =
  Set.of_list (module String) [ "json"; "sexp"; "binio" ]
```

`Set` communicates intent better and exposes the operations you usually want:

- union
- intersection
- difference
- membership

Do not encode a set as `Map` to `unit` unless the repo already has a very specific reason.

## Use `Hashtbl` for mutable owned state

`Hashtbl` is the right tool when:

- mutation is part of the design
- the table is owned by one module or one computation
- you need fast repeated lookup/update
- deterministic iteration order is not the contract

Examples:

- memoization cache
- in-progress compiler environment
- dedup table during a single pass
- mutable aggregation inside an algorithm

Good:

```ocaml
open Base

let counts = Hashtbl.create (module String)

let bump key =
  Hashtbl.update counts key ~f:(function
    | None -> 1
    | Some n -> n + 1)
```

Bad:

- using `Hashtbl` as a drop-in "faster map" without caring about mutation, iteration order, or ownership

If the surrounding code is pure and persistent, introducing mutation for hypothetical speed usually makes the design worse.

## Base comparator witnesses are doing real work

In Base/Core, `Map.t` and `Set.t` carry a comparator witness in the type:

```ocaml
(key, data, comparator_witness) Map.t
```

This prevents mixing maps and sets built with incompatible orderings.

That is good. It stops subtle bugs like:

- one map ordered case-sensitively
- another ordered case-insensitively
- code later assuming they are interchangeable because both use `string`

Treat comparator witnesses as semantic evidence, not noise.

## Build comparators near the key type

For custom key types, define comparison and comparator support alongside the type.

Typical Base pattern:

```ocaml
open Base

module Book = struct
  module T = struct
    type t =
      { title : string
      ; isbn : string
      }
    [@@deriving sexp]

    let compare a b =
      match String.compare a.title b.title with
      | 0 -> String.compare a.isbn b.isbn
      | n -> n
  end

  include T
  include Comparator.Make (T)
end
```

Then:

```ocaml
let inventory = Map.empty (module Book)
```

This is better than scattering ad hoc anonymous compare functions through the codebase.

If the repo uses `Comparable.Make` or exposes an `Intf` module for key-like types, copy that pattern.

## Equality, ordering, and hashing must agree with the domain

For any nontrivial key type, think through:

- what counts as equal?
- what ordering is intended?
- what hash should be consistent with that equality?

These are domain decisions.

Examples:

- user IDs: compare by normalized id, not display name
- filesystem paths: compare after normalization only if the repo clearly models normalized paths
- floats: be careful; `NaN` and total ordering semantics can surprise you
- records: field order in comparison should reflect the intended identity, not whatever was quick to write

Bad:

```ocaml
type t = { name : string; created_at : Time_ns.t }
[@@deriving compare, hash, sexp]
```

if `created_at` should not participate in identity.

That derived comparison may be mechanically legal and semantically wrong.

## Polymorphic compare is a hazard

Avoid treating polymorphic compare as the default answer for production collections.

Why it is risky:

- semantic intent is unclear
- performance can be worse than specialized comparison
- behavior over functions and some structural values is problematic
- it bakes in field/layout details that may not match domain identity

Bad:

```ocaml
let dedup xs = List.dedup_and_sort ~compare:Poly.compare xs
```

unless the repo explicitly embraces `Poly` and the element type genuinely has the intended structural semantics.

Better:

```ocaml
let dedup_users xs =
  List.dedup_and_sort xs ~compare:User.compare
```

In Base-heavy code, prefer module-local `compare`, explicit equality, or comparator modules.

## Duplicate keys are part of the API

When converting lists into maps or tables, duplicate-key behavior must be explicit.

Useful patterns:

- `Map.of_alist_exn` when duplicates are a bug
- `Map.of_alist_or_error` when you want structured failure
- `Map.of_alist_multi` when duplicates are expected and grouped
- `Hashtbl.of_alist_exn` or `Hashtbl.create` plus manual accumulation when mutation is intended

Good:

```ocaml
let user_by_id =
  Map.of_alist_or_error (module User_id) users
```

Bad:

```ocaml
let user_by_id =
  List.fold users ~init:(Map.empty (module User_id)) ~f:(fun acc user ->
    Map.set acc ~key:user.id ~data:user)
```

if duplicate IDs are actually invalid input. That silently chooses last-write-wins and erases the bug.

## Deterministic output usually wants `Map`, not `Hashtbl`

If code later prints, serializes, snapshots, or diffs collection contents, deterministic order matters.

Good:

```ocaml
Map.to_alist stats
|> List.iter ~f:(fun (k, v) -> printf "%s %d\n" k v)
```

Potentially bad:

```ocaml
Hashtbl.iteri stats ~f:(fun ~key ~data ->
  printf "%s %d\n" key data)
```

If that output is used in expect tests, CLI results, or docs, you may have introduced nondeterminism into the product surface.

Sometimes the fix is:

- use `Map` from the start, or
- sort the `Hashtbl` entries before printing

## Mutable tables need ownership boundaries

`Hashtbl` is reasonable when the mutation is local and owned.

It is dangerous when:

- shared widely across modules
- updated from concurrent code without discipline
- used as ambient global state
- depended on for deterministic iteration

If concurrency is involved, be extra careful. Unsynchronized shared hash-table mutation is usually a design bug, not a performance optimization.

## Choose the collection that matches the algorithm

Some common patterns:

- compiler environment with snapshots: `Map`
- memo table inside one pass: `Hashtbl`
- small option/config lookup: association list
- live membership set used across pure transforms: `Set`
- grouping many values by key: `Map.of_alist_multi` or `Hashtbl.add_multi` depending on persistence vs mutation

Do not pick based on vibes like "hash tables are faster." Hot code should be profiled after the semantics are right.

## Serialization and collection choice

Collection choice also affects serialization and testability.

`Map` helps when you need:

- stable `sexp` or JSON output order
- reviewable snapshots
- deterministic round-trip tests

`Hashtbl` may be fine internally, but you often want to convert to a sorted representation before exposing data publicly.

Good pattern:

```ocaml
let sexp_of_counts counts =
  Hashtbl.to_alist counts
  |> List.sort ~compare:[%compare: string * int]
  |> [%sexp_of: (string * int) list]
```

## Good and bad examples

Good: explicit local equality for association lists

```ocaml
List.Assoc.find headers ~equal:String.Caseless.equal "content-type"
```

Good: custom comparator module for domain keys

```ocaml
module Project_id = struct
  module T = struct
    type t = string [@@deriving sexp]
    let compare = String.compare
  end
  include T
  include Comparator.Make (T)
end
```

Bad: polymorphic compare as a reflex

```ocaml
Map.of_alist_exn (module struct
  type t = project
  let compare = Poly.compare
  let sexp_of_t = [%sexp_of: project]
end)
```

Bad: using `Hashtbl` when persistence is the point

```ocaml
let apply_patch state patch =
  Hashtbl.set state.table ~key:patch.key ~data:patch.value;
  state
```

If callers expect old versions of `state` to remain valid, this is the wrong structure.

## Repository signals to copy

Look for:

- `Comparator.Make`, `Comparable.Make`, `Hashable.Make`
- `module T` plus `include T`
- explicit `equal`, `compare`, `hash`
- tests around duplicate keys and ordering
- conversion helpers that choose `*_exn`, `*_or_error`, or `*_multi` deliberately

If the repo uses `Base`, do not backslide into implicit polymorphic comparison unless there is a very local and justified reason.

## Editing checklist for agents

- What semantics are needed: order, persistence, mutation, uniqueness?
- Is deterministic iteration part of the behavior?
- Is key equality/order/hash explicitly correct for the domain?
- Is duplicate-key behavior deliberate?
- Is a mutable table locally owned?
- Will printed or serialized output remain stable?
- Are you accidentally using `Poly.compare` where a domain comparator should exist?

## Verification

Add tests for:

- duplicate-key handling
- iteration or output order when user-visible
- equality/ordering edge cases
- round-trips through serialization when relevant
- mutation behavior and ownership boundaries for `Hashtbl`

If performance is the motivation, benchmark after semantic correctness is settled, not before.
