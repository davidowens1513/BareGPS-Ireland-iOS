import Foundation
import Testing

@Suite("Reference Data Verifier")
struct ReferenceDataVerifierTests {

    private func bundledURL(_ name: String, ext: String) -> URL? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "ReferenceData") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        #endif

        let bundles: [Bundle] = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "ReferenceData") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func detectDelimiter(in headerLine: String) -> Character? {
        let candidates: [Character] = [",", ";", "\t"]
        var best: (char: Character, count: Int)? = nil
        for c in candidates {
            let count = headerLine.filter { $0 == c }.count
            if count > 0, (best == nil || count > best!.count) {
                best = (c, count)
            }
        }
        return best?.char
    }

    private func assertCSVBasicIntegrity(resourceName: String) throws {
        let url = try #require(bundledURL(resourceName, ext: "csv"), "Missing \(resourceName).csv in ReferenceData")
        let content = try String(contentsOf: url, encoding: .utf8)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!trimmed.isEmpty, "\(resourceName).csv is empty")

        let lines = content.split(whereSeparator: \.isNewline)
        let header = try #require(lines.first.map(String.init), "\(resourceName).csv is missing a header row")

        // Detect a plausible delimiter in the header
        if let delimiter = detectDelimiter(in: header) {
            let headerCols = header.split(separator: delimiter)
            #expect(headerCols.count >= 2, "\(resourceName).csv header appears to have too few columns")

            if lines.count >= 2 {
                let firstDataLine = String(lines[1])
                let dataCols = firstDataLine.split(separator: delimiter)
                #expect(dataCols.count == headerCols.count, "\(resourceName).csv first data row column count doesn't match header")
            }
        } else {
            // If no delimiter is detected, at least ensure the file has more than one line
            #expect(lines.count >= 2, "\(resourceName).csv has no data rows")
        }
    }

    @Test("MountainViews start points CSV is bundled")
    func mountainViewsStartPointsCSVExists() throws {
        let url = bundledURL("MountainViewsStartPoints", ext: "csv")
        _ = try #require(url, "Missing MountainViewsStartPoints.csv in ReferenceData")
    }

    @Test("Coillte start points CSV is bundled")
    func coillteStartPointsCSVExists() throws {
        let url = bundledURL("CoillteStartPoints", ext: "csv")
        _ = try #require(url, "Missing CoillteStartPoints.csv in ReferenceData")
    }

    @Test("Sport Ireland trailheads CSV is bundled")
    func sportIrelandTrailheadsCSVExists() throws {
        let url = bundledURL("SportIrelandTrailheads", ext: "csv")
        _ = try #require(url, "Missing SportIrelandTrailheads.csv in ReferenceData")
    }

    @Test("Outscape trails GeoJSON is bundled")
    func outscapeTrailsGeoJSONExists() throws {
        let url = bundledURL("OutscapeTrails", ext: "geojson")
        _ = try #require(url, "Missing OutscapeTrails.geojson in ReferenceData")
    }

    @Test("MountainViews CSV has basic integrity")
    func mountainViewsStartPointsCSVIntegrity() throws {
        try assertCSVBasicIntegrity(resourceName: "MountainViewsStartPoints")
    }

    @Test("Coillte CSV has basic integrity")
    func coillteStartPointsCSVIntegrity() throws {
        try assertCSVBasicIntegrity(resourceName: "CoillteStartPoints")
    }

    @Test("Sport Ireland trailheads CSV has basic integrity")
    func sportIrelandTrailheadsCSVIntegrity() throws {
        try assertCSVBasicIntegrity(resourceName: "SportIrelandTrailheads")
    }

    @Test("Outscape trails GeoJSON parses as FeatureCollection")
    func outscapeTrailsGeoJSONIntegrity() throws {
        let url = try #require(bundledURL("OutscapeTrails", ext: "geojson"), "Missing OutscapeTrails.geojson in ReferenceData")
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let type = obj?["type"] as? String
        #expect(type == "FeatureCollection", "GeoJSON 'type' should be 'FeatureCollection'")

        if let features = obj?["features"] as? [Any] {
            #expect(!features.isEmpty, "GeoJSON 'features' should not be empty")
        } else {
            #expect(false, "GeoJSON missing 'features' array")
        }
    }
}
