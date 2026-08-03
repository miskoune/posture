# Expanded Architecture Guidance

Deeper rules, litmus tests, and diagrams-in-words for the principles summarized in SKILL.md. All content is language- and framework-agnostic.

## Contents
- [The three paradigms](#the-three-paradigms)
- [SOLID in depth](#solid-in-depth)
- [Component cohesion and coupling](#component-cohesion-and-coupling)
- [Drawing and building boundaries](#drawing-and-building-boundaries)
- [Policy, level, and business rules](#policy-level-and-business-rules)
- [The Clean Architecture scenario](#the-clean-architecture-scenario)
- [Humble Objects and presenters](#humble-objects-and-presenters)
- [Partial boundaries](#partial-boundaries)
- [Main and configuration](#main-and-configuration)
- [Services](#services)
- [The test boundary](#the-test-boundary)
- [Embedded and hardware-adjacent code](#embedded-and-hardware-adjacent-code)
- [Databases, web, frameworks](#databases-web-frameworks)
- [Design method: actor and use-case analysis](#design-method-actor-and-use-case-analysis)
- [Code organization options](#code-organization-options)

## The three paradigms

Each paradigm removes a capability rather than adding one; together they tell you what not to do.

- **Structured programming** disciplines direct transfer of control (no goto). Its architectural lesson: correctness works like science, not math. Tests show the presence of bugs, never their absence, so decompose systems into small, falsifiable (testable) units.
- **Object orientation** disciplines indirect transfer of control (safe polymorphism). For an architect, OO is exactly one thing: the ability to gain absolute control over every source-code dependency via polymorphism. Normally a source dependency follows flow of control (caller names callee). Insert an interface and the implementation's dependency points backward, against control flow. Any dependency, anywhere, can be inverted; this is what makes the database and UI plugins to the business rules.
- **Functional programming** disciplines assignment (immutability). All race conditions, deadlocks, and concurrent-update problems come from mutable variables. Practical compromise: segregate mutability. Push most processing into immutable components; confine mutation to a few components protected by transactional discipline. Event sourcing is the extreme: store transactions, not state, and the store becomes append-only with no concurrent-update problem.

## SOLID in depth

### SRP
"A module should be responsible to one, and only one, actor." Not "do one thing" (that is a function-level rule). Actor = a group of stakeholders whose changes arrive for the same reasons.

Canonical violation: an `Employee` class with `calculatePay()` (finance), `reportHours()` (HR), and `save()` (DBAs). A shared private helper gets tweaked for finance and silently breaks HR's numbers. Fixes: split into one class per responsibility sharing a dumb data structure, optionally fronted by a Facade that instantiates and delegates.

Detection signals: unrelated teams repeatedly merge-conflicting in the same file; a change for one department breaking another's feature.

### OCP
Behavior extends through new code, not edits to working code. The ideal amount of existing code changed for a new variation is zero. Direction rule: if A must be protected from changes in B, B depends on A. Build a protection hierarchy: interactors (most protected, nothing depends outward from them), then controllers, then presenters, then views. Insert interfaces not only to invert dependencies but to hide internals so clients don't acquire transitive dependencies on things they don't use.

### LSP
S substitutes for T only if no program written against T can tell the difference. Applies to any set of implementations behind a shared contract: interfaces, duck-typed classes, multiple services behind one REST spec. The Square/Rectangle failure: independently settable width/height on Rectangle makes Square a behavioral misfit; callers must type-check, and substitutability is dead. At architecture scale, one partner API that spells a field differently forces `if (vendor == "acme")` special cases or an entire config-driven dispatch mechanism. A small substitutability violation buys a large amount of polluting mechanism.

### ISP
Split fat interfaces so each client depends only on the operations it calls; changes for other clients then can't force recompiles or redeploys. Generalized: depending on anything that carries baggage you don't need causes trouble you don't expect (a framework bound to a database binds you to that database even for features you never use).

### DIP
Refer only to abstractions; target the volatile concretions, not stable ones (platform strings and standard facilities are safe to name). Practices: don't reference volatile concrete classes (use factories for creation), don't derive from them (inheritance is the strongest dependency), don't override concrete functions (you inherit their dependencies). Violations can't reach zero; sweep them into a small number of dirty components (Main, factories) that instantiate the concretes and hand them to the abstract side.

The Abstract Factory shape: application code uses a `Service` interface and calls `ServiceFactory.makeService()`. On the concrete side of the line, `ServiceFactoryImpl` creates `ConcreteService`. Every source dependency crosses the line pointing toward the abstract side; flow of control crosses the other way.

## Component cohesion and coupling

Which classes belong in which deployable unit:

- **REP (Reuse/Release Equivalence)**: the granule of reuse is the granule of release. Classes in a component must share a purpose and make sense released together under one version.
- **CCP (Common Closure)**: gather what changes for the same reasons at the same times; separate what changes at different times. SRP for components: a change should be confined to one component.
- **CRP (Common Reuse)**: don't force users of a component to depend on classes they don't need; classes not tightly bound must not share a component. ISP for components.

These form a tension triangle. REP and CCP make components bigger; CRP makes them smaller. Abandon CRP and every change redeploys too many dependents; abandon REP and reuse dies; abandon CCP and every change touches too many components. Early-phase projects lean CCP; mature, reused code leans REP/CRP. The right grouping changes as the project matures.

Coupling rules:

- **ADP**: the component dependency graph is a DAG, no cycles. A cycle fuses its members into one de facto component: shared fate, no clean build order, giant test setups. Break a cycle by inverting one edge with an interface or extracting a component both sides depend on. The structure jitters; monitor it continuously. Component structure cannot be designed top-down; it maps buildability and volatility, not function.
- **SDP**: depend in the direction of stability. Instability I = fan-out / (fan-in + fan-out), in [0,1]. I must decrease along every dependency arrow. Not everything should be stable: volatile, easy-to-change components belong at the top of the graph with nothing depending on them.
- **SAP**: a component should be as abstract as it is stable. Abstractness A = abstract types / total types. Plot components on the A/I graph: the main sequence runs from (I=0, A=1) to (I=1, A=0). Distance D = |A + I - 1|; investigate anything far from zero. Zone of pain near (0,0): stable and concrete, rigid (a volatile schema everyone depends on). Zone of uselessness near (1,1): abstractions no one implements; delete them.

## Drawing and building boundaries

Where: along axes of change. Ask "do these two things change at different rates, for different reasons, at the request of different people?" Beyond the obvious rules|UI and rules|DB lines, look for delivery mechanism, human language, storage medium, network protocol, and vertical use-case slices; each is its own axis.

Boundary anatomy: a runtime crossing is just a function call passing data; what you manage is the source-code dependency. When a low-level client calls a high-level service, call it directly. When a high-level client must use a low-level service, the high-level side declares the interface and the data structures; the low-level side implements them. Boundary strengths, cheapest to strongest: source-level (monolith, chatty calls are fine), deployment-level (separate binaries, still cheap), local processes (limit chattiness), services (assume latency, avoid chat). At every strength: the higher-level side must not contain names, addresses, URIs, or keys of the lower-level side.

Timing: boundaries are expensive to build and much more expensive to retrofit. Don't implement every potential boundary; identify them, implement a few fully, sketch others partially, and watch. Implement a boundary at the inflection point where the cost of not having it exceeds the cost of building it. This decision is revisited for the life of the project.

Premature-decision smell: adopting frameworks, tiers, service meshes, or a database before any use case demands them. Counter-pattern: put an interface between rules and persistence, start with a stub or in-memory implementation, and let the "real database" decision defer, possibly forever. Side effects: fast tests and no schema churn.

True vs accidental duplication: true duplication means every change to one copy must be mirrored in the other; eliminate it. Accidental duplication is two things that look alike today but change for different reasons; unifying them welds two axes of change together. Screens, view models vs entities, request models vs records: usually accidental. Create the "duplicate" structure.

## Policy, level, and business rules

Level = distance from inputs and outputs. IO-handling code is low level; the central transformation is high level. Couple dependencies to level, not to data flow. Anti-example: `encrypt() { while(true) writeChar(translate(readChar())) }` has the highest-level policy calling IO directly. Fix: `Encrypt` owns `CharReader`/`CharWriter` interfaces; console implementations plug in.

- **Entities** = critical business rules + critical business data that would exist even without a computer (interest calculation, order validity). Litmus: would this class serve the business in any system, with any UI, any storage? Pure business and nothing else.
- **Use cases** = application-specific rules describing one automated interaction: input, processing steps, output, and how entities are directed ("use cases control the dance of the entities"). Use cases know entities; entities know nothing of use cases.
- **Request/response models**: plain data structures owned by the use case. Not framework request objects (that couples inward), not entity references (that welds two different rates of change together and looks like DRY but is accidental duplication).

Screaming architecture litmus tests: the top-level directory listing names the domain, not the framework; all use cases unit-test with no server running and no database connected; a new developer can learn what the system does without learning how it is delivered.

## The Clean Architecture scenario

Four schematic circles (more is fine; the rule is what matters), outermost to innermost: frameworks and drivers, interface adapters, use cases, entities. The Dependency Rule: source dependencies point only inward; no inner circle names anything declared outside, nor uses externally defined data formats.

Canonical request flow: the controller packs user input into a plain input model and calls the input-boundary interface. The use-case interactor implements it, pulls data through a data-access interface it owns (implemented in the database layer), directs entities, and builds a plain output model. It hands that to the output-boundary interface, implemented by the presenter, which formats everything into a view model of strings and flags. The view only copies view-model fields to the screen. Every arrow crosses each boundary pointing inward, even though flow of control runs outward to the presenter.

Data crossing any boundary is in the form most convenient for the inner circle.

## Humble Objects and presenters

Split behavior that is hard to test from behavior that is easy to test. The humble half keeps the bare untestable essence (the View: move data to the screen); the testable half does everything else (the Presenter: format dates and currency into strings, compute button names and enabled/grayed flags, fill the view model). Every architectural boundary tends to have a Humble Object near it, and rising testability is evidence you drew the boundary well.

Database gateways: one polymorphic interface per application need (`lastNamesOfUsersLoggedInAfter(date)`), no SQL above the database layer, implementations as humble objects, interactors tested against stubs. ORMs are data mappers, not object mappers (objects are behavior); they live in the database layer.

## Partial boundaries

A full boundary costs reciprocal polymorphic interfaces, input/output data structures, and independently deployable components. Placeholders, in decreasing strength:

1. Build the full separation but deploy as one component (no version administration). Risk: erosion without anyone noticing.
2. One-dimensional boundary: a Strategy interface between client and implementation. Only diligence prevents backchannel dependencies.
3. Facade: no inversion at all; the client transitively depends on everything. Cheapest, degrades fastest.

The architect's ongoing job is deciding where a boundary might one day exist and which of these to hold it with in the meantime.

## Main and configuration

Main is the ultimate detail: the entry point, the dirtiest component, the outermost circle. It creates the factories, strategies, and global facilities, holds the config strings, then hands control to high-level policy. Dependency-injection frameworks operate only inside Main; beyond it, pass dependencies by ordinary constructors. Treat Main as a plugin: keep one per configuration (dev/test/prod, per country, per customer), which turns configuration problems into plugin problems.

## Services

A service is a function call across a process or network boundary; some are architecturally significant, most are expensive function calls. Two fallacies:

- **Decoupling fallacy**: services stay coupled through shared data and resources. Add a field to a record that several services process, and they all change in lockstep. Service interfaces are no more rigorous than function interfaces.
- **Independence fallacy**: to the extent services share data or behavior, their development and deployment must be coordinated anyway.

Cross-cutting-concern test (the kitty problem): a functionally decomposed service chain forces a new cross-cutting feature to modify every service. Fix by componentizing inside each service: shared logic in abstract base components, each feature a derivative component created by factories, deployed by adding an artifact rather than editing services. Architectural boundaries run through services, not between them.

## The test boundary

Tests are system components: the outermost, most concrete circle, always depending inward, with nothing depending on them. Design them as part of the system.

- Fragile Tests Problem: tests coupled to volatile things (GUI navigation, page layout) break en masse on trivial changes, which teaches developers to resist change; fragile tests make production code rigid. Never verify business rules through the GUI.
- Structural coupling smell: one test class per production class, one test method per production method. Tests must grow ever more concrete while production code grows ever more abstract; coupling their structures blocks that divergence.
- Build a testing API: a superset of the interactors and adapters with superpowers to bypass security, skip expensive resources, and force the system into testable states. Its purpose is to hide the application's structure from the tests. If the superpowers are dangerous, ship it as a separate component that never reaches production.

## Embedded and hardware-adjacent code

Code is "firmware" because of what it depends on, not where it is stored: buried SQL and scattered platform calls are firmware by this definition, whatever the platform. Rules that generalize:

- Passing "make it work" without "make it right" fails the app-titude test; one file mixing domain logic, interrupt handlers, and storage details works and is still wrong.
- Insert abstraction seams: a HAL whose API speaks product language (`indicateLowBattery()`, not `ledOn(5)`), a processor abstraction confining vendor extensions to a few files, an OS abstraction so porting means rewriting the OSAL, not the app. Each seam exists to enable testing off the target platform; if you can only test on the real hardware/OS/database, development throttles on its availability.
- Header/interface hygiene: expose only what callers need; implementation-only types in shared headers create unwanted dependencies.
- Conditional-compilation smell: the same `#ifdef TARGET_X` repeated everywhere. Hide the target under the abstraction layer and bind via linker or runtime instead.

## Databases, web, frameworks

- The data model is architecturally significant; the database engine is a doorknob. Keep row/table knowledge in the lowest-level gateway code; frameworks that pass database rows around the system as objects violate the Dependency Rule. Storage performance is real but wholly encapsulable at low level. If politics demand a technology, bolt it on at the side behind a narrow channel; keep it out of the core.
- The industry oscillates forever between centralizing and distributing compute; the web is one oscillation. The GUI is an IO device. Find the moment input data is complete, execute the use case on a plain input structure, and hand the output structure back to the UI's chatty dance.
- Frameworks are asymmetric marriages: you commit maximally (derive from their base classes, import them into your core), they commit nothing. Risks: they want into your innermost circle, you may outgrow them, they may evolve away from you. Use, don't marry: keep them in outer-circle plugins, derive proxies rather than entities, keep DI wiring in Main. Some marriages (standard library) are unavoidable; make each an explicit decision.

## Design method: actor and use-case analysis

1. Identify the actors (e.g. viewer, purchaser, author, admin). Actors are the primary sources of change; partition so a change for one actor never affects another.
2. Identify use cases per actor. Where use cases substantially overlap, extract an abstract use case (general policy) with concrete variants inheriting from it; recognize the similarity early.
3. Form a preliminary component architecture: per actor, separate view, presenter, interactor, and controller components; shared abstract views/presenters live in common components.
4. Check the two dimensions of separation: by actor (different reasons to change, SRP) and by level (different rates of change, Dependency Rule). All dependencies cross boundaries pointing toward higher-level policy; inheritance arrows point against flow of control.
5. Keep deployment grouping flexible: structure the build so every component could ship independently, then combine into as few artifacts as currently convenient, regrouping as the system evolves. Flow of control runs controller to interactor to presenter to view; dependencies do not all follow it.

## Code organization options

Four ways to organize the same use case (controller, service interface and implementation, repository interface and implementation):

1. **Package by layer** (web/, service/, repository/): fast to start, screams nothing about the domain, and invites relaxed layering: someone injects the repository straight into the controller, skipping the business rules and their checks, while the dependency graph still looks clean.
2. **Package by feature** (orders/ holding all its types): screams the domain, localizes change per use case, and can make the controller the only public entry point.
3. **Ports and adapters / hexagonal** (inside domain, outside infrastructure; outside depends on inside): name inside types in domain language. Watch the ring-road anti-pattern: with all infrastructure in one tree and lax access modifiers, a controller can still bypass the domain to reach a repository.
4. **Package by component**: bundle a coarse-grained business capability with its persistence behind one component interface (`OrdersComponent`), UI separate. The repository types aren't public, so the compiler enforces "controllers never touch repositories." A well-componentized monolith is a stepping stone to microservices.

Cross-cutting rules: if every type is public, packages are just folders and all four styles collapse into the same layered mud, so minimize public types. Prefer compiler-enforced structure over discipline, review, or static-analysis regexes (they decay under deadline pressure). Stronger decoupling modes when warranted: module systems (published vs public types), separate source trees for domain vs infrastructure with a one-way compile-time dependency. Choose packaging, access modifiers, and decoupling mode deliberately; good design intentions die in implementation details.
