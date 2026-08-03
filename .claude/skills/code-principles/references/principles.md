# Expanded Principles with Examples

Deeper guidance and before/after examples for the rules summarized in SKILL.md. Examples use Swift, but every principle is language-agnostic.

## Contents
- [Naming in practice](#naming-in-practice)
- [Function extraction](#function-extraction)
- [Command–query separation](#commandquery-separation)
- [Error handling](#error-handling)
- [Null/nil discipline](#nulnil-discipline)
- [Objects vs data structures](#objects-vs-data-structures)
- [Boundaries](#boundaries)
- [System construction and wiring](#system-construction-and-wiring)
- [Contracts and assertions](#contracts-and-assertions)
- [Resource balancing](#resource-balancing)
- [DRY beyond code](#dry-beyond-code)
- [Test-driven development](#test-driven-development)
- [Debugging session shape](#debugging-session-shape)
- [Refactoring workflow](#refactoring-workflow)

## Naming in practice

Before:

```swift
func calc(_ d: [Double], _ f: Bool) -> Double {
    var t = 0.0
    for v in d { t += f ? v * 1.2 : v }
    return t
}
```

After removing the selector argument entirely:

```swift
func totalPrice(of items: [Double]) -> Double { items.reduce(0, +) }
func totalPriceWithTax(of items: [Double]) -> Double { totalPrice(of: items) * taxMultiplier }
```

Naming decision procedure:
1. Say out loud what the thing does/holds. The name is that sentence, compressed. Try several candidates — the search itself often improves the design.
2. Check it against its scope: wider scope → more descriptive; a 3-line loop earns `i`, a file-scope variable never does.
3. Check consistency: does the codebase already have a word for this concept? Use it. Does a standard pattern name apply (`Adapter`, `Factory`)? It communicates design for free.
4. Check honesty and precision: the name promises exactly what the code does — no more, no less, no ambiguity about the effect.

Supplying context via structure — instead of loose `street`, `city`, `zip` floating in a function, group them:

```swift
struct Address { let street: String, city: String, zip: String }
```

The type name gives every field its context; no `addrStreet` prefixes needed.

Keyword-form names make argument order self-documenting; Swift's argument labels do this natively (`move(from:to:)`) — use them, don't fight them.

## Function extraction

The "one thing" test: a function does one thing if you cannot extract another function from it whose name is not merely a restatement of its body. A second detector: if you can label sections inside the body ("setup", "validation", "the actual work"), it's several functions wearing one name.

Levels of abstraction must not mix — each line of a function sits exactly one level below the function's name:

```swift
func importWorkouts(from url: URL) throws -> [Workout] {
    let data = try readFile(at: url)          // I/O level
    let records = try parseCSV(data)          // format level
    return records.map(makeWorkout)           // domain level
}
```

Structural limits that keep functions honest: block bodies of `if`/`while` are one line (usually a call); nesting stays within one or two levels — use guard clauses / early returns to flatten. In small functions, multiple returns and `break`/`continue` are clearer than contorting toward a single exit.

Encapsulate conditionals rather than inlining logic:

```swift
// Bad
if session.endDate == nil && session.sets.isEmpty && session.startedAt < cutoff { ... }
// Good
if session.isAbandoned(before: cutoff) { ... }
```

## Command–query separation

A function either changes state (command) or answers a question (query, no side effects). Violations read as lies:

```swift
// Bad: query name, command behavior
func isLoggedIn() -> Bool   // ...also refreshes the token

// Good
func isLoggedIn() -> Bool
func refreshTokenIfNeeded() async throws
```

Side effects also create temporal couplings — the function is only safe to call "at the right time". If the coupling is unavoidable, expose it: name the function for the whole effect, or make the ordering structural by passing each step's output into the next (bucket brigade) so the compiler enforces the sequence.

## Error handling

Write the `do/try/catch` scaffold *first* — it defines the transaction scope and forces you to decide what a consistent state looks like on failure — then fill in and extract the happy path:

```swift
// Good: try/catch wraps one call; body extracted
func save(_ session: WorkoutSession) {
    do { try persist(session) }
    catch { logger.error("Failed to save session \(session.id): \(error)") }
}

private func persist(_ session: WorkoutSession) throws {
    let data = try encoder.encode(session)
    try data.write(to: storeURL)
    cache[session.id] = session
}
```

Design error types around how callers handle them, not around where errors originate. If every caller reacts the same way, one error type with a descriptive payload beats a taxonomy of cases nobody distinguishes. Add a separate case only when some caller genuinely needs to catch one and let another pass.

Error messages carry context: the operation, the identifier involved, the underlying cause. "save failed" is useless in a log at 3 a.m.

## Null/nil discipline

- Return empty collections instead of nil collections.
- Use the type system (Optional, Result, throws) so absence is impossible to ignore, rather than sentinel values (-1, "", 0) the caller can forget to check.
- Special-case object — define the normal flow: when many callers branch on "no value", return a neutral object that behaves correctly (`Discount.none` instead of a nil discount checked everywhere). Push the branching into the collaborator so the caller has a single unconditional path.

## Objects vs data structures

Pick the representation by the axis of change you expect:

- **Data structures + free functions**: adding a new *operation* is easy (one new function); adding a new *type* is hard (every function changes). Right when the set of types is stable and operations keep growing.
- **Objects + polymorphism**: adding a new *type* is easy (one new conformance); adding a new *operation* is hard (every type changes). Right when operations are stable and types keep growing.

Hiding data means abstraction. Reflexive getter/setter pairs around every field hide nothing — but a considered accessor is a legitimate abstraction point: it lets you later swap a stored value for a computed or cached one without touching callers (uniform access). The test is whether the accessor exposes the *essence* or the representation:

```swift
// Representation-exposing
fuelTankCapacityInLiters: Double; litersRemaining: Double
// Abstract
var fuelRemainingPercent: Double
```

Keep record-style types (Codable structs, database rows, Active Records) pure data; business rules live in separate objects that use them. Adding domain methods onto a record creates the worst of both: a hybrid.

## Boundaries

Wrap third-party dependencies in an interface you own:

```swift
protocol HealthStore {
    func heartRateSamples(in range: DateInterval) async throws -> [HeartRateSample]
}
struct HKHealthStoreAdapter: HealthStore { /* only file importing HealthKit */ }
```

- Confine even standard-library boundary types: a raw `[String: Any]` or third-party model type should not appear in your public signatures — it spreads every future change across the codebase.
- For an API that doesn't exist yet or that you don't control, define the interface you *wish* you had, code against it, and bridge later with an adapter. You get progress now and a testing seam forever.
- **Learning tests**: when adopting a library, write small tests that exercise its API the way you intend to use it. They teach you the library in isolation, and re-running them after upgrades detects behavioral breaking changes before your users do.

## System construction and wiring

Separate the *construction* phase from the *use* phase. Business logic never constructs its own collaborators:

```swift
// Bad: lazy init hard-codes the dependency and hides a second responsibility
final class SessionStore {
    private var health: HKHealthStoreAdapter?
    func sync() {
        if health == nil { health = HKHealthStoreAdapter() }
        ...
    }
}

// Good: constructed elsewhere, injected
final class SessionStore {
    private let health: HealthStore
    init(health: HealthStore) { self.health = health }
}
```

- Wire concrete objects in one composition root (the App/main entry point); dependencies point from the wiring side toward the application, never back.
- Use a factory when the *application* must control the moment of creation but shouldn't know the concrete type.
- Grow the architecture incrementally: implement today's requirements; defer each decision to the last responsible moment (the point of maximum information); choose the simplest design that works; adopt frameworks only for demonstrated value.
- Keep cross-cutting concerns (persistence, logging, security, caching) in their own modular layer instead of smeared through every domain object.

## Contracts and assertions

Think of every routine as a contract: what the caller must guarantee (preconditions), what the routine promises back (postconditions), what the type keeps true between calls (invariants). Even without language support, stating them sharpens the design:

```swift
/// Precondition: `sets` is non-empty and all belong to `session`.
/// Postcondition: returned volume > 0; `session` is unchanged.
func totalVolume(of sets: [WorkoutSet]) -> Double {
    precondition(!sets.isEmpty, "totalVolume requires at least one set")
    ...
}
```

- A violated precondition is a **bug in the caller**, never a user-input problem — validate user input with normal control flow, assert programmer guarantees.
- Assert whatever "can never happen" — and leave assertions on in production; real input is more hostile than any test suite. Assertion conditions must be side-effect-free, or checking changes behavior.
- Crash early on impossible states: an `assertionFailure`/fatal in a `default:` case that "can't be reached" stops a crippled program from limping on and corrupting data.
- Liskov via contracts: a subtype may accept more (weaker preconditions) or promise more (stronger postconditions) — never the reverse.

## Resource balancing

The code that acquires a resource releases it, visibly in the same scope. Scope-based release keeps the happy path and the error path from diverging:

```swift
func exportSessions() throws {
    let handle = try FileHandle(forWritingTo: exportURL)
    defer { try? handle.close() }          // runs on every exit path
    try writeHeader(to: handle)
    try writeSessions(to: handle)
}
```

- Releasing in both the success path *and* the catch block is a DRY violation — `defer`/RAII/`finally` exists so the release is written once.
- Deallocate in reverse order of acquisition; when several parts of the code acquire the same set of resources, acquire them in the same order everywhere — the classic deadlock preventive.
- For long-lived structures where strict acquire/release doesn't fit, pick one explicit ownership policy (owner frees substructures, or refuses to free while non-empty) and apply it consistently.

## DRY beyond code

DRY is about knowledge, not lines: every fact should have one authoritative home.

- **Derived data**: `var isEmpty: Bool { count == 0 }`, never a stored `isEmpty` maintained alongside `count`. A performance cache is a deliberate, documented exception hidden inside the owning type.
- **Comments**: prose restating code is a second copy of the knowledge that will drift; the code keeps the *what*, comments keep the *why*.
- **Multiple representations** (API client/server models, code mirroring a schema): generate the copies from one source as a build step rather than hand-maintaining them.
- **Configuration**: business policies, thresholds, and tuning values are knowledge that changes on a different schedule than code — keep them in data/config the code reads, not in compiled constants scattered through logic.

## Test-driven development

The three laws, forming a seconds-long cycle:
1. Write no production code until there is a failing test.
2. Write no more of a test than suffices to fail (compile errors count).
3. Write no more production code than suffices to pass.

Test code holds the same *cleanliness* bar as production code — but not the same *efficiency* bar. Readability may cost memory or CPU in tests; that trade is fine there and wrong in production.

Grow a domain-specific testing language: when tests drown in setup detail, extract helpers that read at the level of intent (`makeCompletedSession()`, `assertLevelUp(after:)`). It evolves from refactoring tests, not from up-front design. Structure each test Given-When-Then, one concept per test, minimal asserts. Good tests double as documentation: a newcomer should learn a class's API by reading its tests.

Testability is a design pressure, not just verification: code that's hard to test is telling you a class is too big, too coupled, or constructing its own dependencies.

## Debugging session shape

1. Reproduce first: reduce the failure to one minimal command/test before touching code. If you can't trigger it on demand, you can't know it's fixed.
2. Suspect in order: your most recent change → your code → configuration/environment → dependencies → platform ("select isn't broken" — the OS and compiler are almost never the culprit).
3. Localize by halving: confirm the symptom at two distant points, probe the midpoint, repeat. For timing-dependent bugs, add consistently formatted trace lines and post-process them instead of stepping.
4. When stuck, explain the code line by line out loud (rubber-ducking) — the skipped assumption is usually where the bug lives. Never wave a routine through as "known-good": prove it with this data at these boundaries.
5. Fix the root cause, not the surfacing symptom.
6. Close the loop: commit a regression test that fails without the fix, move validation closer to where the bad data enters, and grep for the same pattern elsewhere.

## Refactoring workflow

1. Ensure tests cover the behavior about to change; write characterization tests first if none exist.
2. Make one small, behavior-preserving transformation (rename, extract function, move method, inline variable).
3. Run tests. Green → commit or proceed; red → revert the step, don't debug forward.
4. Repeat. Never mix refactoring commits with behavior changes.

Expect non-linearity: refactoring is trial and error, and a later step often reverses an earlier one (re-inlining a function you extracted an hour ago). That churn is normal, not failure.

When to stop feature work and refactor: the moment keeping the mess starts making each new change harder. A tangle is cheap to clean while fresh and expensive once other code depends on it — "later" reliably becomes "never".

Order of operations when cleaning a messy function: first make it correct-and-tested, then rename for honesty, then extract by abstraction level, then simplify conditionals, then remove duplication.
