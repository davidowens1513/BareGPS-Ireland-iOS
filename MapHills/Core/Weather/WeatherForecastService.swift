import Foundation
import CoreLocation

struct WeatherForecast {
    struct CurrentSummary {
        let symbolName: String
        let conditionDescription: String
        let temperature: Measurement<UnitTemperature>
        let windSpeed: Measurement<UnitSpeed>
        let windGust: Measurement<UnitSpeed>?
        let windDirectionDegrees: Double
        let windDirectionAbbreviation: String
        let humidityFraction: Double?
        let fogFraction: Double?
        let lowCloudFraction: Double?
        let mediumCloudFraction: Double?
        let highCloudFraction: Double?
        let uvIndexClearSky: Double?
        let pressure: Measurement<UnitPressure>?
        let precipitationNextHour: Measurement<UnitLength>?
        let precipitationProbabilityFraction: Double?
    }

    struct IntervalSummary {
        let date: Date
        let periodHours: Int
        let symbolName: String
        let conditionDescription: String
        let temperature: Measurement<UnitTemperature>
        let windSpeed: Measurement<UnitSpeed>
        let windGust: Measurement<UnitSpeed>?
        let windDirectionDegrees: Double
        let windDirectionAbbreviation: String
        let fogFraction: Double?
        let lowCloudFraction: Double?
        let mediumCloudFraction: Double?
        let highCloudFraction: Double?
        let uvIndexClearSky: Double?
        let pressure: Measurement<UnitPressure>?
        let precipitationNextHour: Measurement<UnitLength>?
        let precipitationProbabilityFraction: Double?
    }

    let coordinate: CLLocationCoordinate2D
    let requestedAt: Date
    let current: CurrentSummary
    let intervals: [IntervalSummary]
    let attributionText: String
    let attributionURL: URL?
}

enum WeatherForecastServiceError: LocalizedError {
    case invalidResponse
    case missingForecastData
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The weather service returned an unexpected response."
        case .missingForecastData:
            return "The weather service did not provide enough forecast data for this map location."
        case .invalidPayload:
            return "The weather service returned data in an unsupported format."
        }
    }
}

final class WeatherForecastService {
    private let session: URLSession
    private let nowProvider: () -> Date

    init(
        session: URLSession = .shared,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.nowProvider = nowProvider
    }

    func forecast(for coordinate: CLLocationCoordinate2D) async throws -> WeatherForecast {
        let request = try makeRequest(for: coordinate)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherForecastServiceError.invalidResponse
        }

        let payload = try MetEireannForecastParser.parse(data: data)
        let instantEntries = payload.instantEntries.sorted { $0.time < $1.time }
        guard let currentEntry = instantEntries.first(where: { $0.time >= nowProvider() }) ?? instantEntries.first else {
            throw WeatherForecastServiceError.missingForecastData
        }

        let currentPeriod = payload.periodEntry(endingAt: currentEntry.time)

        let current = WeatherForecast.CurrentSummary(
            symbolName: Self.sfSymbolName(for: currentPeriod?.symbolID),
            conditionDescription: Self.conditionDescription(for: currentPeriod?.symbolID),
            temperature: Measurement(value: currentEntry.temperatureCelsius, unit: .celsius),
            windSpeed: Measurement(value: currentEntry.windSpeedMetersPerSecond, unit: .metersPerSecond),
            windGust: currentEntry.windGustMetersPerSecond.map { Measurement(value: $0, unit: .metersPerSecond) },
            windDirectionDegrees: currentEntry.windDirectionDegrees,
            windDirectionAbbreviation: currentEntry.windDirectionName ?? Self.compassDirection(for: currentEntry.windDirectionDegrees),
            humidityFraction: currentEntry.humidityPercent.map { $0 / 100.0 },
            fogFraction: nil,
            lowCloudFraction: currentEntry.lowCloudPercent.map { $0 / 100.0 },
            mediumCloudFraction: currentEntry.mediumCloudPercent.map { $0 / 100.0 },
            highCloudFraction: currentEntry.highCloudPercent.map { $0 / 100.0 },
            uvIndexClearSky: nil,
            pressure: currentEntry.pressureHectopascals.map { Measurement(value: $0, unit: .hectopascals) },
            precipitationNextHour: currentPeriod?.precipitationMillimeters.map { Measurement(value: $0, unit: .millimeters) },
            precipitationProbabilityFraction: currentPeriod?.precipitationProbabilityPercent.map { $0 / 100.0 }
        )

        let intervals = try mixedIntervals(from: payload, startDate: currentEntry.time)

        return WeatherForecast(
            coordinate: coordinate,
            requestedAt: payload.createdAt,
            current: current,
            intervals: intervals,
            attributionText: "Data from Met Éireann.",
            attributionURL: URL(string: "https://www.met.ie/about-us/specialised-services/open-data")
        )
    }

    private func makeRequest(for coordinate: CLLocationCoordinate2D) throws -> URLRequest {
        var components = URLComponents(string: "http://openaccess.pf.api.met.ie/metno-wdb2ts/locationforecast")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", coordinate.latitude)),
            URLQueryItem(name: "long", value: String(format: "%.6f", coordinate.longitude))
        ]

        guard let url = components?.url else {
            throw WeatherForecastServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("application/xml,text/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        return request
    }

    private func mixedIntervals(
        from payload: MetEireannForecastPayload,
        startDate: Date
    ) throws -> [WeatherForecast.IntervalSummary] {
        var intervals: [WeatherForecast.IntervalSummary] = []
        let instantEntries = payload.instantEntries.sorted { $0.time < $1.time }

        let hourlyEndDate = startDate.addingTimeInterval(12 * 3600)
        let mixedEndDate = startDate.addingTimeInterval(24 * 3600)
        var currentTarget = startDate.addingTimeInterval(3600)

        while currentTarget <= hourlyEndDate {
            guard let matchedEntry = instantEntries.first(where: { abs($0.time.timeIntervalSince(currentTarget)) < 1800 }) else {
                currentTarget = currentTarget.addingTimeInterval(3600)
                continue
            }

            guard let periodEntry = payload.periodEntry(endingAt: matchedEntry.time) else {
                currentTarget = currentTarget.addingTimeInterval(3600)
                continue
            }

            intervals.append(makeIntervalSummary(instantEntry: matchedEntry, periodEntry: periodEntry))
            currentTarget = currentTarget.addingTimeInterval(3600)
        }

        currentTarget = hourlyEndDate.addingTimeInterval(3 * 3600)

        while currentTarget <= mixedEndDate {
            guard let matchedEntry = instantEntries.first(where: { abs($0.time.timeIntervalSince(currentTarget)) < 1800 }) else {
                currentTarget = currentTarget.addingTimeInterval(3 * 3600)
                continue
            }

            guard let periodEntry = payload.periodEntry(endingAt: matchedEntry.time) else {
                currentTarget = currentTarget.addingTimeInterval(3 * 3600)
                continue
            }

            intervals.append(makeIntervalSummary(instantEntry: matchedEntry, periodEntry: periodEntry))
            currentTarget = currentTarget.addingTimeInterval(3 * 3600)
        }

        guard !intervals.isEmpty else {
            throw WeatherForecastServiceError.missingForecastData
        }
        return intervals
    }

    private func makeIntervalSummary(
        instantEntry: MetEireannForecastPayload.InstantEntry,
        periodEntry: MetEireannForecastPayload.PeriodEntry
    ) -> WeatherForecast.IntervalSummary {
        let periodHours = max(1, Int(round(periodEntry.end.timeIntervalSince(periodEntry.start) / 3600)))
        return WeatherForecast.IntervalSummary(
            date: instantEntry.time,
            periodHours: periodHours,
            symbolName: Self.sfSymbolName(for: periodEntry.symbolID),
            conditionDescription: Self.conditionDescription(for: periodEntry.symbolID),
            temperature: Measurement(value: instantEntry.temperatureCelsius, unit: .celsius),
            windSpeed: Measurement(value: instantEntry.windSpeedMetersPerSecond, unit: .metersPerSecond),
            windGust: instantEntry.windGustMetersPerSecond.map { Measurement(value: $0, unit: .metersPerSecond) },
            windDirectionDegrees: instantEntry.windDirectionDegrees,
            windDirectionAbbreviation: instantEntry.windDirectionName ?? Self.compassDirection(for: instantEntry.windDirectionDegrees),
            fogFraction: nil,
            lowCloudFraction: instantEntry.lowCloudPercent.map { $0 / 100.0 },
            mediumCloudFraction: instantEntry.mediumCloudPercent.map { $0 / 100.0 },
            highCloudFraction: instantEntry.highCloudPercent.map { $0 / 100.0 },
            uvIndexClearSky: nil,
            pressure: instantEntry.pressureHectopascals.map { Measurement(value: $0, unit: .hectopascals) },
            precipitationNextHour: periodEntry.precipitationMillimeters.map { Measurement(value: $0, unit: .millimeters) },
            precipitationProbabilityFraction: periodEntry.precipitationProbabilityPercent.map { $0 / 100.0 }
        )
    }

    private var userAgent: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ios-app"
        return "\(AppBranding.fileSafeName)/1.0 \(AppBranding.supportContactEmail) (\(bundleIdentifier))"
    }

    private static func conditionDescription(for symbolID: String?) -> String {
        guard let symbolID, !symbolID.isEmpty else { return "Forecast" }
        let normalized = symbolID
            .replacingOccurrences(of: "Dark_", with: "")
            .replacingOccurrences(of: "_", with: " ")

        let splitWords = normalized.unicodeScalars.reduce(into: "") { partialResult, scalar in
            if !partialResult.isEmpty, CharacterSet.uppercaseLetters.contains(scalar), partialResult.last?.isLetter == true {
                partialResult.append(" ")
            }
            partialResult.append(String(scalar))
        }

        return splitWords
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func sfSymbolName(for symbolID: String?) -> String {
        guard let symbolID, !symbolID.isEmpty else { return "cloud" }
        let normalized = symbolID.lowercased()
        if normalized.contains("fog") { return "cloud.fog.fill" }
        if normalized.contains("thunder") {
            if normalized.contains("snow") { return "cloud.snow.fill" }
            if normalized.contains("sleet") { return "cloud.sleet.fill" }
            return "cloud.bolt.rain.fill"
        }
        if normalized.contains("snow") { return "cloud.snow.fill" }
        if normalized.contains("sleet") { return "cloud.sleet.fill" }
        if normalized.contains("drizzle") { return "cloud.drizzle.fill" }
        if normalized.contains("rain") {
            return normalized.contains("sun") ? "cloud.sun.rain.fill" : "cloud.rain.fill"
        }
        if normalized.contains("sun") || normalized.contains("partlycloud") || normalized.contains("lightcloud") {
            return "cloud.sun.fill"
        }
        if normalized.contains("clear") || normalized.contains("fair") {
            return "sun.max.fill"
        }
        if normalized.contains("cloud") {
            return "cloud.fill"
        }
        return "cloud"
    }

    private static func compassDirection(for degrees: Double) -> String {
        let directions = [
            "N", "NNE", "NE", "ENE",
            "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW",
            "W", "WNW", "NW", "NNW"
        ]
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 11.25) / 22.5) % directions.count
        return directions[index]
    }
}

private struct MetEireannForecastPayload {
    struct InstantEntry {
        let time: Date
        let temperatureCelsius: Double
        let windDirectionDegrees: Double
        let windDirectionName: String?
        let windSpeedMetersPerSecond: Double
        let windGustMetersPerSecond: Double?
        let humidityPercent: Double?
        let pressureHectopascals: Double?
        let lowCloudPercent: Double?
        let mediumCloudPercent: Double?
        let highCloudPercent: Double?
    }

    struct PeriodEntry {
        let start: Date
        let end: Date
        let precipitationMillimeters: Double?
        let precipitationProbabilityPercent: Double?
        let symbolID: String?
        let symbolNumber: Int?
    }

    let createdAt: Date
    let instantEntries: [InstantEntry]
    let periodEntries: [PeriodEntry]

    func periodEntry(endingAt date: Date) -> PeriodEntry? {
        periodEntries.first(where: { abs($0.end.timeIntervalSince(date)) < 60 })
    }
}

private enum MetEireannForecastParser {
    static func parse(data: Data) throws -> MetEireannForecastPayload {
        let parserDelegate = MetEireannXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw parser.parserError ?? WeatherForecastServiceError.invalidPayload
        }
        return try parserDelegate.payload()
    }
}

private final class MetEireannXMLParserDelegate: NSObject, XMLParserDelegate {
    private let dateFormatter = ISO8601DateFormatter()
    private var createdAt: Date?
    private var instantEntries: [MetEireannForecastPayload.InstantEntry] = []
    private var periodEntries: [MetEireannForecastPayload.PeriodEntry] = []

    private var currentTimeFrom: Date?
    private var currentTimeTo: Date?
    private var currentInstant = MutableInstantEntry()
    private var currentPeriod = MutablePeriodEntry()

    override init() {
        super.init()
        dateFormatter.formatOptions = [.withInternetDateTime]
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        switch elementName {
        case "weatherdata":
            if let createdString = attributeDict["created"] {
                createdAt = dateFormatter.date(from: createdString)
            }
        case "time":
            currentTimeFrom = attributeDict["from"].flatMap(dateFormatter.date(from:))
            currentTimeTo = attributeDict["to"].flatMap(dateFormatter.date(from:))
            currentInstant = MutableInstantEntry()
            currentPeriod = MutablePeriodEntry()
        case "temperature":
            currentInstant.temperatureCelsius = attributeDict["value"].flatMap(Double.init)
        case "windDirection":
            currentInstant.windDirectionDegrees = attributeDict["deg"].flatMap(Double.init)
            currentInstant.windDirectionName = attributeDict["name"]
        case "windSpeed":
            currentInstant.windSpeedMetersPerSecond = attributeDict["mps"].flatMap(Double.init)
        case "windGust":
            currentInstant.windGustMetersPerSecond = attributeDict["mps"].flatMap(Double.init)
        case "humidity":
            currentInstant.humidityPercent = attributeDict["value"].flatMap(Double.init)
        case "pressure":
            currentInstant.pressureHectopascals = attributeDict["value"].flatMap(Double.init)
        case "lowClouds":
            currentInstant.lowCloudPercent = attributeDict["percent"].flatMap(Double.init)
        case "mediumClouds":
            currentInstant.mediumCloudPercent = attributeDict["percent"].flatMap(Double.init)
        case "highClouds":
            currentInstant.highCloudPercent = attributeDict["percent"].flatMap(Double.init)
        case "precipitation":
            currentPeriod.precipitationMillimeters = attributeDict["value"].flatMap(Double.init)
            currentPeriod.precipitationProbabilityPercent = attributeDict["probability"].flatMap(Double.init)
        case "symbol":
            currentPeriod.symbolID = attributeDict["id"]
            currentPeriod.symbolNumber = attributeDict["number"].flatMap(Int.init)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "time" else { return }
        guard let from = currentTimeFrom, let to = currentTimeTo else { return }

        if from == to,
           let temperature = currentInstant.temperatureCelsius,
           let windDirectionDegrees = currentInstant.windDirectionDegrees,
           let windSpeed = currentInstant.windSpeedMetersPerSecond {
            instantEntries.append(
                MetEireannForecastPayload.InstantEntry(
                    time: to,
                    temperatureCelsius: temperature,
                    windDirectionDegrees: windDirectionDegrees,
                    windDirectionName: currentInstant.windDirectionName,
                    windSpeedMetersPerSecond: windSpeed,
                    windGustMetersPerSecond: currentInstant.windGustMetersPerSecond,
                    humidityPercent: currentInstant.humidityPercent,
                    pressureHectopascals: currentInstant.pressureHectopascals,
                    lowCloudPercent: currentInstant.lowCloudPercent,
                    mediumCloudPercent: currentInstant.mediumCloudPercent,
                    highCloudPercent: currentInstant.highCloudPercent
                )
            )
        } else if from < to {
            periodEntries.append(
                MetEireannForecastPayload.PeriodEntry(
                    start: from,
                    end: to,
                    precipitationMillimeters: currentPeriod.precipitationMillimeters,
                    precipitationProbabilityPercent: currentPeriod.precipitationProbabilityPercent,
                    symbolID: currentPeriod.symbolID,
                    symbolNumber: currentPeriod.symbolNumber
                )
            )
        }
    }

    func payload() throws -> MetEireannForecastPayload {
        guard let createdAt else {
            throw WeatherForecastServiceError.invalidPayload
        }
        return MetEireannForecastPayload(
            createdAt: createdAt,
            instantEntries: instantEntries,
            periodEntries: periodEntries
        )
    }

    private struct MutableInstantEntry {
        var temperatureCelsius: Double?
        var windDirectionDegrees: Double?
        var windDirectionName: String?
        var windSpeedMetersPerSecond: Double?
        var windGustMetersPerSecond: Double?
        var humidityPercent: Double?
        var pressureHectopascals: Double?
        var lowCloudPercent: Double?
        var mediumCloudPercent: Double?
        var highCloudPercent: Double?
    }

    private struct MutablePeriodEntry {
        var precipitationMillimeters: Double?
        var precipitationProbabilityPercent: Double?
        var symbolID: String?
        var symbolNumber: Int?
    }
}
