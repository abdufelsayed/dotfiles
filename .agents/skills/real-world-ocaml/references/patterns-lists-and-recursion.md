# Patterns, Lists, and Recursion

## Core judgment

Pattern matching is for structure, not arbitrary predicate logic. It tells you what shape of data you have, names the interesting subparts, and gives the compiler enough information to check coverage. Agents go wrong when they replace simple combinators with bespoke recursion, or when they hide useful warnings behind `_`.

Real World OCaml style is simple: make the data shape visible, use the list library for standard traversals, write recursion when the control flow is genuinely custom, and let exhaustiveness warnings guide refactors.

## What agents get wrong

- They hand-roll `map`, `filter`, or `exists` for no reason.
- They use `_` to silence warnings that were protecting them.
- They confuse "bind a variable" with "compare against an existing value".
- They use partial patterns in `let` bindings where `match` would be honest.
- They append with `@` inside recursion and accidentally go quadratic.
- They forget that list-depth recursion needs tail recursion on large inputs.

## Patterns describe shape

Classic mistake:

```ocaml
let rec drop_value list to_drop =
  match list with
  | [] -> []
  | to_drop :: tl -> drop_value tl to_drop
  | hd :: tl -> hd :: drop_value tl to_drop
```

The second case does not compare against the outer `to_drop`. It binds a new `to_drop`, shadowing the old one.

Write the structural match first, then use `if` or a guard for value-level conditions:

```ocaml
let rec drop_value list to_drop =
  match list with
  | [] -> []
  | hd :: tl ->
    let rest = drop_value tl to_drop in
    if hd = to_drop then rest else hd :: rest
```

Patterns can test constructors, literals, tuples, and record fields. They cannot express arbitrary relationships between values unless that relationship is already in the structure.

## Prefer `match` over partial destructuring

List and variant patterns are refutable. A partial `let` says "this shape is guaranteed". That is often more confidence than agent-written code deserves.

Questionable:

```ocaml
let first :: rest = String.split ~on:',' line
```

Better:

```ocaml
match String.split ~on:',' line with
| [] -> assert false
| first :: rest -> ...
```

If an API guarantee makes a case impossible, say so explicitly. That keeps the assumption local and visible.

## Exhaustiveness is a refactoring tool

Warnings about non-exhaustive or redundant matches are design feedback, not noise.

Good:

```ocaml
let color_to_int = function
  | Basic c -> basic_color_to_int c
  | Bold c -> 8 + basic_color_to_int c
  | RGB (r, g, b) -> ...
  | Gray i -> ...
```

Bad:

```ocaml
let color_to_int = function
  | Basic c -> basic_color_to_int c
  | _ -> 0
```

The catch-all suppresses the warning that should have helped you when the type evolves.

Default stance: enumerate constructors unless you truly mean "all remaining cases are intentionally identical forever".

## Use the pattern toolkit well

Useful tools:

- or-patterns with `|`
- `as` patterns to keep the original value
- `when` guards for extra value checks
- `function` for small one-argument matchers

Example:

```ocaml
let rec remove_sequential_duplicates = function
  | [] | [_] as l -> l
  | first :: (second :: _ as tl) when first = second ->
    remove_sequential_duplicates tl
  | first :: tl ->
    first :: remove_sequential_duplicates tl
```

This is clearer and allocates less than rebuilding `[x]` or reconstructing tails unnecessarily.

## Prefer list combinators for standard traversals

Before writing recursion, ask if the traversal is already a known list operation.

Reach for these first:

- `List.map`
- `List.filter`
- `List.filter_map`
- `List.find_map`
- `List.exists`
- `List.for_all`
- `List.fold`
- `List.reduce`
- `List.concat_map`
- `List.partition_tf` in Base/Core or the local equivalent

Write manual recursion when you need:

- custom short-circuiting not captured by a combinator
- multiple structures traversed together
- recursion over a user-defined recursive type
- specialized allocation behavior
- a traversal whose real meaning would be obscured by stacked combinators

If the code is "map, filter, flatten", do not hand-roll a loop to look clever.

## Know the fold shape

In Base/Core:

```ocaml
List.fold items ~init:acc ~f:(fun acc item -> ...)
```

In Stdlib:

```ocaml
List.fold_left (fun acc item -> ...) acc items
```

Do not mix the two styles. Follow the repo's dialect.

Use `fold` when you have a real identity and an accumulator. Use `reduce` when the empty-list case is naturally `None`.

Good:

```ocaml
let max_score xs = List.reduce xs ~f:Int.max
```

Less good:

```ocaml
let sum xs = List.reduce xs ~f:( + )
```

If zero is the real identity, `fold ~init:0` is clearer.

## Avoid `*_exn` for expected shapes

If empty and non-empty are both ordinary cases, pattern match instead of probing and then pretending an exception cannot happen.

Bad:

```ocaml
if List.is_empty xs then None else Some (List.hd_exn xs)
```

Good:

```ocaml
match xs with
| [] -> None
| x :: _ -> Some x
```

Reserve `*_exn` for already-established invariants or genuine fail-fast boundaries.

## Tail recursion matters

This innocent function overflows on very long lists:

```ocaml
let rec length = function
  | [] -> 0
  | _ :: tl -> 1 + length tl
```

Use an accumulator when recursion depth grows with input size:

```ocaml
let length list =
  let rec loop acc = function
    | [] -> acc
    | _ :: tl -> loop (acc + 1) tl
  in
  loop 0 list
```

Tree recursion is different: balanced trees are often shallow enough that ordinary recursion is fine and clearer.

## Build lists in reverse, then reverse once

The standard tail-recursive producer pattern is:

```ocaml
let rev_filter_map list ~f =
  let rec loop acc = function
    | [] -> acc
    | x :: xs ->
      match f x with
      | None -> loop acc xs
      | Some y -> loop (y :: acc) xs
  in
  loop [] list

let filter_map list ~f = List.rev (rev_filter_map list ~f)
```

Do not append one element at a time:

```ocaml
let rec bad_map list ~f =
  match list with
  | [] -> []
  | x :: xs -> bad_map xs ~f @ [f x]
```

That is quadratic.

## Repeated `@` and `^` are classic traps

Watch for:

```ocaml
acc @ [x]
```

and:

```ocaml
s ^ piece1 ^ piece2 ^ piece3
```

inside recursion or loops. Use `::` plus a final `List.rev` for lists. Use `String.concat` or the repo's buffering utility for many strings. Small one-off uses of `^` are fine; repeated left-associated concatenation is not.

## Recursive functions should expose the type shape

Good:

```ocaml
let rec eval expr base_eval =
  match expr with
  | Base base -> base_eval base
  | Const b -> b
  | And exprs -> List.for_all exprs ~f:(fun e -> eval e base_eval)
  | Or exprs -> List.exists exprs ~f:(fun e -> eval e base_eval)
  | Not expr -> not (eval expr base_eval)
```

Bad:

```ocaml
let rec eval expr base_eval =
  if is_base expr then ...
  else if is_const expr then ...
  else ...
```

When the type already tells you the cases, use the type directly.

## Review checklist

- Is this really custom recursion, or is it a standard combinator?
- Are the base cases explicit and correct?
- Would `_` hide a useful future compiler warning?
- Is any refutable `let` pattern better written as `match`?
- Could input-size recursion overflow the stack?
- Are list builders using `::` plus `List.rev`, not repeated `@`?
- Are string builders avoiding repeated `^`?
- Will new constructors force the right code to be revisited?
