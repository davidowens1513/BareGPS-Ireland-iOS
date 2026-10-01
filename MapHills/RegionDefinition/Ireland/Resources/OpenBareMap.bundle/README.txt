OPENBAREMAP DATA BUNDLE 1.0.0

Contents
  ireland.mbtiles       Base vector map
  contours.mbtiles      20 metre contour lines
  environment.mbtiles   Coastline, woodland, bog and wetland
  hillshade.mbtiles     Light terrain shading
  hiking.mbtiles        Walking-relevant points of interest
  grid.mbtiles          Traditional all-island Irish Grid overlay
  style/                 MapLibre style, townland labels, and local style assets
  fonts/                 Local Open Sans glyphs
  sprites/               Bundled bog and crag pattern sprites

This bundle is ready to be embedded in an offline MapLibre-compatible map
application. It is not itself an installable phone app. The host application
must support MBTiles sources, resolve the mbtiles:// URLs in the style, and
serve the local glyph ranges, sprites, and style/townlands.geojson file.

Version 1.0.0 adds townland placename labels from TownlandsPlacenames.csv.
Townland labels use a lighter/different label treatment and are drawn from
zoom 12 upward.

Start view used during design:
  Ireland: longitude -8.15412, latitude 53.4, zoom 7

Verify the files using SHA256SUMS.txt. Attribution and licence information is
in ATTRIBUTION.txt, NOTICE.txt and LICENSE-APACHE-2.0.txt.
