---
summary: Runtime representation, allocation, immediates, heap blocks, boxed floats, arrays, closures, mutation, polymorphic compare, GC, profiling, benchmarking, and Obj.
load_when:
  - Task is performance-sensitive or touches allocation, runtime representation, floats, arrays, boxing, closure allocation, mutation, polymorphic compare in hot paths, GC behavior, profiling, benchmarking, FFI memory, or Obj.
skip_when:
  - Task is ordinary correctness work without performance pressure.
search_terms:
  - immediate
  - heap block
  - boxed float
  - float array
  - closure
  - write barrier
  - minor heap
  - GC tuning
---
# Runtime, Memory, GC, And Performance

OCaml performance gets much easier to reason about once you stop thinking in source-level categories and start thinking in runtime shapes: immediates, heap blocks, boxed floats, flat float arrays, closures, custom blocks, and a generational GC that loves short-lived allocation and charges for certain mutations.

This guide is for agents making practical choices in real codebases, not for writing toy micro-optimizations from folklore.

## Default Stance

- Prefer representation changes over GC tuning.
- Prefer algorithmic wins over "clever" low-level tricks.
- Assume allocation is cheap until measurement says otherwise.
- Assume polymorphic operations are too expensive for hot paths until proven acceptable.
- Avoid `Obj` in production code.
- Measure before and after with repo-local tooling when possible.

## The Runtime Mental Model

Every OCaml value is one machine word at the use site.

That word is either:

- an immediate value encoded directly in the word, or
- a pointer to a heap block

The low bit distinguishes them. Immediate values are cheap: no heap allocation, no pointer chase, no scanning by the GC.

Heap blocks have:

- a header word
- a tag
- a size
- payload words or bytes

The GC follows fields in scanned blocks. It does not inspect opaque byte payloads like strings or custom blocks.

## What Is Usually Immediate

These are usually immediate:

- `int`
- `char`
- `bool`
- `unit`
- `[]`
- constant constructors like `None`, `Left`, `Foo`

That means:

- `None` does not allocate
- `Some x` usually allocates a block
- `[]` does not allocate
- each `::` cell allocates

This matters in APIs that wrap tiny values in `option` or variants in tight loops.

## What Usually Allocates A Block

These usually allocate heap blocks:

- tuples
- records
- closures
- arrays
- list cons cells
- variant constructors with payload
- strings and bytes
- boxed floats

The immediate vs block split explains a lot of "why is this slower?" moments.

## Variants And Options

Normal variants are efficient and predictable.

- constant constructors are immediates
- constructors with payload are blocks

So this:

```ocaml
type t = A | B of int | C of string
```

means:

- `A` is immediate
- `B 3` allocates one block
- `C "x"` allocates one variant block plus the string block

`option` follows the same rule:

- `None` is immediate
- `Some x` allocates unless `x` is optimized by a specialized representation outside ordinary source OCaml assumptions

Practical consequence: if you create millions of `Some int` values in a hot path, you are allocating millions of blocks.

## Records, Tuples, And Arrays

Records, tuples, and ordinary arrays are all block-shaped containers of fields.

That means:

- a tiny record is still a block
- tuple-heavy intermediate pipelines allocate aggressively
- `Array.map` can allocate a lot even when the element type is immediate

Bad:

```ocaml
let sum_pairs xs =
  xs
  |> List.map ~f:(fun x -> x, x + 1)
  |> List.fold ~init:0 ~f:(fun acc (x, y) -> acc + x + y)
```

Better:

```ocaml
let sum_pairs xs =
  List.fold xs ~init:0 ~f:(fun acc x -> acc + x + (x + 1))
```

The second version avoids allocating a tuple per element and often avoids an intermediate list too.

## Floats Are The First Big Trap

A standalone `float` is boxed.

That means:

- every float field in an ordinary mixed record is a word pointing at a float block
- passing floats around in generic containers can allocate more than you think
- float-heavy code can suffer from hidden indirections

Special case:

- arrays of only floats
- records of only floats

can use a specialized flat representation with unboxed float payloads.

This is why these two shapes behave differently:

```ocaml
type vec_bad = { x : float; y : float; tag : int }
type vec_good = { x : float; y : float }
```

`vec_good` can use the flat-float representation. `vec_bad` cannot, because the extra `int` field breaks the all-float layout.

Similarly:

```ocaml
let a = [| 1.0; 2.0; 3.0 |]
let t = (1.0, 2.0, 3.0)
```

`a` is a flat float array. `t` is not.

Agent rule: if performance-sensitive numeric code uses tuples of floats, mixed records with floats, or generic `float option list`, inspect the allocation story before touching anything else.

## Polymorphic Variants Cost More

Polymorphic variants buy flexibility and cost some runtime efficiency.

- constant polymorphic variants are hashed immediates
- payload-carrying polymorphic variants need more space than normal variants
- multi-argument payloads often add another tuple block and indirection

Use them when the extensibility story matters. Prefer ordinary variants in hot or memory-sensitive code.

## Strings, Bytes, Bigstring, And Bigarray

`string` and `bytes` are heap blocks with opaque byte contents. The GC does not scan inside them for pointers.

Practical implications:

- large strings increase memory footprint but not GC pointer-traversal cost
- repeated string concatenation still allocates aggressively
- use `Buffer`, `Bytes`, `Bigstring`, or a streaming builder in assembly-heavy paths

Do not confuse OCaml string layout with safe C string usage:

- OCaml strings are null-terminated in representation
- they may contain embedded `\000`
- many C APIs want length-aware buffers, not "whatever `strlen` sees"

For large external buffers or zero-copy IO, prefer `Bigarray` or repo-local `Bigstring`/`Iobuf` style abstractions. They move storage outside the OCaml heap and avoid copying through boxed OCaml strings.

## Closures Allocate Too

Every closure is a block that stores:

- a code pointer
- captured environment values

This means hidden allocation shows up in code like:

```ocaml
for i = 0 to n do
  ignore (List.map xs ~f:(fun x -> x + i))
done
```

or:

```ocaml
let mk_pred threshold = fun x -> x > threshold
```

Creating closures occasionally is fine. Creating them per element in a hot loop can matter.

Watch for:

- fresh lambdas inside tight loops
- partial applications that allocate closures
- iterator-heavy pipelines in hot code where an imperative loop would be simpler

Do not "optimize" this blindly. But if profiling points to allocation churn in a hot loop, fresh closures are a likely suspect.

## Custom Blocks And FFI-Shaped Memory

Custom blocks let OCaml hold opaque externally managed data. The GC does not scan them for OCaml pointers.

Typical uses:

- big external buffers
- file descriptors or handles wrapped by C
- C library structs with custom finalization hooks

Agent rule: if a type ultimately wraps a custom block or bigarray, its memory footprint may not show up as ordinary OCaml heap pressure. That changes how you interpret GC stats.

## The GC Model You Actually Need

OCaml uses a generational GC:

- most allocations go into the minor heap
- surviving values are promoted to the major heap
- minor allocation is extremely cheap
- long-lived data and mutation patterns matter more than people expect

This leads to one of the key practical rules:

short-lived allocation is often cheaper than in-place mutation of old objects

That feels backward if you come from manual-memory or JVM folk wisdom, but it is often true in OCaml.

## Minor Heap vs Major Heap

Minor heap:

- contiguous
- fast bump allocation
- collected frequently
- ideal for short-lived values

Major heap:

- larger
- for promoted or long-lived blocks
- managed incrementally with more bookkeeping

So a pipeline that allocates fresh short-lived records can be fine, while a long-lived mutable structure repeatedly patched to point at fresh minor values can pay write-barrier costs.

## The Write Barrier

When you mutate a field in a major-heap block to point to a younger value, the runtime must remember that pointer so minor collections stay correct.

That bookkeeping is the write barrier.

This is why code like this can surprise you:

```ocaml
type t = { mutable count : float; mutable iters : int }
```

Repeatedly mutating an old record can be slower than allocating fresh immutable copies on the minor heap, depending on the workload.

Do not generalize too far. The right lesson is:

- mutation is not free
- immutable rebuilds are often cheaper than they look
- benchmark before assuming in-place updates are the fast path

## Allocation Awareness

Hot-path allocation commonly comes from:

- tuple and record temporaries
- list append and repeated concatenation
- `Some` wrappers
- boxed floats
- closure creation
- polymorphic containers
- repeated `Map` or `Set` rebuilding
- exception-heavy control flow used as ordinary branching

Useful habit: when reading performance-sensitive OCaml, annotate mentally:

- allocates?
- boxes?
- captures?
- mutates old data?
- uses polymorphic compare/equality?

## Tail Calls, Recursion, And Loops

Tail recursion matters for unbounded recursion depth, not as a religion.

Use:

- direct recursion for clear structural traversals
- tail recursion for large lists or streams
- `for` and `while` loops for tight imperative numeric kernels or index-heavy array code

Bad:

```ocaml
let rec sum = function
  | [] -> 0
  | x :: xs -> x + sum xs
```

This is fine for small lists. It is not fine when input can be huge.

Better:

```ocaml
let sum xs =
  let rec loop acc = function
    | [] -> acc
    | x :: xs -> loop (acc + x) xs
  in
  loop 0 xs
```

For arrays in hot numeric code, an index loop is often the most predictable:

```ocaml
let sum_array a =
  let acc = ref 0.0 in
  for i = 0 to Array.length a - 1 do
    acc := !acc +. a.(i)
  done;
  !acc
```

Choose the simplest shape that matches the workload. Do not contort ordinary tree recursion into ugly accumulators unless stack growth is a real risk.

## Polymorphic Compare Is A Performance Smell

Polymorphic compare works by runtime dispatch over value representation. It is convenient and expensive.

Avoid it in:

- hot loops
- sort comparators
- map/set keys in performance-sensitive code
- public APIs where semantics should be explicit

Bad:

```ocaml
List.sort ~compare:Poly.compare xs
```

Better:

```ocaml
List.sort ~compare:Int.compare xs
```

Or use comparator-carrying containers from the local ecosystem.

This is both a speed and semantics issue. Polymorphic compare on functions is invalid, on structural values may surprise, and on abstract types may violate domain intent.

## Boxing Hazards To Watch For

- `float option` allocates on `Some`
- mixed records with float fields lose flat-float layout
- tuples of floats are boxed per float
- generic containers can force boxed representations
- `list` is pointer-heavy and cache-unfriendly for numeric bulk data
- arrays of pointers to boxed floats are much worse than flat float arrays

If you need dense numeric storage, use:

- `float array`
- float-only records when appropriate
- `Bigarray` for large foreign or IO-oriented buffers

## What Not To Do

- Do not use `Obj.magic` or representation tricks in application code.
- Do not call `Gc.full_major` or `Gc.compact` casually in ordinary request handling.
- Do not rely on finalizers for correctness.
- Do not cargo-cult mutable rewrites because "allocation is slow".
- Do not micro-optimize around imagined compiler magic; OCaml's runtime model is relatively direct.

## Finalizers Are Cleanup Hints, Not Resource Safety

Finalizers can run late, out of order relative to your hopes, or not at process exit.

Use explicit resource management for:

- files
- sockets
- locks
- transactions
- foreign handles with correctness requirements

Finalizers are acceptable for:

- backup cleanup
- leak detection
- logging
- best-effort release of external memory

Never make correctness depend on them.

## Benchmarking And Profiling Workflow

Use the narrowest tool the repo already supports.

Good options:

- `Core_bench` or repo-local benchmark harnesses
- `Gc.quick_stat ()` for rough allocation and collection counters
- Linux `perf` for CPU and call stacks
- generated assembly or compiler dumps for truly hot code

Measure:

- throughput
- latency
- allocated words
- promotions
- major collections
- memory footprint

Do not trust microbenchmarks alone. They are useful for confirming a local hypothesis, not for proving system-wide value.

## A Sensible Perf Triage Order

1. Confirm the path is actually hot.
2. Identify whether the problem is CPU, allocation, promotions, or memory.
3. Look for representation mismatches before touching GC knobs.
4. Remove obvious polymorphic operations and temporary allocations.
5. Consider layout changes: list to array, mixed record to split representation, boxed buffer to bigarray.
6. Re-measure.
7. Only then consider GC tuning.

## GC Tuning: Last, Not First

`Gc.tune` and `OCAMLRUNPARAM` are real tools, but they are not style choices.

Tune only when:

- profiling shows GC dominates runtime or latency
- workload is stable enough to justify configuration
- representation and algorithm issues are already under control

State the knob and the tradeoff explicitly:

- larger minor heap can reduce minor collections but increases memory
- major heap growth settings affect footprint and pause behavior
- allocation policy changes are niche and should be benchmark-backed

If you cannot explain why a knob helps this workload, leave it alone.

## Practical Good/Bad Examples

Bad: repeated append

```ocaml
let rec flatten = function
  | [] -> []
  | xs :: rest -> xs @ flatten rest
```

Better:

```ocaml
let flatten xss = List.concat xss
```

or a tail-recursive accumulator if needed.

Bad: string assembly by repeated concatenation

```ocaml
List.fold xs ~init:"" ~f:(fun acc x -> acc ^ render x)
```

Better:

```ocaml
let b = Buffer.create 128 in
List.iter xs ~f:(fun x -> Buffer.add_string b (render x));
Buffer.contents b
```

Bad: generic comparison in a hot path

```ocaml
if Stdlib.compare a b < 0 then ...
```

Better:

```ocaml
if Int.compare a b < 0 then ...
```

Bad: mutation chosen by instinct

```ocaml
t.count <- t.count +. 1.0
```

Maybe better:

```ocaml
{ t with count = t.count +. 1.0 }
```

Only measurement decides.

## Review Checklist For Agents

- What values allocate here?
- Are floats boxed unexpectedly?
- Is data short-lived enough that allocation is probably fine?
- Is mutation paying a write-barrier cost against old values?
- Is a list being used where an array or buffer better matches access pattern?
- Are polymorphic compare or equality in the hot path?
- Are closures being recreated inside tight loops?
- Is the problem really GC, or just too many temporary objects?
- Are finalizers being used for correctness?
- Is any proposed GC tuning backed by measurement?

## Bottom Line

OCaml is happiest when you:

- allocate short-lived values freely
- keep long-lived data shapes simple
- avoid unnecessary polymorphism in hot code
- respect float and container representations
- measure instead of guessing

Future agents do not need to memorize every tag number. They do need to see through source syntax to the runtime shape, because that is where most real OCaml performance decisions stop being mysterious.
