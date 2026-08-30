import UIKit
import CoreLocation

final class WeatherOverlayViewController: UIViewController {
    private let coordinate: CLLocationCoordinate2D
    private let locationTitle: String
    private let displayUnitSystem: DisplayUnitSystem
    private let forecastProvider: @Sendable (CLLocationCoordinate2D) async throws -> WeatherForecast

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let contentStack = UIStackView()
    private let bodyStack = UIStackView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let gridScrollView = UIScrollView()
    private let closeButton = UIButton(type: .system)
    private var loadTask: Task<Void, Never>?

    init(
        coordinate: CLLocationCoordinate2D,
        locationTitle: String,
        displayUnitSystem: DisplayUnitSystem,
        forecastProvider: @escaping @Sendable (CLLocationCoordinate2D) async throws -> WeatherForecast
    ) {
        self.coordinate = coordinate
        self.locationTitle = locationTitle
        self.displayUnitSystem = displayUnitSystem
        self.forecastProvider = forecastProvider
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(OverlayChromeStyle.dimmingAlpha)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissOverlay)))
        view.addSubview(dimmingView)

        configureOverlayCardChrome(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = makeOverlayTitleLabel("Weather")
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Vicinity of \(locationTitle)"
        subtitleLabel.font = OverlayChromeStyle.bodyFont
        subtitleLabel.textColor = .label
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = OverlayChromeStyle.supportingFont
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = "Loading forecast…"

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        bodyStack.axis = .vertical
        bodyStack.spacing = 14
        bodyStack.translatesAutoresizingMaskIntoConstraints = false

        gridScrollView.translatesAutoresizingMaskIntoConstraints = false
        gridScrollView.showsHorizontalScrollIndicator = true
        gridScrollView.alwaysBounceHorizontal = true

        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(titleRow)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(activityIndicator)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(bodyStack)
        contentStack.addArrangedSubview(closeButton)
        contentStack.setCustomSpacing(2, after: titleRow)
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            cardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: -4)
        ])

        loadForecast()
    }

    @objc private func dismissOverlay() {
        loadTask?.cancel()
        dismiss(animated: true)
    }

    private func loadForecast() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let forecast = try await forecastProvider(coordinate)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.render(forecast: forecast)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.renderError(error)
                }
            }
        }
    }

    private func render(forecast: WeatherForecast) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.isHidden = true

        bodyStack.arrangedSubviews.forEach { subview in
            bodyStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        bodyStack.addArrangedSubview(makeCurrentConditionsCard(forecast.current, requestedAt: forecast.requestedAt))
        bodyStack.addArrangedSubview(makeSectionTitle("Next 24 Hours"))
        bodyStack.addArrangedSubview(makeForecastGrid(for: forecast.intervals))
        bodyStack.addArrangedSubview(makeAttributionView(text: forecast.attributionText, url: forecast.attributionURL))
    }

    private func renderError(_ error: Error) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.isHidden = false
        statusLabel.text = failureMessage(for: error)
    }

    private func makeCurrentConditionsCard(_ current: WeatherForecast.CurrentSummary, requestedAt: Date) -> UIView {
        let container = makeCardContainer()

        let symbolView = UIImageView(image: UIImage(systemName: current.symbolName))
        symbolView.tintColor = .systemBlue
        symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        symbolView.setContentHuggingPriority(.required, for: .horizontal)

        let temperatureLabel = UILabel()
        temperatureLabel.font = .systemFont(ofSize: 28, weight: .bold)
        temperatureLabel.textColor = .label
        temperatureLabel.text = formattedTemperature(current.temperature)

        let conditionLabel = UILabel()
        conditionLabel.font = .systemFont(ofSize: 15, weight: .heavy)
        conditionLabel.textColor = .label
        conditionLabel.text = current.conditionDescription

        let detailLabel = UILabel()
        detailLabel.font = OverlayChromeStyle.bodyFont
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        let detailText = NSMutableAttributedString(
            string: "Wind \(numericWindKnots(current.windSpeed)) kts \(formattedWindDirection(degrees: current.windDirectionDegrees, abbreviation: current.windDirectionAbbreviation))",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .heavy),
                .foregroundColor: UIColor.label
            ]
        )
        detailLabel.attributedText = detailText

        let textStack = UIStackView(arrangedSubviews: [temperatureLabel, conditionLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [symbolView, textStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])
        return container
    }

    private func makeForecastGrid(for intervals: [WeatherForecast.IntervalSummary]) -> UIView {
        let container = makeCardContainer()
        let leftColumnWidth: CGFloat = 58
        let dataColumnWidth: CGFloat = 50
        let columnSpacing: CGFloat = 8
        let rowSpacing: CGFloat = 3
        let sectionGap: CGFloat = 10
        let headerHeight: CGFloat = 56
        let rowHeight: CGFloat = 20

        let temperatureRowTitle = switch displayUnitSystem {
        case .metric:
            "Temp (C)"
        case .imperial:
            "Temp (F)"
        }
        let rowDefinitions: [(title: String, provider: (WeatherForecast.IntervalSummary) -> UIView)] = [
            ("Symbol", { [self] interval in
                gridSymbolView(interval.symbolName)
            }),
            ("Rain (mm)", { [self] interval in
                gridValueLabel(numericRain(interval.precipitationNextHour))
            }),
            ("Rain %", { [self] interval in
                gridValueLabel(
                    interval.precipitationProbabilityFraction.map(formattedHumidity) ?? "—",
                    isUnavailable: interval.precipitationProbabilityFraction == nil
                )
            }),
            (temperatureRowTitle, { [self] interval in
                gridValueLabel(numericTemperature(interval.temperature))
            }),
            ("Pressure", { [self] interval in
                gridValueLabel(
                    interval.pressure.map(numericPressure) ?? "—",
                    isUnavailable: interval.pressure == nil
                )
            }),
            ("Wind (kts)", { [self] interval in
                gridValueLabel(numericWindKnots(interval.windSpeed))
            }),
            ("Gust (kts)", { [self] interval in
                gridValueLabel(numericWindKnots(interval.windGust), isUnavailable: interval.windGust == nil)
            }),
            ("Wind Dir", { interval in
                self.gridValueLabel(
                    self.formattedWindDirection(
                        degrees: interval.windDirectionDegrees,
                        abbreviation: interval.windDirectionAbbreviation
                    )
                )
            }),
            ("Low cld %", { [self] interval in
                gridValueLabel(
                    interval.lowCloudFraction.map(formattedHumidity) ?? "—",
                    isUnavailable: interval.lowCloudFraction == nil
                )
            }),
            ("Mid cld %", { [self] interval in
                gridValueLabel(
                    interval.mediumCloudFraction.map(formattedHumidity) ?? "—",
                    isUnavailable: interval.mediumCloudFraction == nil
                )
            }),
            ("High cld %", { [self] interval in
                gridValueLabel(
                    interval.highCloudFraction.map(formattedHumidity) ?? "—",
                    isUnavailable: interval.highCloudFraction == nil
                )
            })
        ]
        let rowTitles = rowDefinitions.map(\.title)
        let sectionBreakAfterRows: Set<Int> = [0, 4, 7]
        let totalSectionGapHeight = sectionGap * CGFloat(sectionBreakAfterRows.count)
        let gridBodyHeight = headerHeight
            + rowSpacing
            + (rowHeight * CGFloat(rowTitles.count))
            + (rowSpacing * CGFloat(max(0, rowTitles.count - 1)))
            + totalSectionGapHeight

        let labelColumn = UIView()
        labelColumn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelColumn)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        gridScrollView.subviews.forEach { $0.removeFromSuperview() }
        gridScrollView.addSubview(contentView)
        container.addSubview(gridScrollView)

        NSLayoutConstraint.activate([
            labelColumn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            labelColumn.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            labelColumn.widthAnchor.constraint(equalToConstant: leftColumnWidth),
            labelColumn.heightAnchor.constraint(equalToConstant: gridBodyHeight),

            gridScrollView.leadingAnchor.constraint(equalTo: labelColumn.trailingAnchor, constant: columnSpacing),
            gridScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            gridScrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            gridScrollView.heightAnchor.constraint(equalTo: labelColumn.heightAnchor),
            gridScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            contentView.leadingAnchor.constraint(equalTo: gridScrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: gridScrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: gridScrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: gridScrollView.contentLayoutGuide.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: gridScrollView.frameLayoutGuide.heightAnchor),
            contentView.widthAnchor.constraint(equalToConstant: (dataColumnWidth * CGFloat(intervals.count)) + (columnSpacing * CGFloat(max(0, intervals.count - 1))))
        ])

        func rowTop(for rowIndex: Int) -> CGFloat {
            var top = headerHeight + rowSpacing
            if rowIndex == 0 {
                return top
            }
            for previousIndex in 0..<rowIndex {
                top += rowHeight
                if previousIndex < rowIndex - 1 {
                    top += rowSpacing
                }
                if sectionBreakAfterRows.contains(previousIndex) {
                    top += sectionGap
                }
            }
            return top
        }

        let leftHeader = leftGridHeaderView("Hour")
        leftHeader.translatesAutoresizingMaskIntoConstraints = false
        labelColumn.addSubview(leftHeader)
        NSLayoutConstraint.activate([
            leftHeader.leadingAnchor.constraint(equalTo: labelColumn.leadingAnchor),
            leftHeader.trailingAnchor.constraint(equalTo: labelColumn.trailingAnchor),
            leftHeader.topAnchor.constraint(equalTo: labelColumn.topAnchor),
            leftHeader.heightAnchor.constraint(equalToConstant: headerHeight)
        ])

        for (rowIndex, title) in rowTitles.enumerated() {
            let rowView = gridRowTitleLabel(title)
            rowView.translatesAutoresizingMaskIntoConstraints = false
            labelColumn.addSubview(rowView)
            let top = rowTop(for: rowIndex)
            NSLayoutConstraint.activate([
                rowView.leadingAnchor.constraint(equalTo: labelColumn.leadingAnchor),
                rowView.trailingAnchor.constraint(equalTo: labelColumn.trailingAnchor),
                rowView.topAnchor.constraint(equalTo: labelColumn.topAnchor, constant: top),
                rowView.heightAnchor.constraint(equalToConstant: rowHeight)
            ])
        }

        for (columnIndex, interval) in intervals.enumerated() {
            let columnView = UIView()
            columnView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(columnView)

            let leading = CGFloat(columnIndex) * (dataColumnWidth + columnSpacing)
            NSLayoutConstraint.activate([
                columnView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: leading),
                columnView.topAnchor.constraint(equalTo: contentView.topAnchor),
                columnView.widthAnchor.constraint(equalToConstant: dataColumnWidth),
                columnView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            let previousDate = columnIndex > 0 ? intervals[columnIndex - 1].date : nil
            let headerView = intervalHeaderView(for: interval, previousDate: previousDate)
            headerView.translatesAutoresizingMaskIntoConstraints = false
            columnView.addSubview(headerView)
            NSLayoutConstraint.activate([
                headerView.leadingAnchor.constraint(equalTo: columnView.leadingAnchor),
                headerView.trailingAnchor.constraint(equalTo: columnView.trailingAnchor),
                headerView.topAnchor.constraint(equalTo: columnView.topAnchor),
                headerView.heightAnchor.constraint(equalToConstant: headerHeight)
            ])

            for (rowIndex, rowDefinition) in rowDefinitions.enumerated() {
                let rowView = rowDefinition.provider(interval)
                rowView.translatesAutoresizingMaskIntoConstraints = false
                columnView.addSubview(rowView)
                let top = rowTop(for: rowIndex)
                NSLayoutConstraint.activate([
                    rowView.leadingAnchor.constraint(equalTo: columnView.leadingAnchor),
                    rowView.trailingAnchor.constraint(equalTo: columnView.trailingAnchor),
                    rowView.topAnchor.constraint(equalTo: columnView.topAnchor, constant: top),
                    rowView.heightAnchor.constraint(equalToConstant: rowHeight)
                ])
            }
        }

        return container
    }

    private func makeAttributionView(text: String, url: URL?) -> UIView {
        let container = makeCardContainer()

        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.text = text

        let row = UIStackView(arrangedSubviews: [label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        if let url {
            let linkButton = UIButton(type: .system)
            linkButton.configuration = .plain()
            linkButton.configuration?.title = "License"
            linkButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            linkButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
            linkButton.contentHorizontalAlignment = .leading
            linkButton.setContentHuggingPriority(.required, for: .horizontal)
            linkButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            linkButton.addAction(UIAction { _ in
                UIApplication.shared.open(url)
            }, for: .touchUpInside)
            row.addArrangedSubview(linkButton)
        }

        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        return container
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.text = text
        return label
    }

    private func gridHeaderLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 3
        label.contentMode = .top
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.text = text
        label.backgroundColor = UIColor.systemGray6
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return label
    }

    private func leftGridHeaderView(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 8
        container.clipsToBounds = true

        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.heightAnchor.constraint(equalToConstant: 26)
        ])

        container.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return container
    }

    private func intervalHeaderView(for interval: WeatherForecast.IntervalSummary, previousDate: Date?) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 8
        container.clipsToBounds = true

        let timeLabel = UILabel()
        timeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        timeLabel.textColor = .label
        timeLabel.textAlignment = .center
        timeLabel.numberOfLines = 2
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.8
        timeLabel.text = intervalTimeText(for: interval)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timeLabel)

        let shouldShowDate: Bool
        if let previousDate {
            shouldShowDate = !Calendar.current.isDate(interval.date, inSameDayAs: previousDate)
        } else {
            shouldShowDate = true
        }

        if shouldShowDate {
            let dateLabel = UILabel()
            dateLabel.font = .systemFont(ofSize: 11, weight: .bold)
            dateLabel.textColor = .label
            dateLabel.textAlignment = .center
            dateLabel.adjustsFontSizeToFitWidth = true
            dateLabel.minimumScaleFactor = 0.8
            dateLabel.text = dayHeaderFormatter.string(from: interval.date)
            dateLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(dateLabel)

            NSLayoutConstraint.activate([
                dateLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                dateLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                dateLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 5),

                timeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                timeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3),
                timeLabel.heightAnchor.constraint(equalToConstant: 28)
            ])
        } else {
            NSLayoutConstraint.activate([
                timeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                timeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
                timeLabel.heightAnchor.constraint(equalToConstant: 26)
            ])
        }

        container.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return container
    }

    private func gridRowTitleLabel(_ text: String) -> UIView {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 26).isActive = true
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func gridValueLabel(_ text: String, isUnavailable: Bool = false) -> UILabel {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = isUnavailable ? .tertiaryLabel : .label
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.text = text
        label.backgroundColor = isUnavailable
            ? UIColor.systemGray6.withAlphaComponent(0.55)
            : UIColor.systemBackground.withAlphaComponent(0.7)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return label
    }

    private func gridSymbolView(_ symbolName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        container.layer.cornerRadius = 8
        container.clipsToBounds = true
        container.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let imageView = UIImageView(image: UIImage(systemName: symbolName))
        imageView.tintColor = .systemTeal
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 20),
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 20)
        ])

        return container
    }

    private func makeCardContainer() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 12
        return container
    }

    private func formattedTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        switch displayUnitSystem {
        case .metric:
            return formatter.string(from: measurement.converted(to: .celsius))
        case .imperial:
            return formatter.string(from: measurement.converted(to: .fahrenheit))
        }
    }

    private func formattedWind(_ measurement: Measurement<UnitSpeed>) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        switch displayUnitSystem {
        case .metric:
            return formatter.string(from: measurement.converted(to: .kilometersPerHour))
        case .imperial:
            return formatter.string(from: measurement.converted(to: .milesPerHour))
        }
    }

    private func formattedWindKnots(_ measurement: Measurement<UnitSpeed>?) -> String {
        guard let measurement else { return "—" }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter.string(from: measurement.converted(to: .knots))
    }

    private func formattedRain(_ measurement: Measurement<UnitLength>?) -> String {
        guard let measurement else { return "—" }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter.string(from: measurement.converted(to: .millimeters))
    }

    private func numericTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let value: Double = switch displayUnitSystem {
        case .metric:
            measurement.converted(to: .celsius).value
        case .imperial:
            measurement.converted(to: .fahrenheit).value
        }
        return roundedText(value)
    }

    private func numericWindKnots(_ measurement: Measurement<UnitSpeed>?) -> String {
        guard let measurement else { return "—" }
        return roundedText(measurement.converted(to: .knots).value)
    }

    private func numericRain(_ measurement: Measurement<UnitLength>?) -> String {
        guard let measurement else { return "—" }
        return roundedText(measurement.converted(to: .millimeters).value, maximumFractionDigits: 1)
    }

    private func numericUV(_ value: Double) -> String {
        roundedText(value, maximumFractionDigits: 1)
    }

    private func numericPressure(_ measurement: Measurement<UnitPressure>) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let value = measurement.converted(to: .hectopascals).value
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value.rounded()))
    }

    private func roundedText(_ value: Double, maximumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(maximumFractionDigits)f", value)
    }

    private func formattedHumidity(_ fraction: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: fraction)) ?? "\(Int(fraction * 100))%"
    }

    private func formattedWindDirection(degrees: Double, abbreviation: String) -> String {
        "\(Int(degrees.rounded()))° \(abbreviation)"
    }

    private func failureMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "Unable to load weather for this map location right now."
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private let hourTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func intervalTimeText(for interval: WeatherForecast.IntervalSummary) -> String {
        if interval.periodHours == 1 {
            return hourTimeFormatter.string(from: interval.date)
        } else {
            let endDate = interval.date.addingTimeInterval(TimeInterval(interval.periodHours * 3600))
            return "\(hourTimeFormatter.string(from: interval.date))-\n\(hourTimeFormatter.string(from: endDate))"
        }
    }

    private let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d")
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()
}
