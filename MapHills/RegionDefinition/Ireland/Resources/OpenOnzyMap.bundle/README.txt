IRELAND WALKING MAP DATA BUNDLE 0.6.0

Contents
  ireland.mbtiles       Base vector map
  contours.mbtiles      20 metre contour lines
  environment.mbtiles   Coastline, woodland, bog and wetland
  hillshade.mbtiles     Light terrain shading
  hiking.mbtiles        Walking-relevant points of interest
  style/                 MapLibre style
  fonts/                 Local Open Sans glyphs
  sprites/               Empty; the current style does not require sprites

This bundle is ready to be embedded in an offline MapLibre-compatible map
application. It is not itself an installable phone app. The host application
must support MBTiles sources, resolve the mbtiles:// URLs in the style, and
serve the local glyph ranges.

Start view used during design:
  Carrauntoohil: longitude -9.7427, latitude 52.0005, zoom 13

Verify the files using SHA256SUMS.txt. Attribution and licence information is
in ATTRIBUTION.txt, NOTICE.txt and LICENSE-APACHE-2.0.txt.
