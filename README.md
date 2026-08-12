# Posture

A small macOS menu bar app that notices when you slouch and gives you one
quiet nudge. Everything runs on your Mac: no video leaves the device, no
account, no cloud.

**[Download the latest release](https://github.com/miskoune/posture/releases/latest/download/Posture.dmg)**
(signed and notarized, macOS 14+, Apple silicon) · site at
[posture.miskoune.com](https://posture.miskoune.com)

## How it works

1. **Calibrate once.** Sit the way you actually want to sit and press
   Calibrate. Posture remembers that pose as a handful of numbers: the angle
   of your neck, the height of your shoulders in frame.
2. **It watches the angle, not you.** A few times a minute it takes a frame
   from the camera, asks Apple's Vision framework for body landmarks, and
   compares them to your baseline. The frame is discarded on the spot; only
   the numbers survive.
3. **One nudge.** Drift past your tolerance for long enough and you get a
   single notification, replaced rather than stacked if you stay folded over,
   and withdrawn the moment you sit back.

Almost all of it lives in the menu bar. Behind it there is a dashboard window
with three pages: the live camera view with the verdict, this session's
stats, and settings.

## Private by construction

- **No network entitlement.** The sandbox grants the camera and nothing else.
  The app cannot open a socket even if a future version tried to, so the
  privacy claim is enforced by macOS, not promised by a policy.
- **The camera light is honest.** Solid green while monitoring, off while
  paused. The light maps one-to-one onto what the app is doing.
- **Nothing is stored.** No history, no photos, no analytics. Quit the app
  and the session's numbers are gone.

## How the app is put together

The Swift package has two layers with a hard boundary between them:

- **`PostureCore`** holds every rule and decision: what a reading is, how far
  you have drifted from your baseline, when a slouch has lasted long enough
  to deserve a banner. It imports Foundation only, so "two minutes of
  slouching" can be tested in microseconds with a fake camera and a fake
  clock.
- **`PostureApp`** is the macOS shell: AVFoundation for the camera, Vision
  for the landmarks, UserNotifications for the nudge, AppKit and SwiftUI for
  the menu bar and the dashboard. It implements the small set of protocols
  the core declares, and `main.swift` is the one place that wires the two
  together.

```
app/Sources/
  PostureCore/     imports Foundation only, compiles and tests anywhere
    Reading        one measurement: two ratios, never an image
    Baseline       the calibrated pose, and how far a reading has drifted
    Calibration    a run in progress, averaging away the unlucky frame
    SlouchTracker  when a slouch has lasted long enough to deserve the banner
    PostureMonitor the use case: look, judge, occasionally speak
    Ports          PostureSensor, NudgeDelivering, SettingsStoring, Clock
  PostureApp/      every macOS framework lives here and nowhere else
    PoseReader     Vision, the only file that knows what a pixel is
    CameraSensor   AVFoundation
    NotificationNudger, UserDefaultsSettings, StatusMenuController
    Dashboard/     the SwiftUI window: camera, stats, settings
    main.swift     the composition root
```

`PostureCore` names nothing from `PostureApp`. The protocols are declared by
the core and implemented on the outside, so the rules can be tested against a
fake camera and a fake clock, which is what `app/Tests` does.

## The repository

```
app/   the Mac app (Swift Package, no Xcode project)
src/   the website, posture.miskoune.com
```

## Licence

MIT.
