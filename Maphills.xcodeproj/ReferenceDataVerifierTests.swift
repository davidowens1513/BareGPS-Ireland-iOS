import Foundation
import Testing

@Suite("Reference Data Verifier")
struct ReferenceDataVerifierTests {

    private func bundledURL(_ name: String, ext: String) -> URL? {
        let bundles = [Bundle.main] + Bundle.allBundles
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
}
