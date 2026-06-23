# GADTs, Type Witnesses, And Existentials

Use GADTs when the type checker should carry a proof that changes what code is legal. Do not use them just because the data feels fancy. They earn their keep when they delete dynamic checks, make illegal states unrepresentable, or let one API vary its return type in a way ordinary variants cannot express cleanly.

## Default Stance

- Prefer ordinary variants, records, modules, and validation first.
- Reach for GADTs when a constructor should refine the result type of the value it builds.
- Keep GADTs behind a small API unless callers truly need the indices.
- Expect to write more annotations: locally abstract types, explicit polymorphism on recursive functions, and sometimes helper witnesses.
- Treat existential packaging as a precision tool, not a dump bucket for "some unknown thing".

## The Core Payoff

Ordinary variants let you say "this value is one of these shapes".

GADTs let you say "this constructor also proves something about the type parameter".

That extra proof is what powers:

- typed ASTs
- equality witnesses
- heterogeneous collections with safe elimination
- state-indexed workflows
- length or capability indexed values
- APIs whose return type depends on a mode witness

## Start With A Typed AST

This is the canonical case. If your AST has terms of different result types, a GADT can keep construction and evaluation aligned.

```ocaml
type _ expr =
  | Int : int -> int expr
  | Bool : bool -> bool expr
  | Plus : int expr * int expr -> int expr
  | Eq : 'a expr * 'a expr -> bool expr
  | If : bool expr * 'a expr * 'a expr -> 'a expr

let rec eval : type a. a expr -> a = function
  | Int n -> n
  | Bool b -> b
  | Plus (x, y) -> eval x + eval y
  | Eq (x, y) -> eval x = eval y
  | If (c, t, e) -> if eval c then eval t else eval e
```

Treat the `Eq` case above as a compact teaching shape, not a blanket production pattern. It uses OCaml equality on whatever `'a` evaluates to. In real code, if the expression language may grow beyond simple comparable atoms, carry an equality/comparator witness in the constructor or restrict equality to concrete constructors:

```ocaml
type _ expr =
  | Int : int -> int expr
  | Int_equal : int expr * int expr -> bool expr
  | String_equal : string expr * string expr -> bool expr
```

Agent rule: do not smuggle polymorphic equality into a typed AST just because the GADT makes the branch compile.

This is better than a phantom-typed wrapper around an untyped AST when:

- you want the implementation to be type safe too, not just the surface API
- you want one `eval : 'a expr -> 'a`
- you want impossible terms to be impossible to construct

This is worse than an ordinary AST when:

- the language is mostly parsed from untrusted text and type errors are inherently dynamic
- most consumers need generic traversals that do not care about result type
- the annotation burden overwhelms the actual benefit

## Locally Abstract Types And Polymorphic Recursion

If you use GADTs, future agents will hit this. Put the pattern in muscle memory.

Non-recursive functions often need a locally abstract type:

```ocaml
let show_value (type a) (w : a ty) (x : a) =
  match w with
  | Int_t -> Int.to_string x
  | String_t -> x
```

Recursive functions over GADTs usually need explicit polymorphism:

```ocaml
let rec eval : type a. a expr -> a = function
  | Int n -> n
  | Bool b -> b
  | Plus (x, y) -> eval x + eval y
  | Eq (x, y) -> eval x = eval y
  | If (c, t, e) -> if eval c then eval t else eval e
```

If you instead write:

```ocaml
let rec eval e =
  match e with
  | ...
```

you should expect confusing inference failures. The problem is usually not your branch logic. It is that the recursive function is being used at multiple instantiations and OCaml will not infer that polymorphism for you.

Agent rule: when a recursive GADT consumer fails with a bizarre type escape or branch mismatch, first try `let rec f : type a. a t -> ... = function`.

## Type Witnesses

A type witness is a runtime token whose constructor tells you which static type you are dealing with.

```ocaml
type _ ty =
  | Int_t : int ty
  | String_t : string ty
  | Bool_t : bool ty

let to_string : type a. a ty -> a -> string = fun ty x ->
  match ty with
  | Int_t -> Int.to_string x
  | String_t -> x
  | Bool_t -> Bool.to_string x
```

This is useful when:

- you need one function over values of many concrete types
- the choice of serializer, parser, printer, comparator, or decoder depends on a runtime tag
- you want a typed command, field, or configuration schema

Keep witnesses small. If every new type forces edits in twenty functions, the witness layer is too central or your design wants modules or first-class modules instead.

## Equality Witnesses

Equality witnesses let code prove that two type parameters are equal.

```ocaml
type (_, _) eq = Refl : ('a, 'a) eq

let cast : type a b. (a, b) eq -> a -> b = fun Refl x -> x
```

This is the building block behind safe heterogeneous maps, extensible typed identifiers, and witness comparison.

Typical pattern:

```ocaml
type _ ty =
  | Int_t : int ty
  | String_t : string ty

let eq_ty : type a b. a ty -> b ty -> (a, b) eq option =
  fun a b ->
    match a, b with
    | Int_t, Int_t -> Some Refl
    | String_t, String_t -> Some Refl
    | Int_t, String_t
    | String_t, Int_t -> None
```

Once you have `eq_ty`, you can recover typed values from heterogeneous storage:

```ocaml
type packed = Pack : 'a ty * 'a -> packed

let get : type a. a ty -> packed -> a option =
  fun want (Pack (have_ty, v)) ->
    match eq_ty want have_ty with
    | Some Refl -> Some v
    | None -> None
```

If the codebase needs this pattern in many places, centralize the witness definitions and equality function. Do not re-invent mini witness universes in random modules.

## Existential Packaging

Existentials mean "a specific type exists here, but callers do not get to know which one".

```ocaml
type printable =
  | Printable : { value : 'a; pp : 'a -> string } -> printable

let render (Printable { value; pp }) = pp value
```

Good uses:

- heterogeneous queues of jobs, commands, widgets, or fields
- typed values stored behind a common operation
- plugin registries where each entry carries its own interpreter

Bad uses:

- hiding sloppy API design
- postponing type design until "later"
- smuggling unrelated operations into one mega existential record

A packed value should come with exactly the operations needed to eliminate it safely. If every consumer immediately unpacks and pattern matches on ten fields, the abstraction failed.

## Index-Like And Length-Like Constraints

You can index data by structure, capability, or length. Keep this local to the modules that benefit.

Simple capability state:

```ocaml
type incomplete
type complete

type ('a, _) field =
  | Missing : ('a, incomplete) field
  | Present : 'a -> ('a, _) field

type 's request =
  { user_id : (int, 's) field
  ; perms : (string list, 's) field
  }

let authorize (r : complete request) =
  let { user_id = Present user_id; perms = Present perms } = r in
  user_id, perms
```

This is often more useful than Peano-encoded vector lengths because it matches actual application workflows.

For true length-like invariants, prefer exposing a narrow API:

```ocaml
type zero
type 'n succ

type (_, _) vec =
  | [] : (zero, 'a) vec
  | ( :: ) : 'a * ('n, 'a) vec -> ('n succ, 'a) vec
```

This is only worth it when operations genuinely benefit from the proof, such as non-empty heads, zipping equal-length vectors, or parser states with fixed arity.

If you only need "non-empty list", a dedicated type is usually cheaper than a full indexed vector encoding.

## Refutation Cases

If the type indices make a branch impossible, let the compiler check that explicitly.

```ocaml
type nothing = |

let unwrap_ok (x : (int, nothing) result) =
  match x with
  | Ok n -> n
  | Error _ -> .
```

Use refutation cases when they clarify the proof. Do not spray them around to look clever.

## Or-Patterns Usually Get Worse

GADT matches refine types per branch. Or-patterns often throw away the refinement you wanted.

Bad:

```ocaml
match witness with
| Int_t | String_t -> ...
```

If the branch body depends on the refined type, duplicate the branch or factor a helper.

Good:

```ocaml
let show_string s = s

match witness with
| Int_t -> Int.to_string x
| String_t -> show_string x
```

This is one of those places where a little repetition is more honest than trying to outsmart the type checker.

## Keep GADTs Behind Clean APIs

The sharpest GADT code often lives in a private implementation, with callers seeing plain functions and abstract types.

Good pattern:

- expose abstract `'a t`
- expose smart constructors
- expose eliminators like `eval`, `run`, `fold`, `decode`
- keep witness internals private unless downstream code truly composes on them

Example shape:

```ocaml
module Query : sig
  type 'a t

  val int : int -> int t
  val bool : bool -> bool t
  val if_ : bool t -> 'a t -> 'a t -> 'a t
  val eval : 'a t -> 'a
end
```

That gives callers the benefit without forcing every reader to parse the representation.

## When Not To Use GADTs

Do not use a GADT when:

- a regular variant plus a validation function is simpler
- the invariant is not consumed anywhere
- the only effect is harder error messages and more annotations
- you need broad deriving support and generic programming over the representation
- you are modeling parse errors, user input errors, or external schema errors that must remain dynamic anyway
- the type indices leak everywhere and infect unrelated modules

Bad smell:

```ocaml
type _ t =
  | Json : Yojson.Safe.t -> json t
  | Int : int -> int t
```

If every consumer immediately turns the GADT back into untyped dynamic inspection, you bought complexity and then sold it at a loss.

## Good And Bad Examples

Bad: phantom API over untyped implementation

```ocaml
type 'a expr = raw_expr
val eval_int : int expr -> int
val eval_bool : bool expr -> bool
```

This can still hide dynamic failures internally.

Better: typed implementation and typed eliminator

```ocaml
type _ expr =
  | Int : int -> int expr
  | Bool : bool -> bool expr
  | ...

val eval : 'a expr -> 'a
```

Bad: existential with no eliminator discipline

```ocaml
type box = Box : 'a -> box
```

This is rarely useful because you threw away all operations.

Better:

```ocaml
type showable = Showable : 'a * ('a -> string) -> showable
```

Now the package carries exactly the operation needed.

## Review Checklist For Agents

- What invariant is the GADT proving?
- Who produces the indexed value, and who consumes the proof?
- Would a regular variant plus a module boundary be simpler?
- Does a recursive consumer need `: type a.`?
- Is an existential package carrying the minimum elimination surface?
- Are marker types distinct enough to preserve narrowing through `.mli` boundaries?
- Are impossible cases encoded as refutations instead of runtime assertions?
- Is the public API smaller than the internal representation?

## Practical Recommendations

- Use GADTs for typed interpreters, query DSLs, mode-indexed APIs, and heterogeneous registries.
- Prefer state or capability indices over elaborate type-level arithmetic unless the arithmetic is central to correctness.
- Centralize witnesses and equality proofs; do not duplicate them across modules.
- Hide representation details in `.mli` files unless downstream composition needs them.
- Accept a little duplication in matches when it keeps type refinements obvious.
- If the code becomes annotation-heavy and still confusing, back up and ask whether modules or plain variants would be kinder.

The win condition is not "more type-level power". The win condition is that future agents can delete branches, delete runtime checks, and trust the types without cursing your name.
