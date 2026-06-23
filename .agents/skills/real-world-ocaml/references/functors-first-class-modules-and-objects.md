---
summary: Functors, first-class modules, objects/classes, records of callbacks, variants, dependency injection, backends, sharing constraints, and comparator-backed construction.
load_when:
  - Task chooses between functors, first-class modules, objects/classes, records of callbacks, variants, dependency injection, backends, sharing constraints, output constraints, or comparator-backed construction.
skip_when:
  - Task is an ordinary module interface edit without abstraction variation.
search_terms:
  - Make
  - with type
  - destructive substitution
  - first-class module
  - sharing constraints
  - objects
  - classes
---
# Functors, First-Class Modules, And Objects

## Core Judgment

Choose the abstraction that matches where variability actually happens.

- Use functors when the choice is static and enforced at module level.
- Use first-class modules when the choice is runtime and should travel as a value.
- Use objects or classes only when dynamic dispatch, row polymorphism, or open recursion is genuinely the point.

Most OCaml code needs modules and signatures constantly, functors sometimes, first-class modules occasionally, and objects/classes rarely.

## Start With The Real Decision

Ask:

- is the dependency chosen at compile time or runtime?
- do I need type sharing between implementations and callers?
- is the dependency truly module-shaped?
- would a plain function, record of callbacks, or variant be simpler?

If the answer is "this is one function dependency," you probably do not need a functor.

## Functors: Use Them For Module-Shaped Static Variation

Before reaching for a functor, check whether a function argument or record of callbacks would do. Functors are worth the weight when the parameter is genuinely module-shaped and the output's type story depends on it.

Bad functor use:

```ocaml
module Make (Log : sig val info : string -> unit end) = struct
  let run x =
    Log.info "running";
    x + 1
end
```

Usually better:

```ocaml
type logger = { info : string -> unit }

let run ~logger x =
  logger.info "running";
  x + 1
```

Good functor use:

```ocaml
module type Comparable = sig
  type t
  val compare : t -> t -> int
end

module Make_interval (Endpoint : Comparable) = struct
  type t =
    | Empty
    | Interval of Endpoint.t * Endpoint.t

  let create low high =
    if Endpoint.compare low high > 0 then Empty else Interval (low, high)
end
```

That is good because the dependency is module-shaped, the output type depends on the input module's type, the choice is static, and type relationships matter.

In real repos, functors are appropriate for pluggable storage backends, protocol backends, generic ordered containers, mockable service implementations in tests, and derived functionality over canonical signatures. Healthy patterns include `Comparable` or `Comparator` input for ordered containers, `Backend` signatures for storage or transport implementations, `Intf.S` consumed by `Make`, and core libraries instantiated differently by Unix, JS, or test backends.

Unhealthy patterns include turning every module into a functor, stacking `Make(M)(N)(O)` layers that hide simple logic, or using a functor for code that will only ever have one implementation.

## Comparator Patterns And Collection Construction

In Base/Core code, functors often support comparator-aware APIs cleanly.

```ocaml
module Id = struct
  module T = struct
    type t = int [@@deriving sexp, compare]
  end

  include T
  include Comparable.Make (T)
end
```

This centralizes the domain type, equality/ordering, and compatibility with maps and sets. Do not hand-roll ad hoc compare functions across a repo if one key module should own them.

## Dependency Injection, Output Constraints, And Type Equalities

Functors are good dependency injection when the dependency is a coherent module contract, not a stray value.

Good:

```ocaml
module type Clock = sig
  type t
  val now : unit -> t
end

module Make_cache (Clock : Clock) = struct
  ...
end
```

This is useful when the dependency participates in types, several related operations travel together, or tests and production need different instantiations. If the dependency does not affect the type story and only one function is needed, prefer value-level injection.

As with `.mli` files, do not let functor outputs sprawl unless the extra surface is part of the design.

Prefer:

```ocaml
module Make (X : S) : S_with_extra = struct
  ...
end
```

when the output contract should be stable and documented. An unconstrained output can accidentally expose helpers, nested modules, or concrete types that later become painful to change.

If several modules must agree on a type, say so explicitly.

```ocaml
module type Bumpable = sig
  type t
  val bump : t -> t
end

let bump_list
    (type a)
    (module B : Bumpable with type t = a)
    (xs : a list)
  =
  List.map B.bump xs
```

The sharing constraint `with type t = a` is not garnish. It connects the module value to the value-level type being manipulated. Use sharing constraints when functor inputs and outputs must align on a type, first-class modules must expose a usable type equality, or several modules refer to the same abstract domain type. Without them, abstraction often becomes unusably opaque.

Destructive substitution keeps signatures readable when a type already exists:

```ocaml
module type ID = sig
  type t
  include Comparable.S with type t := t
  val to_string : t -> string
end
```

This says "`t` is the main type" while reusing `Comparable.S` without introducing a second visible `type t`. Use this heavily around `Comparable.S`, `Sexpable.S`, and similar interface fragments.

When editing functors, think operationally about generativity and visible type equalities. Sometimes you want distinct instances with separate mutable state; sometimes you want downstream code to see stable equalities across instantiations. Write down the equalities callers should rely on before you patch the signature.

## First-Class Modules: Use Them For Runtime Module Choice

First-class modules let modules travel as values. Use them when module choice is data-driven at runtime: plugin registries, command-line backend selection, named handler loading, or heterogeneous lists of implementations sharing one signature.

```ocaml
module type Handler = sig
  val name : string
  val run : string -> string
end

let handlers : (module Handler) list = ...

let find_handler name =
  List.find_map
    (fun (module H : Handler) ->
      if String.equal H.name name then Some (module H : Handler) else None)
    handlers
```

This is cleaner than a giant variant when implementations are naturally module-shaped and already exist as modules.

They are not a universal replacement for functors. Costs: type equalities are harder to express, unpacking adds indirection, APIs can become opaque if you do not expose enough sharing, and they are awkward for heavy compile-time composition. If the implementation choice is fixed when building the library, use a functor or a plain module. If the choice happens while the program is running, first-class modules may be right.

Prefer a record of functions when there are only values, not types; ordinary polymorphism is enough; and you do not need module-level abstraction. Prefer first-class modules when implementations carry types, nested modules, or other signature structure, or when a runtime registry naturally wants module identity.

## Objects And Classes: Usually Avoid, Sometimes Exactly Right

Modern OCaml code usually prefers algebraic data types, records of functions, and modules over objects/classes. That is not because objects are bad; it is because most OCaml design problems are better served by modules and variants, and most ecosystem code follows that style.

Objects can still be a good fit when you need open object types with row polymorphism, subtype-friendly consumer APIs, method dispatch on values from diverse implementations, callback-heavy or UI-like integration points, or open recursion.

Consumer-side example:

```ocaml
let area x = x#width * x#width
```

That can accept any object with a `width` method. This can be elegant for consumer-side polymorphism.

Objects may also appear in bindings to external systems or older OCaml libraries. If the repo already uses them, match the local style instead of rewriting on sight.

Usually avoid objects/classes for ordinary domain models, service boundaries, pluggable backends already expressible with modules, closed sets of cases that variants model cleanly, or code where inheritance is not genuinely buying reuse.

Bad reason to add a class: "I need encapsulation." Modules and abstract types already do that well. Bad reason to add objects: "I want methods instead of functions." Method syntax alone is not a design win.

Classes are mainly about constructing objects and reusing behavior through inheritance. In modern OCaml repo work, inheritance is often not the best default. Prefer classes only when the repo already uses class hierarchies, open recursion is central, or subclass customization is a real extension mechanism. Otherwise prefer modules behind signatures, explicit composition, or variants plus interpreter functions.

## Small Good/Bad Examples

### Good: functor for backend-specialized construction

```ocaml
module type Store = sig
  type key
  type value
  type t

  val find : t -> key -> value option
  val set : t -> key -> value -> unit
end

module Make_cache (Store : Store) = struct
  let get_or_load t key ~load =
    match Store.find t key with
    | Some v -> v
    | None ->
      let v = load key in
      Store.set t key v;
      v
end
```

Why it is good: the module parameter is coherent, the output is specialized to the backend contract, and tests can instantiate a fake store.

### Good: first-class module for runtime selection

```ocaml
module type Codec = sig
  val name : string
  val encode : string -> bytes
end

let select_codec name codecs =
  List.find_map
    (fun (module C : Codec) ->
      if String.equal C.name name then Some (module C : Codec) else None)
    codecs
```

## Agent Checklist

- Is the choice static or runtime?
- Does the abstraction carry types ordinary values cannot express cleanly?
- Would a function or record be simpler?
- Are the needed type equalities explicit?
- Should the functor output be constrained?
- Is this repo already using modules, objects, or classes in this area?
- Is the abstraction solving a real variation point, or creating architecture tax?

## Default Recommendations

- Prefer plain modules and signatures first.
- Use functors for module-shaped static variability.
- Use first-class modules for runtime registries and plugin-like selection.
- Use sharing constraints aggressively when types must line up.
- Use destructive substitution to keep signatures readable.
- Prefer modules over objects/classes unless row polymorphism or open recursion is a real requirement.

Choose the abstraction that fits the repo's real variation point, not the one that merely looks advanced.
