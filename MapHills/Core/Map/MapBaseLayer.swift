enum MapBaseLayer: String {
    case topographic
    case standard
    case satellite

    var attributionText: String {
        switch self {
        case .topographic:
            return "Map data: © OpenStreetMap contributors, SRTM | Map style: © OpenTopoMap (CC-BY-SA)"
        case .standard:
            return "© OpenStreetMap contributors"
        case .satellite:
            return "Sources: Esri, Maxar, Earthstar Geographics, USDA, USGS"
        }
    }
}
