# Compiler, PPX, FFI, And Codegen

This reference is about boundaries that matter in real OCaml work:

- where the compiler still knows source syntax
- where types disappear
- where PPX can and cannot help
- where generated code should be trusted, wrapped, or overridden
- where FFI code stops being ordinary OCaml and starts carrying memory and ABI risk

The right posture is explicitness. When code crosses compiler, generator, or C boundaries, make the source of truth obvious and keep the unsafe surface small.

## Default Stance

- Reuse the repo's existing PPX stack and build wiring.
- Keep generated code deterministic and build-owned.
- Treat derived code as mechanical convenience, not semantic authority.
- Use handwritten wrappers to restore invariants and present a safe `.mli`.
- Prefer `ppxlib` for new PPX work unless the repo already chose otherwise.
- Prefer `ctypes-cstubs` or handwritten stubs for production bindings where header layout or ABI correctness matters.
- Keep unsafe FFI implementation private and expose abstract types.

## The Compiler Pipeline You Actually Need

Roughly:

1. source text
2. parse tree
3. PPX rewrites on syntax trees
4. typed tree
5. lambda and later backend IRs
6. bytecode or native code

What changes across these phases:

- source comments and formatting matter only early
- PPX runs on syntax trees, not on typed semantic information
- type checking happens after PPX expansion
- by lambda, module and type structure has largely collapsed into runtime-oriented code

This matters because many mistakes come from asking the wrong layer to solve the problem.

Examples:

- Want to enforce a domain invariant from `[@@deriving sexp]`? PPX can generate structure, but your handwritten constructor or override should enforce the invariant.
- Want to inspect why matching got slow? Look at backend output, not the parsetree.
- Want to rewrite syntax in a repo-stable way? Use `ppxlib`, not compiler-internal AST modules directly.

## Parsetree vs Typedtree

Parsetree is syntax with locations and extension nodes. Typedtree is syntax after type inference and resolution.

Practical consequences:

- PPX transforms parsetree-shaped data.
- PPX cannot directly rely on inferred types.
- Compiler debug flags like `-dparsetree` and `-dtypedtree` are useful when syntax expansion or type elaboration gets weird.

Use `-dparsetree` when:

- an extension point is expanding strangely
- locations or attached attributes look wrong
- you are authoring or debugging PPX code

Use `-dtypedtree` when:

- you need to understand what the compiler inferred
- type-directed rewriting would have helped but is unavailable
- a module path or constructor resolution question is confusing

Do not build production tooling around raw debug dump formats. They are for learning and debugging, not stable APIs.

## Menhir, ocamllex, And Parser Boundaries

For new parser work, default to:

- `ocamllex` for lexing
- `menhir` for parsing

Why:

- Menhir has better ergonomics than `ocamlyacc`
- better error behavior
- standard dune integration
- better long-term odds of maintainability

Keep the boundary clean:

- lexer turns bytes into tokens
- parser turns tokens into an AST
- validation and semantic invariants belong after parsing unless the grammar can express them directly without turning the parser into sludge

Good shape:

```ocaml
type raw_expr =
  | Int of int
  | Add of raw_expr * raw_expr
```

then:

```ocaml
val type_check : raw_expr -> typed_expr Or_error.t
```

Do not force a parser to construct a deeply indexed GADT unless the grammar and error model truly justify it. Most external text formats want a raw or lightly typed AST first, then a separate typing or validation pass.

## Generated Parsers And Lexers

Generated files should feel boring.

Rules:

- generator inputs are the source of truth
- dune rules own regeneration
- do not hand-edit generated parser or lexer outputs
- if outputs are checked in, make regeneration reproducible and review diffs

If a generated file changed unexpectedly, find:

- the `.mly` or `.mll`
- the dune rule
- the generator version

before touching the output.

## PPX Hygiene

PPX is useful when it removes boilerplate or enables concise local syntax. It is harmful when it obscures control flow, changes semantics in surprising ways, or drags a repo into version-coupled tool pain for tiny gains.

Use PPX when:

- the repo already uses it heavily
- the generated code is conventional and predictable
- the abstraction pays for its dependency cost
- error messages remain tolerable

Avoid new PPX when:

- a helper function or module would be clearer
- only one file would benefit
- the repo is deliberately low-magic
- tooling friction outweighs saved lines

Good existing use cases:

- `[@@deriving sexp]`
- `ppx_compare`
- `ppx_fields_conv`
- expect tests
- let-syntax already standard in the repo

Bad reason:

- "I do not want to write twenty lines of straightforward OCaml once"

## PPX Runs Before Typing

This is the most important mental model for agents.

PPX sees syntax, attributes, locations, and extension nodes. It does not see inferred principal types.

Consequences:

- deriving works from declarations, not from semantic analysis
- type-driven custom generation is limited unless encoded syntactically
- PPX-generated code can still type-check incorrectly after expansion if your assumptions are wrong

If you need true semantic inspection, you are usually outside ordinary PPX territory and into compiler-libs tooling or separate analysis passes.

## Prefer ppxlib For New PPX Work

Direct use of compiler-internal AST modules ties you harder to compiler churn. `ppxlib` exists to absorb some of that pain and provide a stable-ish authoring surface.

Agent rule:

- if a repo already uses `ppxlib`, stay there
- if a repo has a legacy stack, follow local precedent unless you are intentionally upgrading it
- do not casually introduce compiler-libs-based PPX internals into an app repo

## Deriving Is Mechanical, Not Magical

Generated serializers, comparators, and field accessors are convenient but blind to domain invariants unless you intervene.

Classic example:

```ocaml
type t =
  | Range of int * int
  | Empty
[@@deriving sexp]

let create lo hi = if lo > hi then Empty else Range (lo, hi)
```

Derived `t_of_sexp` will happily construct `Range (6, 3)` unless you override it.

Good pattern:

```ocaml
type t =
  | Range of int * int
  | Empty
[@@deriving sexp]

let create lo hi = if lo > hi then Empty else Range (lo, hi)

let t_of_sexp sexp =
  match t_of_sexp sexp with
  | Empty -> Empty
  | Range (lo, hi) -> create lo hi
```

The general rule:

- let deriving handle shape
- let handwritten code handle invariants

## Keep Public Interfaces Handwritten

For generated, PPX-heavy, or FFI-heavy modules, a small handwritten `.mli` is often the difference between a maintainable API and a leaky one.

Expose:

- abstract types
- safe constructors
- deliberate operations

Hide:

- raw pointer types
- generated helper noise
- accidental representation details
- unsafe escape hatches unless the module is explicitly low-level

## Dune Wiring Expectations

Agents should know where the build truth usually lives:

- `(preprocess (pps ...))` for PPX
- `(menhir ...)` for Menhir
- `(ocamllex ...)` for lexers
- `(rule ...)` for custom generation
- `(foreign_stubs ...)` and `(foreign_archives ...)` for C

When adding a compiler-adjacent tool, update:

- dune stanza
- package dependencies
- tests that actually exercise the generated path

Do not add a library dependency and forget its PPX runtime or vice versa.

## Generated Code Expectations

Generated code should be:

- deterministic
- reproducible from checked-in inputs
- easy to regenerate
- excluded from manual edits

Generated code should not be:

- silently patched by hand
- a hidden second source of truth
- the only place invariants are enforced

If a repo checks in generated files, review generated diffs with the same skepticism you would give handwritten code, especially around public types and serialization.

## When To Inspect Backend Output

Look at backend artifacts only when the question is genuinely runtime-facing:

- why is this compare slower?
- why did this pattern match compile oddly?
- why is this call no longer tail-recursive?
- why is a function crossing the C boundary expensive?

Useful flags and tools vary by repo and compiler version, but the broad idea holds:

- typed dump for type issues
- lambda/backend dump for compiled shape
- assembly for very hot code
- `perf` or debugger symbols for profiling and native debugging

Do not debug ordinary app logic by spelunking assembly. That is a last-mile tool.

## FFI Strategy Choices

You generally have three levels:

1. `ctypes-foreign`
2. `ctypes-cstubs`
3. handwritten C stubs using the OCaml runtime API

Use `ctypes-foreign` when:

- interactive development matters
- the binding is small
- dynamic loading is acceptable
- you need dynamic function pointers or rapid experimentation

Use `ctypes-cstubs` when:

- production performance and startup stability matter
- you need header-driven struct layout
- compile-time mismatches should fail early

Use handwritten stubs when:

- you need low-level runtime control
- callbacks, rooting, or custom conversions get too subtle for a clean ctypes story
- the repo already uses handwritten stubs and has the discipline for it

Do not default to handwritten C if ctypes is enough. Do not default to `ctypes-foreign` if ABI fidelity is the real requirement.

## Abstract Foreign Handles In The Interface

Bad:

```ocaml
type window = unit Ctypes.ptr
val initscr : unit -> window
```

in a public `.mli`

Better:

```ocaml
type window
val initscr : unit -> window
```

This prevents random callers from fabricating pointers or mixing unrelated handles.

Expose the OCaml meaning, not the foreign storage trick.

## Lifetime Hazards With Ctypes

This is the part agents most often get wrong.

Memory allocated on the OCaml side and exposed through ctypes stays valid only while OCaml still keeps the owning value reachable.

That means:

- derivative pointers are only safe while the owner remains alive
- storing an interior pointer in C does not keep the OCaml owner alive
- callbacks passed to C have the same issue if C stores them beyond the OCaml call

Bad pattern:

```ocaml
let pass_ptr () =
  let p = allocate int 42 in
  c_library_stores_pointer p
```

If C keeps `p`, you need a strategy that also keeps the OCaml owner alive.

Good patterns:

- keep the owner in a long-lived OCaml structure
- make C own the memory and return an abstract handle
- use bigarrays or custom blocks when external lifetime is the real model

Agent rule: if C retains a pointer after the call returns, ask who owns the memory and how reachability is maintained.

## Strings And Buffers Across FFI

Strings are not "free C strings".

Check:

- does the C API need length + pointer, or null-terminated text?
- may data contain embedded null bytes?
- does C retain the pointer after the call?
- does C mutate the buffer?

If C mutates, a plain OCaml `string` is the wrong abstraction.
If C retains, you need explicit ownership.
If C expects large mutable buffers, prefer `Bigarray` or repo-local bigstring wrappers.

## Struct Layout Hazards

C struct layout can vary by:

- field order assumptions
- platform-specific padding
- conditional compilation
- undocumented fields in vendor headers

If layout fidelity matters, `ctypes-cstubs` is often the right answer because it can consult actual C headers at build time.

Do not confidently hand-declare complicated structs from a PDF or blog post and call it done.

## Callback Hazards

Callbacks are where FFI stops being cozy.

Questions to answer:

- can C call back only during the OCaml-initiated call, or later?
- who owns the callback function pointer?
- what thread or runtime state will invoke it?
- can it allocate OCaml values?
- does it need to re-enter the OCaml runtime safely?

If the callback escapes the call boundary, lifetime and runtime re-entry rules become central. That is often where handwritten stubs or a well-tested existing binding become much safer than improvised ctypes code.

## Handwritten C Stubs: Safety Expectations

If you cross into handwritten C stubs, treat them as unsafe systems code.

Expect to think about:

- rooting OCaml values
- allocation during stub execution
- callbacks into OCaml
- exception propagation boundaries
- custom blocks and finalizers
- platform ABIs

In the classic runtime API, macros like `CAMLparam`, `CAMLlocal`, and `CAMLreturn` exist for a reason. Skipping them in allocating or callback-heavy code is how bindings become intermittently wrong.

Agent rule: do not write or edit handwritten stubs casually from memory. Read adjacent stubs in the repo and match their conventions exactly.

## Good And Bad Patterns

Bad: public module exposes raw pointers and generated helper soup

```ocaml
type t = unit Ctypes.ptr
val t : t Ctypes.typ
val unsafe_make : unit Ctypes.ptr -> t
```

Better:

```ocaml
type t
val open_ : string -> (t, Error.t) result
val close : t -> unit
val read : t -> bytes -> int
```

Bad: deriving trusted with invariants

```ocaml
type config = { port : int } [@@deriving sexp]
```

when valid ports must be checked

Better:

```ocaml
type config = private { port : int }
val of_sexp : Sexp.t -> config
```

with range checks in the implementation

Bad: editing generated files directly

```text
parser.ml was patched by hand
```

Better:

```text
parser.mly changed; dune regenerated parser.ml
```

## Review Checklist For Agents

- What is the true source of truth: handwritten module, `.mly`, `.mll`, PPX annotation, codegen spec, or C header?
- Does the problem belong to syntax, typing, code generation, or runtime?
- Is the repo already committed to a PPX stack or FFI strategy?
- Are generated files deterministic and build-owned?
- Are derived serializers or comparators silently bypassing invariants?
- Does the public `.mli` hide unsafe or noisy implementation details?
- If C keeps a pointer, who owns the memory and how is lifetime guaranteed?
- If a callback escapes, what keeps it alive and what runtime assumptions hold?
- Would `ctypes-cstubs` catch layout problems that `ctypes-foreign` would miss?
- Are tests hitting the actual generated or foreign path, not just wrappers?

## Practical Recommendations

- Use Menhir for new parser work and keep parsing separate from semantic validation.
- Let PPX remove boilerplate, not conceal architecture.
- Favor `ppxlib` and repo-local conventions over compiler-internal cleverness.
- Override derived code at invariant boundaries.
- Keep handwritten `.mli` files for generated or unsafe modules.
- Choose FFI strategy based on ownership, ABI, and lifecycle constraints, not convenience alone.
- Treat lifetime and reachability as first-class design questions in any foreign binding.

The compiler and runtime are predictable enough that careful agents can work effectively at these boundaries. The failure mode is rarely "OCaml is mysterious". It is usually "the boundary was implicit". Make the boundary explicit, make the source of truth obvious, and keep the unsafe part embarrassingly small.
