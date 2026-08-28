enum MapBaseLayer: String {
    case topographic
    case openOnzyMap
    case standard
    case satellite

    var displayName: String {
        switch self {
        case .topographic:
            return "OpenTopo"
        case .openOnzyMap:
            return "OpenOnzyMap"
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
        case .openOnzyMap:
            return "Map data: © OpenStreetMap contributors, SRTM | OpenOnzyMap offline bundle"
        case .standard:
            return "© OpenStreetMap contributors"
        case .satellite:
            return "Sources: Esri, Maxar, Earthstar Geographics, USDA, USGS"
        }
    }
}
