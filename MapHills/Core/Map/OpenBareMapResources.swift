import Foundation

/// Resolves the packaged OpenBareMap resources into a MapLibre-compatible style URL.
enum OpenBareMapResources {
    enum ResourceError: Error {
        case missingBundle
        case missingResource(String)
        case invalidManifest
        case invalidStyle
    }

    static func bundled(in application: Bundle = .main) throws -> Bundle {
        guard let url = application.url(forResource: "OpenBareMap", withExtension: "bundle"),
              let bundle = Bundle(url: url) else {
            throw ResourceError.missingBundle
        }
        return bundle
    }

    static func prepareStyle(in bundle: Bundle, fileManager: FileManager = .default) throws -> URL {
        let root = bundle.bundleURL
        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let manifest = try JSONSerialization.jsonObject(
            with: Data(contentsOf: manifestURL)
        ) as? [String: Any],
              let sourceFiles = manifest["sourceFiles"] as? [String: String] else {
            throw ResourceError.invalidManifest
        }

        let styleURL = root.appendingPathComponent("style.json")
        guard var style = try JSONSerialization.jsonObject(
            with: Data(contentsOf: styleURL)
        ) as? [String: Any],
              var sources = style["sources"] as? [String: [String: Any]] else {
            throw ResourceError.invalidStyle
        }

        for (name, relativePath) in sourceFiles {
            let fileURL = root.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: fileURL.path),
                  var source = sources[name] else {
                throw ResourceError.missingResource(relativePath)
            }

            source.removeValue(forKey: "tiles")
            source["url"] = "mbtiles://" + String(fileURL.absoluteString.dropFirst("file://".count))
            sources[name] = source
        }

        guard var townlands = sources["townlands"] else {
            throw ResourceError.invalidStyle
        }
        townlands["data"] = root.appendingPathComponent("townlands.geojson").absoluteString
        sources["townlands"] = townlands

        style["sources"] = sources
        style["glyphs"] = root.appendingPathComponent("fonts").absoluteString + "/{fontstack}/{range}.pbf"
        style["sprite"] = root.appendingPathComponent("sprites/outdoors").absoluteString

        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("OpenBareMap-" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("style.json")
        try JSONSerialization.data(withJSONObject: style, options: [.sortedKeys])
            .write(to: destination, options: .atomic)
        return destination
    }
}
