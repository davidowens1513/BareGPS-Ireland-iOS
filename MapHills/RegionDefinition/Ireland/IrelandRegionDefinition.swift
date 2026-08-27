import CoreLocation
import Foundation

struct IrelandRegionDefinition: RegionDefinition {
    let displayName = "Ireland"
    let hillDatasetResourceName = "RegionPeakDataset"
    let startPlaceDatasetResourceName = "MountainViewsStartPoints"
    let topographicStyleResourceName = "RegionTopographicStyle"
    let externalDataProviderName = "MountainViews.ie"
    let externalDataProviderAssetName = "RegionDataProvider"
    let satelliteStyleName = "Ireland Satellite"
    let standardStyleName = "Ireland Standard"
    let satelliteStyleFilename = "Region-satellite.json"
    let standardStyleFilename = "Region-standard.json"
    let defaultMapCenter = CLLocationCoordinate2D(latitude: 53.40, longitude: -8.10)
    let defaultMapZoomLevel = 6.8
    let alwaysVisibleClassificationCodes: Set<String> = ["L100"]
    let aboutText = IrelandAboutText.text

    func externalDataProviderURL(forPeakIndex peakIndex: String) -> URL? {
        let trimmedIndex = peakIndex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIndex.isEmpty else { return nil }
        return URL(string: "https://mountainviews.ie/summit/\(trimmedIndex)/")
    }
}
