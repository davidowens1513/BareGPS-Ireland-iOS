import CoreLocation
import Foundation

protocol RegionDefinition {
    var displayName: String { get }
    var hillDatasetResourceName: String { get }
    var startPlaceDatasetResourceName: String { get }
    var topographicStyleResourceName: String { get }
    var externalDataProviderName: String { get }
    var externalDataProviderAssetName: String { get }
    var satelliteStyleName: String { get }
    var standardStyleName: String { get }
    var satelliteStyleFilename: String { get }
    var standardStyleFilename: String { get }
    var defaultMapCenter: CLLocationCoordinate2D { get }
    var defaultMapZoomLevel: Double { get }
    var aboutText: String { get }
    var alwaysVisibleClassificationCodes: Set<String> { get }

    func externalDataProviderURL(forPeakIndex peakIndex: String) -> URL?
    func parseGridReference(_ input: String) -> (gridReference: String, easting: Double, northing: Double)?
    func gridReference(easting: Double, northing: Double) -> String?
    func derivedClassificationMemberships(
        for peaks: [Peak],
        localHundredConfiguration: LocalHundredConfiguration?
    ) -> DerivedClassificationMemberships
    func classificationCodes(for peak: Peak, derivedMemberships: DerivedClassificationMembershipStore) -> [String]
    func displayNameForClassificationCode(_ code: String) -> String?
    func classificationSections(for availableCodes: Set<String>) -> [ClassificationSection]
}

enum ActiveRegion {
    static let current: any RegionDefinition = IrelandRegionDefinition()
}
