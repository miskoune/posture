# Posture — the macOS app

A menu bar app that measures the angle of your neck and shoulders and tells you
once when you have been slouching for a while.

## Build it

Needs a Mac with Xcode 15 or later (macOS 14+).

```sh
cd app
./build.sh --run
```

That runs the tests, builds release, assembles `build/Posture.app`, ad-hoc signs
it with the sandbox entitlements, and launches it. Look for the figure icon in
the menu bar — there is no Dock icon and no window.

First launch asks for camera and notification permission. Then open the menu and
press **Calibrate** while sitting the way you actually want to sit.

```sh
swift test          # the rules, no camera required
```

## How it is put together

The boundary is the point of the whole layout:

```
Sources/
  PostureCore/     imports Foundation only — compiles and tests anywhere
    Reading        one measurement: two ratios, never an image
    Baseline       the calibrated pose, and how far a reading has drifted
    Calibration    a run in progress, averaging away the unlucky frame
    SlouchTracker  when a slouch has lasted long enough to deserve the banner
    PostureMonitor the use case: look, judge, occasionally speak
    Ports          PostureSensor, NudgeDelivering, SettingsStoring, Clock
  PostureApp/      every macOS framework lives here and nowhere else
    PoseReader     Vision — the only file that knows what a pixel is
    CameraSensor   AVFoundation, duty-cycled
    NotificationNudger, UserDefaultsSettings, StatusMenuController
    main.swift     the composition root
```

`PostureCore` names nothing from `PostureApp`. The protocols are declared by the
core and implemented on the outside, so the rules can be tested against a fake
camera and a fake clock — which is what `Tests/PostureCoreTests` does, including
"two minutes of slouching" in microseconds.

## Two decisions worth knowing

**The camera light is steady, not blinking.** While monitoring, the session
stays running and one frame is measured every few seconds; the light is simply
on. Duty-cycling the session per sample was tried first, but a blinking light
reads as the camera sneaking glances. Solid green while monitoring, off while
paused — the light maps one-to-one onto what the app is doing.

**There is no network entitlement.** `Resources/Posture.entitlements` grants the
sandbox and the camera, nothing else. The app cannot open a socket even if a
later version tried to — which is the product claim, enforced by the OS rather
than promised in a privacy policy. Do not add one without arguing about it.

## What is not built yet

- Pausing during screen sharing and calls
- Anything for an external webcam beyond what macOS exposes by default
- A Developer ID signature — the ad-hoc one only works on the machine that built it
- An app icon
