# BareGPS Ireland

BareGPS Ireland is an iOS hillwalking and mountain navigation app for exploring, recording, and logging hills across Ireland.

The app combines live mapping, Irish hill classification data, GPX workflows, offline map caching, Go To navigation, grid references, and a hill log register in one field-focused tool.

## Features

- View Irish hills on live MapLibre maps.
- Switch between topographic, standard, and satellite map styles.
- Show live position, heading, elevation, accuracy, and Irish grid reference.
- Record GPX tracks, including background recording while a recording is active.
- Import, save, reopen, rename, delete, export, and share GPX files.
- Use Go To navigation for hills or map points with live distance, bearing, heading, and on-map guidance.
- Cache map areas for offline use before a walk.
- Filter hills by height or classification.
- Surface Irish and British hill classifications, including Arderins, Vandeleur-Lynams, Highest Hundred, Carns, Binnions, Hewitts, Humps, Tumps, and Furths.
- Configure a local reference point for the Nearest 100 hill list.
- Log completed hills and review them in the Log Register.
- Search hills, logged hills, saved GPX files, waypoints, start points, trails, and Irish placenames.
- Customise hill marker colours, recorded track colours, imported track colours, and snail trail colour.
- Choose north-up or heads-up map orientation.

## Repository Layout

```text
.
|-- Data/                         # Reference/canonical data notes and sources
|-- Documentation/                # Project notes, review notes, and work logs
|-- MapHills/                     # Main iOS app target
|   |-- Branding/                 # App branding and App Store/support copy
|   |-- Core/                     # App lifecycle, domain models, map logic, overlays
|   |-- Packaging/                # App packaging resources such as Info.plist
|   `-- RegionDefinition/Ireland/ # Ireland-specific data, styles, classifications
|-- MapHillsTests/                # Swift Testing unit tests
|-- MapHillsUITests/              # UI automation tests
|-- Scripts/                      # Project support scripts
`-- Maphills.xcodeproj            # Xcode project
```

## Requirements

- Xcode with iOS SDK support for the project deployment target.
- iOS 18.2 or later deployment target.
- Swift 5 project settings.
- MapLibre Native package dependency.

The app target bundle identifier is currently:

```text
com.DavidOwens1513.BareGPSIreland.MapHills
```

## Getting Started

1. Clone the repository.
2. Open `Maphills.xcodeproj` in Xcode.
3. Let Xcode resolve the MapLibre Native package dependency.
4. Select the `MapHills` scheme.
5. Build and run on a simulator or device.

For device testing, configure signing to use your own Apple Developer team if needed.

## Reference Data

The Ireland region lives under:

```text
MapHills/RegionDefinition/Ireland/
```

That area contains:

- Ireland-specific region configuration.
- Hill classification derivation rules.
- Bundled map style resources.
- OpenBareMap resources.
- Reference data setup notes.

Additional reference data notes are in:

```text
Data/Ireland/Canonical/README.md
MapHills/RegionDefinition/Ireland/REFERENCE_DATA_SETUP.md
```

## Build And Test

From Xcode, use:

- Product > Build
- Product > Test

The test target uses Apple's Swift Testing framework for unit tests, with a separate UI test target for automation.

## Hill Classifications

Ireland-specific classification logic is implemented in:

```text
MapHills/RegionDefinition/Ireland/IrelandPeakClassifications.swift
```

The app derives classifications from hill height, prominence, county highpoint data, range membership, province membership, and local reference-point distance.

Examples include:

- Arderin
- Arderin Beg
- Vandeleur-Lynam
- Highest Hundred
- Carn
- Binnion
- County Highpoint
- Range Highpoint
- Province Top 50
- Hewitt
- Marilyn
- Hump
- Tump
- Furth

## Location And Privacy

Location access is used for map position, grid references, Go To navigation, GPX recording, and related live navigation features.

Background location is used only while GPX recording is active, so a walk can continue to be recorded while the app is minimised or the screen is locked.

App Store support and privacy copy lives in:

```text
MapHills/Branding/AppStore/
```

## Attribution

BareGPS Ireland uses MapLibre Native for map rendering.

The app includes or references Irish hill, trail, placename, map, and OpenBareMap resources. Check the bundled resource notices and source-specific documentation before redistributing data or publishing builds.

Relevant bundled notices include:

```text
MapHills/RegionDefinition/Ireland/Resources/OpenBareMap.bundle/LICENSE-APACHE-2.0.txt
MapHills/RegionDefinition/Ireland/Resources/OpenBareMap.bundle/NOTICE.txt
```

## Status

This is an active iOS project for BareGPS Ireland. Expect ongoing changes around mapping, GPX workflows, hill classification display, offline caching, and field-navigation ergonomics.
