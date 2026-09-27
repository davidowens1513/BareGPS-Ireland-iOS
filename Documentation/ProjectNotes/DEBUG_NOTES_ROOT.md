# Debug Notes

## What I changed in the app code

- I first simplified startup in `AppDelegate` and `SceneDelegate` to remove anything that might block launch.
- I rolled those changes back when they did not fix the green-screen hang.
- I then made `SceneDelegate` explicitly create a `UIWindow` and set the root controller programmatically.
- After that, I removed the scene-based path entirely and rewrote `AppDelegate` so it creates the window and root controller itself.
- I also removed the `UIApplicationSceneManifest` from `Info.plist` so the app no longer depended on a scene manifest.
- I left `MapViewController` in its deferred-bootstrap form, because the launch failure was happening before any of that UI could plausibly matter.

## What I verified in the source

- `MapHills/Core/Map/MapViewController.swift` still has:
  - `viewDidLoad` only setting background color
  - `viewDidAppear` scheduling bootstrap
  - `bootstrapInitialInterfaceIfNeeded()` creating the map and the rest of the UI later
- `MapHills/Core/AppLifecycle/SceneDelegate.swift` was changed to create a window manually, then later the scene path was removed entirely.
- `MapHills/Core/AppLifecycle/AppDelegate.swift` now creates the window and sets `ViewController()` as root directly.
- `MapHills/Packaging/Info.plist` no longer has a scene manifest.
- The `Main.storyboard` initial view controller still exists and points at `ViewController`, but the code path no longer depends on it.

## What I checked in Xcode/build settings

- `Application Scene Manifest (Generation)` is already set to `No`.
- `UIKit Main Storyboard File Base Name` is blank now.
- `Launch Screen File` is still `LaunchScreen`, which is correct.
- Earlier, the project file had been carrying `INFOPLIST_KEY_UIMainStoryboardFile = Main`, and I kept pressing on that because it matched the classic launch-screen trap.

## What I tried to diagnose launch behavior

- I asked Xcode for runtime output from the launch path.
- I tried `log show` from the shell, but the environment refused access to system logging.
- I tried `xcodebuild`/simulator-style inspection, but the local simulator service is broken in this session.
- I tried to use the build log as a proxy for runtime, but that only told me about build and package issues, not the app process itself.

## What the build logs showed

- At first, the app built successfully.
- Later, the build started failing for the same specific reason every time:
  - `There is no XCFramework found at '/Users/davidowens/Library/Developer/Xcode/DerivedData/Maphills-axowxehudumszjbpvvhforoxfigs/SourcePackages/artifacts/maplibre-gl-native-distribution/MapLibre/MapLibre.xcframework'`
- That means the current blocking issue is not the launch-screen code anymore; it is the MapLibre package artifact not being present in Derived Data.

## What I verified about the package

- The project is linked to the remote package:
  - `maplibre-gl-native-distribution`
- The build failure specifically references the package artifact path in Derived Data, not an app source compile error.
- I also hit SwiftPM cache/manifest issues earlier:
  - `cannot open file ... maplibre-gl-native-distribution.dia for diagnostics emission (Operation not permitted)`
- So the package cache in this environment appears unhealthy.

## What I concluded along the way

- The original green-screen hang was very likely obscuring the fact that the app lifecycle was misconfigured.
- I corrected the lifecycle wiring as far as source code goes.
- After that, the real blocker shifted to package resolution / missing XCFramework artifacts.
- The app still cannot be fully tested until MapLibre resolves cleanly again.
- Because the local simulator service is broken here and SwiftPM cache access is restricted, I could not capture trustworthy runtime console output from this session.

## Current state

- App startup code is now simplified and no longer depends on storyboard scene autowiring.
- The launch-screen settings are no longer the obvious blocker.
- The build currently fails on a missing MapLibre XCFramework in Derived Data.
- I have not been able to capture true runtime logs from the device/simulator in this environment.

## Next step

If you want to keep going from here, the next useful step is to fix the package cache state:

1. Use Xcode’s `File > Packages > Reset Package Caches`.
2. Use `File > Packages > Resolve Package Versions`.
3. Build again.

If it still fails after that, the MapLibre package reference itself needs inspection.
