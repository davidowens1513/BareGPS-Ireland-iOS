# BareGPS Ireland Canonical Data

This folder contains the platform-neutral generated data package for BareGPS Ireland.

The files are intended to be shared by iOS, Android, and any future tooling so each platform uses the same known-good hill, start-place, trail-summary, and provider-mapping data.

Current files:

- `RegionPeakDataset.json`
- `MountainViewsStartPoints.json`
- `SportIrelandStartPoints.json`
- `CoillteStartPoints.json`
- `OutscapeTrailStartPoints.json`
- `CoillteTrailSummaries.json`
- `SportIrelandTrailSummaries.json`
- `OutscapeTrailSummaries.json`
- `SportIrelandTrailIDByStartPlaceID.json`

The iOS app currently loads matching copies from `MapHills/RegionDefinition/Ireland/Resources`. When this canonical package changes, sync the relevant JSON files into the iOS resources, rebuild, test, and commit both the canonical package and app resource copies together.

Raw source imports remain separate from this generated package. CSV is suitable for tabular source data such as hills and start places; GeoJSON is suitable for source trail geometry. The app-facing cross-platform format is JSON.
