import Foundation

struct MapStyleURLProvider {
    let regionDefinition: any RegionDefinition
    let bundle: Bundle
    let fileManager: FileManager

    init(
        regionDefinition: any RegionDefinition,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        self.regionDefinition = regionDefinition
        self.bundle = bundle
        self.fileManager = fileManager
    }

    func topographicStyleURL() -> URL? {
        if let url = bundle.url(
            forResource: regionDefinition.topographicStyleResourceName,
            withExtension: "json"
        ) {
            return url
        }

        print("Missing map style JSON in app bundle")
        return nil
    }

    func openBareMapStyleURL() -> URL? {
        do {
            let resources = try OpenBareMapResources.bundled(in: bundle)
            return try OpenBareMapResources.prepareStyle(in: resources, fileManager: fileManager)
        } catch {
            print("Failed to prepare OpenBareMap style: \(error.localizedDescription)")
            return nil
        }
    }

    func satelliteStyleURL() -> URL? {
        let styleJSON = """
        {
          "version": 8,
          "name": "\(regionDefinition.satelliteStyleName)",
          "sources": {
            "esri-world-imagery": {
              "type": "raster",
              "tiles": [
                "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
              ],
              "tileSize": 256,
              "minzoom": 0,
              "maxzoom": 19,
              "attribution": "Sources: Esri, DigitalGlobe, GeoEye, i-cubed, USDA FSA, USGS, AEX, Getmapping, Aerogrid, IGN, IGP, swisstopo, and the GIS User Community"
            }
          },
          "layers": [
            {
              "id": "satellite-layer",
              "type": "raster",
              "source": "esri-world-imagery",
              "minzoom": 0,
              "maxzoom": 19
            }
          ],
          "center": [\(regionDefinition.defaultMapCenter.longitude), \(regionDefinition.defaultMapCenter.latitude)],
          "zoom": \(regionDefinition.defaultMapZoomLevel)
        }
        """

        let styleURL = fileManager.temporaryDirectory.appendingPathComponent(regionDefinition.satelliteStyleFilename)
        do {
            try styleJSON.write(to: styleURL, atomically: true, encoding: .utf8)
            return styleURL
        } catch {
            print("Failed to create satellite map style JSON: \(error.localizedDescription)")
            return nil
        }
    }

    func standardStyleURL() -> URL? {
        let styleJSON = """
        {
          "version": 8,
          "name": "\(regionDefinition.standardStyleName)",
          "sources": {
            "osm-standard": {
              "type": "raster",
              "tiles": [
                "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
              ],
              "tileSize": 256,
              "minzoom": 0,
              "maxzoom": 19,
              "attribution": "© OpenStreetMap contributors"
            }
          },
          "layers": [
            {
              "id": "standard-layer",
              "type": "raster",
              "source": "osm-standard",
              "minzoom": 0,
              "maxzoom": 19
            }
          ],
          "center": [\(regionDefinition.defaultMapCenter.longitude), \(regionDefinition.defaultMapCenter.latitude)],
          "zoom": \(regionDefinition.defaultMapZoomLevel)
        }
        """

        let styleURL = fileManager.temporaryDirectory.appendingPathComponent(regionDefinition.standardStyleFilename)
        do {
            try styleJSON.write(to: styleURL, atomically: true, encoding: .utf8)
            return styleURL
        } catch {
            print("Failed to create standard map style JSON: \(error.localizedDescription)")
            return nil
        }
    }
}
