---
name: clean-architecture
summary: Architectural principles for structuring systems, from Clean Architecture.
description: Actionable architecture principles distilled from Clean Architecture (Robert C. Martin). Use when (1) designing or restructuring a system, service, or module layout, (2) deciding where to place business logic, database access, UI, or framework code, (3) drawing component or service boundaries, (4) choosing a project/package structure, (5) evaluating coupling, dependency direction, or testability problems, or (6) the user asks to apply "clean architecture", hexagonal, or ports-and-adapters ideas.
---

# Clean Architecture

Distilled, actionable principles for structuring software systems, drawn from *Clean Architecture* by Robert C. Martin. Apply them as defaults, not dogma: scale the ceremony to the project's size and volatility, and prefer the simplest structure that keeps the important decisions reversible.

## Core mindset

- The goal of architecture is to minimize the human effort required to build and maintain the system. Measure it by effort per change over time: if every release costs more than the last, the design is failing.
- Software has two values: behavior (works now) and structure (easy to change). Structure is the greater value; fight for it as a stakeholder, because no one else will.
- "We'll clean it up later" is a lie; the only way to go fast is to go well. Starting over from scratch is the same overconfidence that made the mess.
- Separate high-level policy (business rules, the true value) from low-level detail (IO, database, web, frameworks, delivery). A good architect maximizes the number of decisions *not* made: defer every detail decision as long as possible, because late decisions are made with more information.
- Difficulty of a change should be proportional to its scope, not its shape (how it happens to fit the existing structure).

## The Dependency Rule

- Organize code in concentric layers, outermost to innermost: frameworks and drivers (web, DB, devices), interface adapters (controllers, presenters, gateways, all SQL and format conversion), use cases (application-specific rules), entities (enterprise-wide critical rules). Inward means higher-level, more abstract, more stable.
- **Source-code dependencies must point only inward, toward higher-level policy.** Nothing in an inner circle may mention any name declared in an outer circle, nor use data formats defined outside (especially framework types).
- When flow of control goes outward (use case calls presenter), invert the source dependency: the inner circle owns an output-port interface; the outer circle implements it. Polymorphism lets you point any dependency any direction, regardless of control flow.
- Data crossing a boundary is a simple, isolated data structure shaped for the inner side. Never pass entities, framework requests, or database rows across.
- Level = distance from inputs and outputs. Couple dependencies to level, not to data flow: urgent, trivial changes (UI, formats) must never be able to touch important, stable code (rules).
- Everything volatile is a plugin to everything stable. The plugin can be broken by the core, never the reverse; put the important side on the immune side of every boundary.

## SOLID, architecturally

- SRP: a module is responsible to one and only one actor (a group of stakeholders requesting changes for the same reason). Symptoms: one class serving accounting, HR, and DBAs; merge conflicts from unrelated teams in one file. Fix: separate code that different actors depend on.
- OCP: add behavior with new code, not edits to old code. If A must be protected from changes in B, then B must depend on A; arrange all dependencies to point toward what you protect most.
- LSP: every implementation behind an interface must be substitutable without callers knowing. One non-conforming implementation forces special-case checks that pollute the whole architecture; never hard-code a vendor or variant name into logic.
- ISP: don't force clients to depend on methods they don't use; depending on anything that carries baggage you don't need causes trouble you don't expect.
- DIP: refer only to abstractions, never to *volatile* concretions (stable platform types are fine). Don't derive from, override, or even name volatile concrete classes. Gather the unavoidable concrete instantiations into a few dirty components, typically Main and factories.

## Components

- A component is a unit of deployment. Group classes by cohesion principles: release together what is reused together (REP), gather what changes together for the same reasons (CCP), don't force dependents to carry what they don't use (CRP). These three pull against each other: early projects favor CCP (develop-ability), mature ones drift toward REP/CRP (reuse). The grouping evolves; revisit it.
- Allow no cycles in the component dependency graph. Break cycles with an interface (DIP) or by extracting a shared component.
- Depend in the direction of stability: instability I = fan-out / (fan-in + fan-out); I must decrease along every dependency. A component should be as abstract as it is stable (put policy in stable abstract components, details in unstable concrete ones). Distance from the main sequence D = |A + I - 1|; investigate components far from 0. Avoid the zone of pain (stable and concrete, e.g. a widely-depended-on schema) and the zone of uselessness (abstract with no dependents: delete it).

## Boundaries

- Draw boundaries along axes of change, where two sides change at different rates for different reasons: rules|GUI, rules|DB, rules|delivery mechanism, and also between use-case slices vertically. "UI / rules / DB" is rarely the full set.
- The interface at a boundary is owned by the higher-level side (its user), not by its implementer. The gateway interface the use case calls lives with the use case; the implementation lives with the detail.
- Boundaries are expensive; don't build every potential one (YAGNI), but don't ignore them. Watch the system as it evolves and implement a boundary at the inflection point where the friction of its absence exceeds its cost. Cheaper placeholders while you wait: same structure deployed as one unit, a one-dimensional Strategy interface, or a Facade; each erodes without diligence.
- Decoupling modes, cheapest first: source-level (monolith), deployment-level (separate binaries), service-level (network). Let a system be born a monolith and grow into services; defaulting to microservices buys the most expensive mode before you know where the boundaries belong.
- Distinguish true duplication (every change mirrored: eliminate it) from accidental duplication (similar now, evolving apart: keep separate). Two similar screens, or an entity that resembles a view model, are almost always accidental; resist knee-jerk unification.

## Business rules

- Entities hold critical business rules and data that would exist even without a computer; pure business, no framework, no persistence, no UI awareness. Litmus: could this class serve the business in any system?
- Use cases orchestrate entities for one application-specific interaction: input data in, processing, output data out. From the use-case code it must be impossible to tell whether delivery is web, CLI, or service.
- Use cases accept and return plain request/response models, never framework types and never entity references.
- Screaming architecture: the top-level structure should scream the domain ("accounting", "orders"), not the framework. New developers should learn all the use cases before learning how the system is delivered.

## Details stay details

- The database is a detail; the data model is not. Keep knowledge of tables/rows in the lowest-level gateway implementations; never let database structures travel through the system. ORMs are data mappers and belong in the database layer.
- The web is an IO device. You can't abstract the chatty UI dance, but you can collect input until it's complete, execute the use case with a plain input structure, and hand the output structure back to the dance.
- Use the framework, don't marry it: it's an asymmetric commitment (you commit, its authors don't). Keep it behind a boundary; derive proxies in plugin components, never your entities from its base classes; wire DI only in Main. Unavoidable marriages (standard library) are fine, but make each one an explicit decision.
- Main is the dirtiest, lowest-level component: it creates factories and concrete implementations, holds config, then hands control to the policy. Treat Main as a plugin and keep one per configuration (dev/test/prod, per customer).

## Services and tests

- Services are function calls across a network, not an architecture. They stay coupled through shared data (add a field to a shared record and every service changes) so the fallacies of "independent" development and deployment need checking. Architectural boundaries run *through* services, dividing them into components that obey the Dependency Rule; a cross-cutting feature should be a new component dropped in, not an edit to every service.
- Tests are the outermost component: they depend inward, nothing depends on them. Don't test business rules through the GUI (fragile tests make production code rigid), and avoid one-test-class-per-production-class structural coupling. Provide a testing API (superset of the interactors) that hides the application's structure and can bypass security and expensive resources; ship it as a separate component. Testability is the cheapest continuous audit of your boundaries: needing the framework, DB, or GUI to test a rule means a boundary is missing or leaking.

## Workflow

**When designing a system:** start with actor and use-case analysis. Actors are the primary sources of change; partition so a change for one actor never touches another. Separate along two dimensions: by actor (reasons to change) and by level (rates of change). Keep deployment grouping flexible: structure the build so components *could* ship independently, and reserve the right to combine them.

**When choosing code organization:** package by layer scales worst (invites bypassing the rules); package by feature screams the domain; ports-and-adapters separates inside from outside; package by component (feature plus its persistence behind one interface) is the strongest monolith default. Whatever you pick, minimize public types so the compiler, not discipline, enforces the architecture; if everything is public, all four styles collapse into the same mud.

For expanded guidance, diagrams described in words, and litmus tests for every topic above, read [references/architecture.md](references/architecture.md).
