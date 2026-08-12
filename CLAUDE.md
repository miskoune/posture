# Posture

A monorepo: the macOS menu bar app lives in `app/` (Swift Package), the
marketing site at the root (Astro 7). See README.md for build and release.

## Code quality

Load and apply the `code-principles` skill (Clean Code / Pragmatic
Programmer) before writing or refactoring any code in this repo, app or
site. In particular, keep these properties of the codebase true:

- `app/` is ports-and-adapters. Every rule and decision lives in
  `PostureCore` behind the protocols in `Ports.swift`, testable without a
  camera, timers, or real seconds. AppKit, AVFoundation, Vision, and
  SwiftUI never appear in `PostureCore`; they stay in `PostureApp`.
- `main.swift` is the only composition root: the one place allowed to name
  concrete types. Everything else receives protocols through its
  initializer.
- One authoritative home per piece of knowledge. Existing homes: camera
  session setup in `CaptureSetup`, live preview streaming in `CameraFeed`,
  setting defaults in `UserDefaultsSettings`, choice tables in
  `SettingsOptions`, user commands in `AppCommand`, nudge timing rules in
  `SlouchTracker`. Extend these rather than re-deriving their logic
  elsewhere.
- Comments explain why (constraints, trade-offs, non-obvious consequences),
  never restate what the code does.
- Any new rule or bug fix in `PostureCore` comes with a test; run
  `swift test --package-path app` before calling work done. Shell/UI code
  (`PostureApp`) is intentionally untested; keep it thin so that stays
  reasonable.

## Writing rules

- Never use em dashes (—) in user-facing copy: site text, app strings,
  notifications, FAQ answers, release notes, meta tags. They read as
  AI-generated. Use a period, comma, or colon instead. Code comments are
  exempt.
- Call it a "notification", never a "nudge", in user-facing copy: app
  strings, site text, README, release notes. Code identifiers and comments
  (NudgeDelivering, nudgeRepeat, NotificationNudger) keep the internal
  vocabulary.
