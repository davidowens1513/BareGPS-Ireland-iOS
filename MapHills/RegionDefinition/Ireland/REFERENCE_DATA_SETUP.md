# Reference Data Setup

This app bundles CSV/GeoJSON reference data from a Desktop folder using a Run Script build phase. This lets you keep your data sources of truth outside the Xcode project and mirror them into the app bundle at build time.

- Source folder (local): `~/Desktop/baregps ireland 2.0`
- Destination (in app bundle at build time): `ReferenceData/`

Suggested layout inside the source folder (any layout is mirrored):

- `Hills/`
- `StartPoints/`
- `Trails/`

Add a Build Phase in Xcode (Target → Build Phases → + → New Run Script Phase) and set the script to:

