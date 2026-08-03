---
name: code-principles
summary: Core principles for writing clean, maintainable code.
description: Actionable principles for writing and refactoring code, distilled from Clean Code and The Pragmatic Programmer. Use when (1) writing new functions, classes, or modules, (2) refactoring or cleaning up existing code, (3) debugging a defect, (4) naming things, structuring functions, or deciding how to handle errors, comments, tests, or system wiring, or (5) the user asks to apply "clean code" or pragmatic principles.
---

# Code Principles

Distilled, actionable principles for producing readable, maintainable code, drawn from *Clean Code* and *The Pragmatic Programmer*. Apply them as defaults, not dogma: match the conventions of the surrounding codebase first, and deviate when a rule would make the code genuinely worse.

## Core mindset

- Code is read far more often than it is written. Optimize for the reader.
- Push past "it works" toward clean and maintainable — but bound the polish by the actual requirements. Good-enough today often beats perfect later, and over-refinement past the quality bar spoils working code.
- Program deliberately, not by coincidence: if you can't explain why code works, you can't fix it when it breaks. Rely only on documented behavior of what you call; turn unproven assumptions into assertions; delete "just in case" calls left over from flailing.
- Clean code emerges through drafts. Write a rough working version, then refine it under tests — no one writes it clean on the first pass.
- No broken windows: fix bad code the moment you spot it. Can't fix it now? Visibly contain it (stub it, mark it) so no one builds on the rot. Quality is contagious in both directions — one tolerated mess invites more; pristine surroundings keep additions clean.
- Simple design, in priority order: (1) passes all tests, (2) no duplication, (3) expresses intent, (4) minimizes the number of classes and methods. Rule 4 is the counterweight: over-extraction into many tiny classes/methods is its own failure mode.
- Leave code cleaner than found (Boy Scout Rule) — but keep unrelated cleanups out of focused changes unless asked.
- Stop and refactor before the mess compounds; also step back periodically to check cumulative drift — systems rot one small unnoticed increment at a time.
- DRY is about knowledge, not just code: every piece of knowledge gets one authoritative representation. Before writing new logic, look for an existing implementation to reuse or extract; when the same structure must exist in several places, generate the copies from one source instead of hand-maintaining them.

## Naming

- Names must reveal intent: `elapsedDays`, not `d`. If a name needs a comment to explain it, the name failed. A long descriptive name beats a short name plus a comment.
- No mental mapping: the reader should never have to translate a name into the concept it stands for. Loop counters `i`/`j` are fine only in tiny scopes.
- Use pronounceable, searchable names; no magic numbers — name them as constants. Scope rule: short names for short scopes, descriptive names for wide scopes.
- Pick one word per concept (don't mix `fetch`/`get`/`retrieve`) and don't pun — never reuse a word for a semantically different operation.
- No cute/joke names; say what you mean. Prefer solution-domain terms (CS, patterns — naming a class `…Decorator` or `…Factory` communicates design) and problem-domain terms when no technical word exists.
- Classes/types: nouns (`WorkoutSession`). Functions: verbs (`saveSession`). Booleans: predicates (`isEmpty`). Names must be unambiguous about behavior — vague `doRename` loses to a name that states the full effect.
- Avoid encodings, prefixes, and noise words (`data`, `info`, `manager`, `helper`); leave interfaces unadorned (no `I` prefix — if one side must be marked, mark the implementation).
- Add context via structure, not prefixes: group loose variables into a named type (`Address`) instead of prefixing; never add gratuitous app/module prefixes to every name.
- Rename fearlessly — the moment a better name appears, take it; tooling makes it cheap.

## Functions

- Small. Blocks inside `if`/`else`/`while` should be one line — usually a call; indentation should rarely exceed two levels. If a function has visually separable "sections", it does more than one thing.
- One thing, one level of abstraction below the name; extract until each function's name fully describes its body.
- Few arguments: 0–2 ideal, 3 is a last resort; more means the arguments want to be an object. A legitimate single-argument function asks about its argument, transforms it and returns the result, or handles an event.
- No selector arguments — boolean flags, enums, or ints that switch behavior announce two functions in one. Split it.
- No hidden side effects: a function named `checkPassword` must not also initialize a session (side effects also create hidden temporal couplings — if order matters, expose it in names or thread each result into the next call). Command–query separation: do something or answer something, not both.
- Avoid output arguments; return the result. Early returns, `break`/`continue` are fine in small functions — clarity beats single-exit.
- Encapsulate complex conditionals in intent-revealing predicates (`shouldArchive(session)`); prefer positive conditionals over negated ones; break dense expressions into explanatory variables.
- For a nontrivial loop, state its invariant — what holds before the loop and after each iteration — to guard against off-by-one and boundary errors.
- A run of near-identical functions (same head/tail, differing middle) is a structural smell: factor the varying part out.
- A `switch`/type-`if` chain is tolerable only once, buried in a factory that creates polymorphic objects; everywhere else, prefer polymorphism.
- For overloaded constructors, prefer named static factory methods that describe the arguments.
- When you write a loop or recursion, do a quick complexity check (nested loop ≈ n², halving ≈ log n) and ask how big the input can realistically get; but confirm something is actually a bottleneck before optimizing — simple often beats asymptotically-faster for real input sizes.

## Comments

- The best comment is the one made unnecessary by better code. Before writing a comment, refactor so it isn't needed.
- Good comments: intent/why, warnings of consequences, amplification of why a trivial-looking line is critical, clarification of values from code you can't change, TODO with context, license pointer at file top, API docs for genuinely public APIs.
- Bad comments: restating the code (it duplicates knowledge and *will* drift out of sync), commented-out code (delete — version control remembers), journal/byline/changelog entries, banner dividers, closing-brace markers, mandated boilerplate on every function, HTML markup, information about distant code, essays where a reference would do.
- A comment must be well-written, accurate, and clearly attached to the code beside it.

## Formatting

- Small files: aim ~200 lines, rarely over 500. Lines ~100–120 characters max.
- Newspaper order: high-level first, detail below; caller above callee. Functions that are variants of one operation belong near each other.
- Blank lines separate concepts; tightly related lines stay dense with no gaps. Declare local variables near the top of their (short) function, loop variables in the loop, instance variables in one conventional place at the top of the class.
- Don't column-align declarations or assignments — if a list is long enough to "need" alignment, the class wants splitting. Never collapse a scope onto one line; make empty loop bodies visible with braces.
- Follow the project's existing formatter/style config; team consistency beats personal preference.

## Objects, data, boundaries

- Choose the style by the expected axis of change: data structures + functions make new *operations* easy; objects + polymorphism make new *types* easy. "Everything is an object" is a myth.
- Hiding data means abstraction: expose operations on the essence of the data, not its representation. Accessors are legitimate as abstraction points (they can later hide computation or caching); they are noise as reflexive get/set ceremony around every field.
- Derived data is duplicated knowledge: compute it, don't store it alongside its sources. If caching is needed for performance, keep that a deliberate, localized exception hidden inside the owning type.
- Objects hide data and expose behavior; data structures expose data and have no behavior. Don't build hybrids (an Active Record is a data structure — keep business rules in separate objects).
- Law of Demeter: avoid `a.getB().getC().doThing()` chains on objects (fine on plain data structures). It's a trade-off, not a law of physics — the forwarding methods it demands have a cost, and deliberately coupling two modules for a measured performance need is a legitimate, documented exception.
- Don't key your data on properties you don't control (a phone number as a customer ID — the outside world can reassign it).
- Wrap third-party APIs behind an interface you own; confine even standard-library boundary types (raw dictionaries, etc.) to the class that uses them — don't pass them through public APIs.
- For a dependency that doesn't exist yet or you don't control, code against the interface you wish you had and bridge with an adapter — it's also your testing seam.
- Write learning tests when adopting a library: small tests exercising the API the way you'll use it; re-run them on upgrades to catch breaking changes.
- Generated/scaffolded code becomes yours the moment it's in the application: understand it or don't keep it.

## Error handling, contracts, resources

- Write the try/catch(/finally) first — define the failure scope before the happy path, then extract the body so error handling is the function's only concern.
- Reserve exceptions for the genuinely exceptional. Litmus test: would the code still be correct with every handler removed? A user file that may plausibly be absent is a normal outcome — return an optional/result; exceptions used as control flow are a nonlocal goto. Never encode failure in silent sentinels (-1, "", 0) the caller can forget to check.
- Define error types by how callers will handle them — one type per handling strategy is usually enough; carry detail in the payload. Provide context: the operation, the identifier, the cause. Never swallow caught errors.
- Crash early on impossible states: a dead program does far less damage than a crippled one silently corrupting data. Give every switch a default that catches the "can't happen" value; don't assume calls that "can't fail" won't.
- Assert what can never happen. Assertions check programmer errors, not expected conditions; keep them side-effect-free; leave them enabled in production (real input is more hostile than any test suite), disabling only measured hotspots.
- Think in contracts: what must the caller guarantee (preconditions — their violation is a bug in the caller, never a user-input concern), what does the routine promise back (postconditions), what does the class keep true between calls (invariants)? Be strict in what you accept, promise as little as possible. A subtype may only loosen preconditions or strengthen postconditions (Liskov).
- Balance resources: the code that acquires releases, visibly in the same scope — use scope-based release (defer/RAII/finally) so the happy path and error path can't diverge. Deallocate in reverse acquisition order; acquire multiple resources in the same order everywhere (deadlock); never return or pass null/nil where an empty collection, optional, or special-case object works.

## Classes & systems

- Classes are small in responsibilities, not lines. SRP test: describe the class in ~25 words without "and"/"or"/"but". Can't find a concise name? Too big.
- Orthogonality: a change to one requirement should touch one module. Write "shy" code — reveal nothing unnecessary, depend on no other module's implementation; to change another object's state, ask that object to do it.
- Avoid global data and singletons-as-globals: every reference to shared mutable state couples you to everything else that touches it. Pass required context in explicitly.
- Member order: constants, then fields, then public methods with each private helper directly below its caller. Keep members private; loosen for a test only as a last resort.
- Open–Closed: add features by extension, not by editing tested code. Trigger to split responsibilities: actually having to open the class to change it — don't split speculatively.
- High cohesion: methods use most of the fields. When a subset of methods shares a subset of state, extract the class hiding inside.
- Separate construction from use: no `if (x == null) x = new …` inside business logic. Wire concrete objects in one place (main/composition root, factories, dependency injection) and hand them in.
- Keep decisions reversible: abstract the database to "persistence as a service", keep deployment shape a configuration concern, and treat vendor choices as revocable.
- Put volatile details — business policies, thresholds, tuning values — in configuration, not compiled code: abstractions in code, details in data. For long-running processes, make configuration reloadable.
- Decouple with events: let components subscribe to what they care about instead of routing everything through one dispatcher; keep models ignorant of their views.
- Grow architecture incrementally: implement today's requirements, defer decisions to the last responsible moment, use the simplest thing that works, adopt frameworks only for demonstrated value. Keep cross-cutting concerns (persistence, logging, security) modular, not smeared through domain logic.

## Concurrency

- Concurrency is a decoupling strategy (what runs vs when). Analyzing which steps are genuinely order-dependent — and removing the sequencing that isn't real — improves the design even if it never runs parallel.
- Keep threading code separate from business logic: plain thread-unaware objects called by a thin thread-aware layer.
- Design objects to be valid at all times, callable in any order: no split constructor-then-init window, no interfaces hiding call-to-call state that imposes a secret required sequence.
- Limit shared mutable state; prefer copies, immutable snapshots, or partitioned data over locks — and question why a global or shared variable exists at all before protecting it. When locking, guard the smallest possible critical section.
- Prefer battle-tested concurrency utilities and simple patterns — independent workers pulling from a shared queue beats a central scheduler. Design shutdown early; it's a classic deadlock source.
- Never dismiss a one-in-a-million threading failure as a fluke — it's a real bug. Test with more threads than cores, on every target platform, forcing varied interleavings.

## Tests

- Three Laws of TDD: write no production code without a failing test; write only enough test to fail; write only enough production code to pass.
- Test code must be as clean as production code (same readability bar; efficiency may be relaxed) — making code testable is itself a design force that pushes toward small, decoupled classes. If a unit test is hard to wire up, that difficulty is measuring coupling.
- Test your tests: a test that has never been seen to fail guards nothing — introduce the defect it targets and watch it go red.
- Find bugs once: every bug discovered anywhere becomes a permanent automated regression test, however trivial. And test that function exhaustively while you're there — bugs congregate.
- Derive cases from the contract: reject-invalid, accept-the-edge, sample-the-range. Test bottom-up — verify a module's parts before the module composing them, so composite failures localize instantly.
- Coverage tools find untested branches, but line coverage overstates safety — a fully "covered" line can still fail on the one input state you never tried. Think in input/state coverage; mix real-world data with synthetic data that forces boundaries and volume.
- One concept per test, minimal asserts, Given-When-Then structure; tests double as documentation. F.I.R.S.T.: Fast, Independent, Repeatable, Self-validating, Timely.
- Build a test window into deployed code: consistently formatted, parseable logs and status views, so behavior is observable with real data in the field.
- Building and running the full suite must each be one command.

## Debugging

- Don't panic, and don't say "that's impossible" — it's demonstrably happening, so one of your assumptions is wrong. Fix the problem, not the blame.
- Chase the root cause, not the symptom; the real fault is often upstream of where it surfaces.
- Before fixing, make the failure reproducible with one minimal command — isolating the trigger often reveals the cause. Watch the real failing scenario instead of trusting second-hand reports.
- The prime suspect is whatever changed last — your change, a dependency bump, an environment shift — however unrelated it seems.
- "select" isn't broken: the platform, compiler, and libraries are almost never the culprit — rule out your own code first.
- No obvious lead? Binary-search the failure: confirm the symptom at two distant points, test the midpoint, halve until localized. For time-dependent bugs, add consistently formatted trace output you can post-process.
- Rubber-duck it: explaining the code line by line forces out the assumption you keep skipping over. Don't assume a routine is fine — prove it with *this* data at *these* boundaries.
- After the fix: add the regression test that would have caught it, add earlier validation so bad data surfaces near its source, hunt the same pattern elsewhere, and share the broken assumption.

## Workflow

**When writing new code:** apply the rules above as you go — draft it working, then refine under tests before moving on.

**When facing the unknown:** shoot a tracer bullet — a thin end-to-end skeleton connecting all major components, built to keep (full error handling, real structure), then flesh it out. When one specific question needs answering (an algorithm, a library, a performance risk), build a throwaway prototype instead: correctness, robustness, and style deliberately don't apply, and the code is explicitly disposable — never shipped.

**When refactoring:** work under tests. Make small behavior-preserving steps; run tests between steps; expect some steps to be reversed later — refactoring is trial and error.

For expanded guidance and examples on any topic above, read [references/principles.md](references/principles.md).
