import Foundation

struct InitialMapData {
    let peaks: [Peak]
    let startPlaces: [StartPlace]
    let irelandPlacenames: [IrelandPlacename]
    let coillteTrailSummaries: [CoillteTrailSummary]
    let sportIrelandTrailSummariesByTrailID: [String: SportIrelandTrailSummary]
    let outscapeTrailSummariesByTrailID: [String: OutscapeTrailSummary]
    let sportIrelandTrailIDByStartPlaceID: [String: String]
}

struct InitialMapDataLoader {
    let regionDefinition: any RegionDefinition

    func load() -> InitialMapData {
        InitialMapData(
            peaks: MapDataLoader.loadPeaksFromJSON(resourceName: regionDefinition.hillDatasetResourceName),
            startPlaces: [
                MapDataLoader.loadStartPlacesFromJSON(resourceName: regionDefinition.startPlaceDatasetResourceName),
                MapDataLoader.loadStartPlacesFromJSON(resourceName: "SportIrelandStartPoints"),
                MapDataLoader.loadStartPlacesFromJSON(resourceName: "CoillteStartPoints"),
                MapDataLoader.loadOutscapeDerivedTrailStartPlaces()
            ].flatMap { $0 },
            irelandPlacenames: MapDataLoader.loadIrelandPlacenames(),
            coillteTrailSummaries: MapDataLoader.loadCoillteTrailSummaries(),
            sportIrelandTrailSummariesByTrailID: MapDataLoader.loadSportIrelandTrailSummariesByTrailID(),
            outscapeTrailSummariesByTrailID: MapDataLoader.loadOutscapeTrailSummariesByTrailID(),
            sportIrelandTrailIDByStartPlaceID: MapDataLoader.loadSportIrelandTrailIDByStartPlaceID()
        )
    }
}
