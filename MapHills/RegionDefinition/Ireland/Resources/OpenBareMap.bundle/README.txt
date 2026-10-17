BAREGPS IRELAND 2.0 MAP PACKAGE
OpenBareMap map-data version 1.1.0

This is the complete offline mapping payload prepared for incorporation into
BareGPS Ireland 2.0. The application version and map-data version are separate:

  Application: BareGPS Ireland 2.0
  Map data:    OpenBareMap 1.1.0

Runtime entry point
  baregps-style.json

Runtime contents
  ireland.mbtiles       Main vector basemap
  contours.mbtiles      Contour lines and elevation labels
  environment.mbtiles   Land cover, coast and terrain detail
  hillshade.mbtiles     Raster terrain shading
  hiking.mbtiles        Dedicated hiking points
  grid.mbtiles          Irish National Grid overlay
  islands.mbtiles       Island-name centroids
  style/townlands.geojson
                         Townland names
  fonts/                 Offline Open Sans glyph ranges
  sprites/               Bog pattern and crag/cliff sprite sheets

Additional contents
  documentation/         Current map legend
  build-sources/         Reproducibility configuration and Lua processing files
  INTEGRATION.txt        Host-app integration contract
  manifest.json          Machine-readable package manifest
  SHA256SUMS.txt         Integrity hashes for every bundled file
  ATTRIBUTION.txt        Data and asset attribution
  NOTICE.txt             Distribution and display requirements

The package is offline and self-contained. It does not require a web tile
service. Verify it with:

  shasum -a 256 -c SHA256SUMS.txt

