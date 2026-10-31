# BareGPS Ireland

BareGPS Ireland is an iOS hillwalking and mountain navigation app for exploring, recording, and logging hills across Ireland.

The app combines live and offline mapping, Irish hill classification data, GPX workflows, Go To navigation, grid references, weather forecasts, and a hill log register in one field-focused tool.

## Features

- View Irish hills on live MapLibre maps.
- Switch between OpenBareMap, topographic, standard, and satellite map styles.
- Show live position, heading, elevation, accuracy, and Irish grid reference.
- Record GPX tracks, including background recording while a recording is active.
- Import, save, reopen, rename, delete, export, and share GPX files.
- Use Go To navigation for hills or map points with live distance, bearing, heading, and on-map guidance.
- Download the optional OpenBareMap package for full-island offline mapping.
- Filter hills by height or classification.
- Surface Irish and British hill classifications, including Arderins, Vandeleur-Lynams, Highest Hundred, Carns, Binnions, Hewitts, Humps, Tumps, and Furths.
- Configure a local reference point for the Nearest 100 hill list.
- Log completed hills and review them in the Log Register.
- Search hills, logged hills, saved GPX files, waypoints, start points, trails, and Irish placenames.
- View Met Éireann weather forecasts for locations on the map.
- Open MountainViews pages for additional hill information.
- Customise hill marker colours, recorded track colours, imported track colours, and snail trail colour.
- Choose north-up or heads-up map orientation.

## Repository Layout

```text
.
|-- Data/                         # Reference/canonical data notes and sources
|-- Documentation/                # Technical and project documentation
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

The app target bundle identifier is:

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

### OpenBareMap

OpenBareMap is an optional downloadable map package that provides full-island offline coverage. Once installed, it works without a cellular or Wi-Fi connection and can be selected from the map-layer list. The package is approximately 1 GB and contains five MBTiles databases:

- `maps/basemap.mbtiles`
- `maps/topography.mbtiles`
- `maps/hillshade.mbtiles`
- `maps/grid.mbtiles`
- `maps/coast.mbtiles`

The app contains the MapLibre style, font glyphs, sprites, townlands, attribution, provenance metadata, and OpenBareMap legend used to present the downloaded map data.

The bundle lives at:

```text
MapHills/RegionDefinition/Ireland/Resources/OpenBareMap.bundle/
```

OpenBareMap downloads are managed in the app's Settings screen. Downloads are verified before installation, can continue through the iOS background-download system, and leave an existing installed map available until a replacement is ready. The package can be updated or removed without affecting GPX files, logged hills, or app settings.

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
MapHills/RegionDefinition/Ireland/Resources/OpenBareMap.bundle/ATTRIBUTION.txt
MapHills/RegionDefinition/Ireland/Resources/OpenBareMap.bundle/terrain-attribution.html
MapHills/RegionDefinition/Ireland/Resources/OpenBareMap.bundle/fonts/LICENSE-APACHE-2.0.txt
```
