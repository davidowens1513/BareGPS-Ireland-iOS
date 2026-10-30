import Foundation

enum MapBaseLayer: String {
    case topographic
    case openBareMap
    case standard
    case satellite

    var displayName: String {
        switch self {
        case .topographic:
            return "OpenTopo"
        case .openBareMap:
            return "OpenBareMap"
        case .standard:
            return "OpenStreetMap"
        case .satellite:
            return "Satellite"
        }
    }

    var attributionText: String {
        switch self {
        case .topographic:
            return "Map data: © OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)"
        case .openBareMap:
            return "© OpenStreetMap contributors (ODbL) | Terrain: Mapzen, Copernicus EU-DEM, USGS, NOAA, Environment Agency | Full credits: About"
        case .standard:
            return "© OpenStreetMap contributors"
        case .satellite:
            return "Sources: Esri, Maxar, Earthstar Geographics, USDA, USGS"
        }
    }

    var supportsOfflineCaching: Bool {
        switch self {
        case .topographic, .satellite:
            return true
        case .openBareMap, .standard:
            return false
        }
    }

    func styleURL(
        topographicStyleURL: URL?,
        openBareMapStyleURL: URL?,
        standardStyleURL: URL?,
        satelliteStyleURL: URL?
    ) -> URL? {
        switch self {
        case .topographic:
            return topographicStyleURL
        case .openBareMap:
            return openBareMapStyleURL ?? topographicStyleURL
        case .standard:
            return standardStyleURL
        case .satellite:
            return satelliteStyleURL
        }
    }
}

enum OpenBareMapDetail: String, CaseIterable {
    case hillshade
    case landCover
    case boundaries
    case minorRoads
    case roadNames
    case railwaysAndStations
    case ferryRoutes
    case cyclingRoutes
    case hikingRoutes
    case islandNames
    case waterFeatureNames

    static let defaultVisibleDetails: Set<OpenBareMapDetail> = [
        .hillshade,
        .landCover,
        .boundaries,
        .minorRoads,
        .railwaysAndStations,
        .hikingRoutes
    ]

    var title: String {
        switch self {
        case .hillshade: return "Hillshade"
        case .landCover: return "Land Cover"
        case .boundaries: return "Boundaries"
        case .minorRoads: return "Minor Roads"
        case .roadNames: return "Road Names"
        case .railwaysAndStations: return "Railways and Stations"
        case .ferryRoutes: return "Ferry Routes"
        case .cyclingRoutes: return "Cycling Routes"
        case .hikingRoutes: return "Hiking Routes"
        case .islandNames: return "Island Names"
        case .waterFeatureNames: return "Water-Feature Names"
        }
    }

    var layerIdentifiers: [String] {
        switch self {
        case .hillshade:
            return ["terrain-hillshade"]
        case .landCover:
            return [
                "landcover",
                "bog-texture",
                "bare-rock",
                "scree-and-shingle",
                "bare-rock-stipple",
                "scree-stipple"
            ]
        case .boundaries:
            return ["administrative-boundaries", "county-boundaries", "local-boundaries"]
        case .minorRoads:
            return ["roads-casing-minor", "roads-minor"]
        case .roadNames:
            return ["road-labels"]
        case .railwaysAndStations:
            return ["railways", "station-labels"]
        case .ferryRoutes:
            return ["ferry-routes"]
        case .cyclingRoutes:
            return ["cycling-routes"]
        case .hikingRoutes:
            return ["hiking-routes"]
        case .islandNames:
            return ["island-labels"]
        case .waterFeatureNames:
            return ["water-labels"]
        }
    }

    var layerIdentifierPrefixes: [String] {
        switch self {
        case .minorRoads:
            return ["roads-casing-minor", "roads-minor"]
        case .railwaysAndStations:
            return ["railways"]
        default:
            return []
        }
    }
}
