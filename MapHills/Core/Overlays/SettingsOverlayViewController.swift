//
//  PrimaryOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit

final class SettingsOverlayViewController: UIViewController {
    private enum NearestHundredSetupMode: Int, CaseIterable {
        case currentPosition
        case gridReference

        var title: String {
            switch self {
            case .currentPosition:
                return "Current Position"
            case .gridReference:
                return "Grid Ref"
            }
        }
    }

    private var selectedMapOrientationMode: MapOrientationMode
    private var isMapInteractionLocked: Bool
    private var selectedTrackRecordingQuality: TrackRecordingQuality
    private var showsSnailTrail: Bool
    private var snailTrailColor: UIColor
    private var goToLineColor: UIColor
    private var recordedTrackColor: UIColor
    private var importedTrackColor: UIColor
    private var markerColorOptions: [MarkerColorOption]
    private var showsHillMarkers: Bool
    private var showsGridLines: Bool
    private var visibleStartPlaceProviders: Set<StartPlaceProvider>
    private var startPlaceRouteLengthFilter: StartPlaceRouteLengthFilter
    private var nearestHundredConfiguration: NearestHundredConfiguration?
    private let currentPositionGridReference: String?
    private let mapOrientationModeChangeHandler: (MapOrientationMode) -> Void
    private let mapInteractionLockChangeHandler: (Bool) -> Void
    private let trackRecordingQualityChangeHandler: (TrackRecordingQuality) -> Void
    private let snailTrailVisibilityChangeHandler: (Bool) -> Void
    private let snailTrailColorChangeHandler: (UIColor) -> Void
    private let goToLineColorChangeHandler: (UIColor) -> Void
    private let recordedTrackColorChangeHandler: (UIColor) -> Void
    private let importedTrackColorChangeHandler: (UIColor) -> Void
    private let markerColorChangeHandler: (String, UIColor) -> Void
    private let hillMarkerVisibilityChangeHandler: (Bool) -> Void
    private let gridLineVisibilityChangeHandler: (Bool) -> Void
    private let startPlaceProviderVisibilityChangeHandler: (Set<StartPlaceProvider>) -> Void
    private let startPlaceRouteLengthFilterChangeHandler: (StartPlaceRouteLengthFilter) -> Void
    private let startPlaceProviderCountProvider: (StartPlaceProvider, StartPlaceRouteLengthFilter) -> Int
    private let nearestHundredFromGridReferenceHandler: (String) -> NearestHundredSetupResult
    private let nearestHundredFromCurrentPositionHandler: () -> NearestHundredSetupResult
    private let nearestHundredResetHandler: () -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let contentScrollView = UIScrollView()
    private let mapOrientationModeControl = UISegmentedControl(items: MapOrientationMode.allCases.map(\.title))
    private let mapInteractionLockSwitch = UISwitch()
    private let trackRecordingQualityControl = UISegmentedControl(items: TrackRecordingQuality.allCases.map(\.title))
    private let snailTrailSwitch = UISwitch()
    private let snailTrailColorWell = UIColorWell()
    private let goToLineColorWell = UIColorWell()
    private let recordedTrackColorWell = UIColorWell()
    private let importedTrackColorWell = UIColorWell()
    private let hillMarkerSwitch = UISwitch()
    private let gridLineSwitch = UISwitch()
    private let mapOrientationModeLabel = UILabel()
    private let trackRecordingModeLabel = UILabel()
    private let nearestHundredSetupModeControl = UISegmentedControl(items: NearestHundredSetupMode.allCases.map(\.title))
    private let nearestHundredStatusButton = UIButton(type: .system)
    private let nearestHundredCurrentPositionLabel = UILabel()
    private let nearestHundredGridReferenceField = UITextField()
    private let startPlaceRouteLengthFilterButton = UIButton(type: .system)
    private var startPlaceProviderSwitches: [StartPlaceProvider: UISwitch] = [:]
    private var startPlaceProviderCountLabels: [StartPlaceProvider: UILabel] = [:]
    private let nearestHundredGridReferenceStack = UIStackView()
    private let nearestHundredCurrentPositionStack = UIStackView()

    init(
        selectedMapOrientationMode: MapOrientationMode,
        isMapInteractionLocked: Bool,
        selectedTrackRecordingQuality: TrackRecordingQuality,
        showsSnailTrail: Bool,
        snailTrailColor: UIColor,
        goToLineColor: UIColor,
        recordedTrackColor: UIColor,
        importedTrackColor: UIColor,
        markerColorOptions: [MarkerColorOption],
        showsHillMarkers: Bool,
        showsGridLines: Bool,
        visibleStartPlaceProviders: Set<StartPlaceProvider>,
        startPlaceRouteLengthFilter: StartPlaceRouteLengthFilter,
        localHundredConfiguration: LocalHundredConfiguration?,
        currentPositionGridReference: String?,
        mapOrientationModeChangeHandler: @escaping (MapOrientationMode) -> Void,
        mapInteractionLockChangeHandler: @escaping (Bool) -> Void,
        trackRecordingQualityChangeHandler: @escaping (TrackRecordingQuality) -> Void,
        snailTrailVisibilityChangeHandler: @escaping (Bool) -> Void,
        snailTrailColorChangeHandler: @escaping (UIColor) -> Void,
        goToLineColorChangeHandler: @escaping (UIColor) -> Void,
        recordedTrackColorChangeHandler: @escaping (UIColor) -> Void,
        importedTrackColorChangeHandler: @escaping (UIColor) -> Void,
        markerColorChangeHandler: @escaping (String, UIColor) -> Void,
        hillMarkerVisibilityChangeHandler: @escaping (Bool) -> Void,
        gridLineVisibilityChangeHandler: @escaping (Bool) -> Void,
        startPlaceProviderVisibilityChangeHandler: @escaping (Set<StartPlaceProvider>) -> Void,
        startPlaceRouteLengthFilterChangeHandler: @escaping (StartPlaceRouteLengthFilter) -> Void,
        startPlaceProviderCountProvider: @escaping (StartPlaceProvider, StartPlaceRouteLengthFilter) -> Int,
        localHundredFromGridReferenceHandler: @escaping (String) -> LocalHundredSetupResult,
        localHundredFromCurrentPositionHandler: @escaping () -> LocalHundredSetupResult,
        localHundredResetHandler: @escaping () -> Void
    ) {
        self.selectedMapOrientationMode = selectedMapOrientationMode
        self.isMapInteractionLocked = isMapInteractionLocked
        self.selectedTrackRecordingQuality = selectedTrackRecordingQuality
        self.showsSnailTrail = showsSnailTrail
        self.snailTrailColor = snailTrailColor
        self.goToLineColor = goToLineColor
        self.recordedTrackColor = recordedTrackColor
        self.importedTrackColor = importedTrackColor
        self.markerColorOptions = markerColorOptions
        self.showsHillMarkers = showsHillMarkers
        self.showsGridLines = showsGridLines
        self.visibleStartPlaceProviders = visibleStartPlaceProviders
        self.startPlaceRouteLengthFilter = startPlaceRouteLengthFilter
        self.nearestHundredConfiguration = localHundredConfiguration
        self.currentPositionGridReference = currentPositionGridReference
        self.mapOrientationModeChangeHandler = mapOrientationModeChangeHandler
        self.mapInteractionLockChangeHandler = mapInteractionLockChangeHandler
        self.trackRecordingQualityChangeHandler = trackRecordingQualityChangeHandler
        self.snailTrailVisibilityChangeHandler = snailTrailVisibilityChangeHandler
        self.snailTrailColorChangeHandler = snailTrailColorChangeHandler
        self.goToLineColorChangeHandler = goToLineColorChangeHandler
        self.recordedTrackColorChangeHandler = recordedTrackColorChangeHandler
        self.importedTrackColorChangeHandler = importedTrackColorChangeHandler
        self.markerColorChangeHandler = markerColorChangeHandler
        self.hillMarkerVisibilityChangeHandler = hillMarkerVisibilityChangeHandler
        self.gridLineVisibilityChangeHandler = gridLineVisibilityChangeHandler
        self.startPlaceProviderVisibilityChangeHandler = startPlaceProviderVisibilityChangeHandler
        self.startPlaceRouteLengthFilterChangeHandler = startPlaceRouteLengthFilterChangeHandler
        self.startPlaceProviderCountProvider = startPlaceProviderCountProvider
        self.nearestHundredFromGridReferenceHandler = localHundredFromGridReferenceHandler
        self.nearestHundredFromCurrentPositionHandler = localHundredFromCurrentPositionHandler
        self.nearestHundredResetHandler = localHundredResetHandler
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(OverlayChromeStyle.dimmingAlpha)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissSettings)))
        view.addSubview(dimmingView)

        configureOverlayCardChrome(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.alwaysBounceVertical = true
        cardView.addSubview(contentScrollView)

        let titleLabel = makeOverlayTitleLabel("Settings")
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        mapOrientationModeLabel.font = OverlayChromeStyle.bodyFont
        mapOrientationModeLabel.textColor = .secondaryLabel
        mapOrientationModeLabel.numberOfLines = 0
        mapOrientationModeLabel.text = selectedMapOrientationMode.descriptionText

        let orientationSection = makeSectionView(
            title: "Map Orientation",
            description: "Choose whether the map stays north-up or rotates toward your heading."
        ) { container in
            styleSchemaControl(mapOrientationModeControl)
            mapOrientationModeControl.selectedSegmentIndex = selectedMapOrientationMode.rawValue
            mapOrientationModeControl.addTarget(self, action: #selector(mapOrientationModeChanged(_:)), for: .valueChanged)

            let stack = UIStackView(arrangedSubviews: [
                mapOrientationModeControl,
                mapOrientationModeLabel
            ])
            stack.axis = .vertical
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        let mapInteractionSection = makeSectionView(
            title: "Map Interaction",
            description: "Control whether the map accepts pan, pinch, and rotate gestures."
        ) { container in
            mapInteractionLockSwitch.accessibilityIdentifier = "mapInteractionLockSwitch"
            mapInteractionLockSwitch.isOn = isMapInteractionLocked
            mapInteractionLockSwitch.addTarget(self, action: #selector(mapInteractionLockSwitchChanged(_:)), for: .valueChanged)
            let mapInteractionLockStack = makeMapInteractionLockStack(
                noteText: "When locked, the map keeps the selected orientation and ignores pan, pinch, and rotate gestures.",
                lockSwitch: mapInteractionLockSwitch
            )
            mapInteractionLockStack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(mapInteractionLockStack)

            NSLayoutConstraint.activate([
                mapInteractionLockStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                mapInteractionLockStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                mapInteractionLockStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                mapInteractionLockStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        trackRecordingModeLabel.font = OverlayChromeStyle.bodyFont
        trackRecordingModeLabel.textColor = .secondaryLabel
        trackRecordingModeLabel.numberOfLines = 0
        trackRecordingModeLabel.text = selectedTrackRecordingQuality.descriptionText

        let recordingSection = makeSectionView(
            title: "Track Recording",
            description: "Choose how densely the app records GPX points while walking."
        ) { container in
            styleSchemaControl(trackRecordingQualityControl)
            trackRecordingQualityControl.selectedSegmentIndex = selectedTrackRecordingQuality.rawValue
            trackRecordingQualityControl.addTarget(self, action: #selector(trackRecordingQualityChanged(_:)), for: .valueChanged)

            let stack = UIStackView(arrangedSubviews: [trackRecordingQualityControl, trackRecordingModeLabel])
            stack.axis = .vertical
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        let snailTrailSection = makeSectionView(
            title: "Snail Trail",
            description: "Control whether the lightweight non-recording trail is shown on the map."
        ) { container in
            snailTrailSwitch.accessibilityIdentifier = "snailTrailSwitch"
            snailTrailSwitch.isOn = showsSnailTrail
            snailTrailSwitch.addTarget(self, action: #selector(snailTrailSwitchChanged(_:)), for: .valueChanged)

            let snailTrailLabel = UILabel()
            snailTrailLabel.text = "Show Snail Trail"
            snailTrailLabel.font = OverlayChromeStyle.bodyFont
            snailTrailLabel.textColor = .label

            let snailTrailRow = UIStackView(arrangedSubviews: [snailTrailLabel, snailTrailSwitch])
            snailTrailRow.axis = .horizontal
            snailTrailRow.alignment = .center
            snailTrailRow.distribution = .equalSpacing
            snailTrailRow.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(snailTrailRow)

            NSLayoutConstraint.activate([
                snailTrailRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                snailTrailRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                snailTrailRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                snailTrailRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        let coloursSection = makeSectionView(
            title: "Colours",
            description: "Choose colours for markers, points and lines."
        ) { container in
            func colorRow(for index: Int, option: MarkerColorOption) -> UIStackView {
                let colorWell = UIColorWell()
                colorWell.selectedColor = option.color
                colorWell.supportsAlpha = false
                colorWell.tag = index
                colorWell.addTarget(self, action: #selector(markerColorOptionChanged(_:)), for: .valueChanged)
                return self.makeColorWellRow(title: option.title, colorWell: colorWell)
            }

            snailTrailColorWell.selectedColor = snailTrailColor
            snailTrailColorWell.supportsAlpha = false
            snailTrailColorWell.addTarget(self, action: #selector(snailTrailColorChanged(_:)), for: .valueChanged)

            goToLineColorWell.selectedColor = goToLineColor
            goToLineColorWell.supportsAlpha = false
            goToLineColorWell.addTarget(self, action: #selector(goToLineColorChanged(_:)), for: .valueChanged)

            recordedTrackColorWell.selectedColor = recordedTrackColor
            recordedTrackColorWell.supportsAlpha = false
            recordedTrackColorWell.addTarget(self, action: #selector(recordedTrackColorChanged(_:)), for: .valueChanged)

            importedTrackColorWell.selectedColor = importedTrackColor
            importedTrackColorWell.supportsAlpha = false
            importedTrackColorWell.addTarget(self, action: #selector(importedTrackColorChanged(_:)), for: .valueChanged)

            let startPointOptionIDs = ["mvStartPoints", "coillteStartPoints", "sportIrelandStartPoints", "outscapeStartPoints"]
            let generalRows = markerColorOptions.enumerated()
                .filter { !startPointOptionIDs.contains($0.element.id) }
                .map { colorRow(for: $0.offset, option: $0.element) }

            let startPointRows = startPointOptionIDs.compactMap { optionID -> UIStackView? in
                guard let indexedOption = markerColorOptions.enumerated().first(where: { $0.element.id == optionID }) else { return nil }
                return colorRow(for: indexedOption.offset, option: indexedOption.element)
            }

            let trackRows = [
                makeColorWellRow(title: "Snail Trail", colorWell: snailTrailColorWell),
                makeColorWellRow(title: "Go To Line", colorWell: goToLineColorWell),
                makeColorWellRow(title: "Recorded Track", colorWell: recordedTrackColorWell),
                makeColorWellRow(title: "Imported GPX", colorWell: importedTrackColorWell)
            ]
            let markersSubhead = makeColourSubheadLabel("Markers")
            let startPointsSubhead = makeColourSubheadLabel("Start Points")
            let tracksSubhead = makeColourSubheadLabel("Tracks")
            let firstDivider = makeDividerView()
            let secondDivider = makeDividerView()
            let stack = UIStackView(
                arrangedSubviews: [markersSubhead] + generalRows + [
                    firstDivider,
                    startPointsSubhead
                ] + startPointRows + [
                    secondDivider,
                    tracksSubhead
                ] + trackRows
            )
            stack.axis = .vertical
            stack.spacing = 8
            stack.setCustomSpacing(10, after: markersSubhead)
            stack.setCustomSpacing(12, after: generalRows.last ?? markersSubhead)
            stack.setCustomSpacing(10, after: firstDivider)
            stack.setCustomSpacing(10, after: startPointsSubhead)
            stack.setCustomSpacing(12, after: startPointRows.last ?? startPointsSubhead)
            stack.setCustomSpacing(10, after: secondDivider)
            stack.setCustomSpacing(10, after: tracksSubhead)
            stack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        let displayStartPointsSection = makeSectionView(
            title: "Display Start Points",
            description: "Choose which start-point datasets are shown on the map and hide those relating to shorter provider routes."
        ) { container in
            func switchRow(for provider: StartPlaceProvider) -> UIStackView {
                let toggle = UISwitch()
                toggle.isOn = visibleStartPlaceProviders.contains(provider)
                guard let index = StartPlaceProvider.allCases.firstIndex(of: provider) else {
                    return UIStackView()
                }
                toggle.tag = index
                toggle.addTarget(self, action: #selector(startPlaceProviderSwitchChanged(_:)), for: .valueChanged)
                startPlaceProviderSwitches[provider] = toggle
                return self.makeProviderSwitchRow(for: provider, toggle: toggle)
            }

            let mountainViewsRow = switchRow(for: .mountainViews)
            let providerRoutesLabel = makeInlineSectionLabel("Provider Routes")
            let providerRows = StartPlaceProvider.allCases
                .filter { $0 != .mountainViews }
                .map(switchRow(for:))

            configureStartPlaceRouteLengthFilterButton()
            let routeLengthFilterRow = makeButtonRow(
                title: "Hide routes shorter than",
                button: startPlaceRouteLengthFilterButton
            )

            let stack = UIStackView(arrangedSubviews: [mountainViewsRow, makeDividerView(), providerRoutesLabel] + providerRows + [routeLengthFilterRow])
            stack.axis = .vertical
            stack.spacing = 8
            stack.setCustomSpacing(12, after: mountainViewsRow)
            stack.setCustomSpacing(12, after: providerRows.last ?? providerRoutesLabel)
            stack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        let mapDetailSection = makeSectionView(
            title: "Map Detail",
            description: "Control optional map detail overlays. Search, filters, and records remain available when hill markers are hidden."
        ) { container in
            hillMarkerSwitch.accessibilityIdentifier = "hillMarkerSwitch"
            hillMarkerSwitch.isOn = showsHillMarkers
            hillMarkerSwitch.addTarget(self, action: #selector(hillMarkerSwitchChanged(_:)), for: .valueChanged)

            gridLineSwitch.accessibilityIdentifier = "gridLineSwitch"
            gridLineSwitch.isOn = showsGridLines
            gridLineSwitch.addTarget(self, action: #selector(gridLineSwitchChanged(_:)), for: .valueChanged)

            let stack = UIStackView(arrangedSubviews: [
                self.makeSwitchRow(title: "Show Hill Markers", toggle: hillMarkerSwitch),
                self.makeSwitchRow(title: "Display Grid Lines", toggle: gridLineSwitch)
            ])
            stack.axis = .vertical
            stack.spacing = 10
            stack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        nearestHundredStatusButton.isUserInteractionEnabled = false
        nearestHundredStatusButton.accessibilityIdentifier = "nearestHundredStatusButton"
        nearestHundredStatusButton.titleLabel?.numberOfLines = 0
        nearestHundredStatusButton.titleLabel?.textAlignment = .center

        nearestHundredCurrentPositionLabel.font = OverlayChromeStyle.bodyFont
        nearestHundredCurrentPositionLabel.textColor = .secondaryLabel
        nearestHundredCurrentPositionLabel.numberOfLines = 0

        nearestHundredGridReferenceField.borderStyle = .roundedRect
        nearestHundredGridReferenceField.accessibilityIdentifier = "nearestHundredGridReferenceField"
        nearestHundredGridReferenceField.placeholder = "Grid Reference"
        nearestHundredGridReferenceField.autocapitalizationType = .allCharacters
        nearestHundredGridReferenceField.autocorrectionType = .no
        nearestHundredGridReferenceField.clearButtonMode = .whileEditing
        nearestHundredGridReferenceField.text = nearestHundredConfiguration?.source == .gridReference
            ? nearestHundredConfiguration?.gridReference
            : nil

        let setGridReferenceButton = UIButton(type: .system)
        setGridReferenceButton.accessibilityIdentifier = "setNearestHundredGridReferenceButton"
        setGridReferenceButton.configuration = compactChromeButtonConfiguration(title: "Set from Grid Ref", color: .systemBlue)
        setGridReferenceButton.addTarget(self, action: #selector(setNearestHundredFromGridReference), for: .touchUpInside)

        let useCurrentPositionButton = UIButton(type: .system)
        useCurrentPositionButton.accessibilityIdentifier = "useCurrentPositionNearestHundredButton"
        useCurrentPositionButton.configuration = compactChromeButtonConfiguration(title: "Set from Current Position", color: .systemBlue)
        useCurrentPositionButton.configuration?.attributedTitle = AttributedString(
            "Set from Current Position",
            attributes: AttributeContainer([
                .font: OverlayChromeStyle.supportingFont,
                .foregroundColor: UIColor.white
            ])
        )
        useCurrentPositionButton.addTarget(self, action: #selector(setNearestHundredFromCurrentPosition), for: .touchUpInside)

        let resetNearestHundredButton = UIButton(type: .system)
        resetNearestHundredButton.accessibilityIdentifier = "resetNearestHundredButton"
        resetNearestHundredButton.configuration = compactChromeButtonConfiguration(title: "Unset Nearest 100", color: .systemRed)
        resetNearestHundredButton.addTarget(self, action: #selector(resetNearestHundred), for: .touchUpInside)

        nearestHundredGridReferenceStack.axis = .vertical
        nearestHundredGridReferenceStack.spacing = 8
        nearestHundredGridReferenceStack.addArrangedSubview(nearestHundredGridReferenceField)
        nearestHundredGridReferenceStack.addArrangedSubview(setGridReferenceButton)

        nearestHundredCurrentPositionStack.axis = .vertical
        nearestHundredCurrentPositionStack.spacing = 8
        nearestHundredCurrentPositionStack.addArrangedSubview(nearestHundredCurrentPositionLabel)
        nearestHundredCurrentPositionStack.addArrangedSubview(useCurrentPositionButton)

        let nearestHundredResetSeparator = UIView()
        nearestHundredResetSeparator.translatesAutoresizingMaskIntoConstraints = false
        nearestHundredResetSeparator.backgroundColor = UIColor.tertiaryLabel.withAlphaComponent(0.45)
        NSLayoutConstraint.activate([
            nearestHundredResetSeparator.heightAnchor.constraint(equalToConstant: 1.5)
        ])

        let nearestHundredModeSeparator = UIView()
        nearestHundredModeSeparator.translatesAutoresizingMaskIntoConstraints = false
        nearestHundredModeSeparator.backgroundColor = UIColor.tertiaryLabel.withAlphaComponent(0.45)
        NSLayoutConstraint.activate([
            nearestHundredModeSeparator.heightAnchor.constraint(equalToConstant: 1.5)
        ])

        let nearestHundredSection = makeSectionView(
            title: "Nearest 100",
            description: "Pick a fixed reference point for the 100 nearest hills. The Nearest 100 filter stays visible even before it is set up."
        ) { container in
            styleSchemaControl(nearestHundredSetupModeControl)
            nearestHundredSetupModeControl.apportionsSegmentWidthsByContent = true
            nearestHundredSetupModeControl.accessibilityIdentifier = "nearestHundredSetupModeControl"
            let initialSetupMode: NearestHundredSetupMode = nearestHundredConfiguration?.source == .gridReference ? .gridReference : .currentPosition
            nearestHundredSetupModeControl.selectedSegmentIndex = initialSetupMode.rawValue
            nearestHundredSetupModeControl.addTarget(self, action: #selector(nearestHundredSetupModeChanged(_:)), for: .valueChanged)

            let stack = UIStackView(arrangedSubviews: [
                nearestHundredStatusButton,
                nearestHundredModeSeparator,
                nearestHundredSetupModeControl,
                nearestHundredCurrentPositionStack,
                nearestHundredGridReferenceStack,
                nearestHundredResetSeparator,
                resetNearestHundredButton
            ])
            stack.axis = .vertical
            stack.spacing = 8
            stack.setCustomSpacing(14, after: nearestHundredStatusButton)
            stack.setCustomSpacing(14, after: nearestHundredModeSeparator)
            stack.setCustomSpacing(16, after: nearestHundredGridReferenceStack)
            stack.setCustomSpacing(14, after: nearestHundredResetSeparator)
            stack.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
                stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
                stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
                stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
            ])
        }

        let closeButton = UIButton(type: .system)
        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.addTarget(self, action: #selector(dismissSettings), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [
            titleRow,
            orientationSection,
            mapInteractionSection,
            mapDetailSection,
            displayStartPointsSection,
            recordingSection,
            snailTrailSection,
            coloursSection,
            nearestHundredSection
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStack)

        let footerContainerView = UIView()
        footerContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(footerContainerView)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        footerContainerView.addSubview(closeButton)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -24),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: safeArea.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -24),
            cardView.widthAnchor.constraint(equalToConstant: 320),
            cardView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: 0.7),

            contentScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentScrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentScrollView.bottomAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: -12),

            footerContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            footerContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            footerContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            footerContainerView.heightAnchor.constraint(equalToConstant: 32),

            closeButton.centerXAnchor.constraint(equalTo: footerContainerView.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: footerContainerView.centerYAnchor),

            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor)
        ])

        updateNearestHundredLabels()
        updateNearestHundredSetupModeUI()
    }

    private func makeSectionView(
        title: String,
        description: String,
        contentBuilder: (UIView) -> Void
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = OverlayChromeStyle.sectionTitleFont
        titleLabel.textColor = .label

        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = OverlayChromeStyle.bodyFont
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0

        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, contentContainer])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let containerView = UIView()
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.separator.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14)
        ])

        contentBuilder(contentContainer)
        return containerView
    }

    private func makeSectionView(
        title: String,
        attributedDescription: NSAttributedString,
        contentBuilder: (UIView) -> Void
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = OverlayChromeStyle.sectionTitleFont
        titleLabel.textColor = .label

        let descriptionLabel = UILabel()
        descriptionLabel.attributedText = attributedDescription
        descriptionLabel.numberOfLines = 0

        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, contentContainer])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let containerView = UIView()
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.separator.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14)
        ])

        contentBuilder(contentContainer)
        return containerView
    }

    private func styleSchemaControl(_ control: UISegmentedControl) {
        control.selectedSegmentTintColor = .systemBlue
        control.backgroundColor = UIColor.secondarySystemBackground
        control.setTitleTextAttributes([
            .font: OverlayChromeStyle.supportingFont,
            .foregroundColor: UIColor.label
        ], for: .normal)
        control.setTitleTextAttributes([
            .font: OverlayChromeStyle.supportingFont,
            .foregroundColor: UIColor.white
        ], for: .selected)
    }

    private func makeColorWellRow(title: String, colorWell: UIColorWell) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = OverlayChromeStyle.bodyFont
        titleLabel.textColor = .label

        let row = UIStackView(arrangedSubviews: [titleLabel, colorWell])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        return row
    }

    private func makeSwitchRow(title: String, toggle: UISwitch) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = OverlayChromeStyle.bodyFont
        titleLabel.textColor = .label

        let row = UIStackView(arrangedSubviews: [titleLabel, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        return row
    }

    private func makeProviderSwitchRow(for provider: StartPlaceProvider, toggle: UISwitch) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = provider.title
        titleLabel.font = OverlayChromeStyle.bodyFont
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        let countLabel = UILabel()
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        countLabel.textColor = .secondaryLabel
        countLabel.textAlignment = .right
        countLabel.numberOfLines = 1
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        startPlaceProviderCountLabels[provider] = countLabel
        updateStartPlaceProviderCountLabel(countLabel, for: provider)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        titleStack.axis = .horizontal
        titleStack.alignment = .firstBaseline
        titleStack.spacing = 6
        titleStack.distribution = .fill
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleStack, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.distribution = .fill
        titleStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    private func makeInlineSectionLabel(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = OverlayChromeStyle.supportingFont
        label.textColor = .secondaryLabel
        return label
    }

    private func makeColourSubheadLabel(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .systemBlue
        label.numberOfLines = 1
        return label
    }

    private func makeDividerView() -> UIView {
        let divider = UIView()
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.7)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return divider
    }

    private func makeButtonRow(title: String, button: UIButton) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = OverlayChromeStyle.bodyFont
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [titleLabel, button])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.distribution = .fill
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    private func updateStartPlaceProviderCountLabel(_ label: UILabel, for provider: StartPlaceProvider) {
        let count = startPlaceProviderCountProvider(provider, startPlaceRouteLengthFilter)
        let countText = NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
        label.text = countText
        label.accessibilityLabel = "\(provider.title) points after filter: \(countText)"
    }

    private func refreshStartPlaceProviderCountLabels() {
        for (provider, label) in startPlaceProviderCountLabels {
            updateStartPlaceProviderCountLabel(label, for: provider)
        }
    }

    private func configureStartPlaceRouteLengthFilterButton() {
        var configuration = UIButton.Configuration.tinted()
        configuration.cornerStyle = .medium
        configuration.baseForegroundColor = .systemBlue
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.title = startPlaceRouteLengthFilter.title
        configuration.image = UIImage(systemName: "chevron.up.chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        startPlaceRouteLengthFilterButton.configuration = configuration
        startPlaceRouteLengthFilterButton.showsMenuAsPrimaryAction = true
        startPlaceRouteLengthFilterButton.menu = UIMenu(children: StartPlaceRouteLengthFilter.allCases.map { filter in
            UIAction(
                title: filter.title,
                state: filter == startPlaceRouteLengthFilter ? .on : .off
            ) { [weak self] _ in
                self?.selectStartPlaceRouteLengthFilter(filter)
            }
        })
    }

    private func buttonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = color
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: color
            ])
        )
        return configuration
    }

    private func chromeButtonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: OverlayChromeStyle.sectionTitleFont,
                .foregroundColor: UIColor.white
            ])
        )
        return configuration
    }

    private func compactChromeButtonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: OverlayChromeStyle.supportingFont,
                .foregroundColor: UIColor.white
            ])
        )
        return configuration
    }

    private func updateNearestHundredLabels() {
        if let nearestHundredConfiguration {
            let sourceTitle = nearestHundredConfiguration.source == .gridReference ? "Grid Ref" : "Current Position"
            var configuration = compactChromeButtonConfiguration(title: "", color: .systemGreen)
            configuration.attributedTitle = AttributedString(
                "Nearest 100 active via \(sourceTitle)\nReference: \(nearestHundredConfiguration.gridReference)",
                attributes: AttributeContainer([
                    .font: OverlayChromeStyle.supportingFont,
                    .foregroundColor: UIColor.white
                ])
            )
            nearestHundredStatusButton.configuration = configuration
        } else {
            var configuration = compactChromeButtonConfiguration(title: "", color: .systemRed)
            configuration.attributedTitle = AttributedString(
                "Current setup: Not set",
                attributes: AttributeContainer([
                    .font: OverlayChromeStyle.supportingFont,
                    .foregroundColor: UIColor.white
                ])
            )
            nearestHundredStatusButton.configuration = configuration
        }

        if let currentPositionGridReference {
            nearestHundredCurrentPositionLabel.text = "Position: \(currentPositionGridReference)"
        } else {
            nearestHundredCurrentPositionLabel.text = "Position: u/a"
        }
    }

    private func updateNearestHundredSetupModeUI() {
        let selectedMode = NearestHundredSetupMode(rawValue: nearestHundredSetupModeControl.selectedSegmentIndex) ?? .currentPosition
        nearestHundredCurrentPositionStack.isHidden = selectedMode != .currentPosition
        nearestHundredGridReferenceStack.isHidden = selectedMode != .gridReference
    }

    private func presentNearestHundredAlert(title: String, message: String) {
        guard presentedViewController == nil else { return }
        let overlay = ActionOverlayViewController(
            title: title,
            message: message,
            actions: [
                .init(title: "OK", style: .normal, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    private func presentNearestHundredSuccessAlert(for configuration: NearestHundredConfiguration) {
        let sourceTitle = configuration.source == .gridReference ? "Grid Ref" : "Current Position"
        presentNearestHundredAlert(
            title: "Nearest 100 Ready",
            message: "Nearest 100 has been set from \(sourceTitle) using \(configuration.gridReference)."
        )
    }

    @objc private func mapOrientationModeChanged(_ sender: UISegmentedControl) {
        guard let mapOrientationMode = MapOrientationMode(rawValue: sender.selectedSegmentIndex) else { return }
        selectedMapOrientationMode = mapOrientationMode
        mapOrientationModeLabel.text = mapOrientationMode.descriptionText
        mapOrientationModeChangeHandler(mapOrientationMode)
    }

    func syncMapInteractionLockState(_ isLocked: Bool) {
        isMapInteractionLocked = isLocked
        mapInteractionLockSwitch.isOn = isLocked
    }

    @objc private func mapInteractionLockSwitchChanged(_ sender: UISwitch) {
        isMapInteractionLocked = sender.isOn
        mapInteractionLockChangeHandler(sender.isOn)
    }

    @objc private func trackRecordingQualityChanged(_ sender: UISegmentedControl) {
        guard let trackRecordingQuality = TrackRecordingQuality(rawValue: sender.selectedSegmentIndex) else { return }
        selectedTrackRecordingQuality = trackRecordingQuality
        trackRecordingModeLabel.text = trackRecordingQuality.descriptionText
        trackRecordingQualityChangeHandler(trackRecordingQuality)
    }

    @objc private func snailTrailSwitchChanged(_ sender: UISwitch) {
        showsSnailTrail = sender.isOn
        snailTrailVisibilityChangeHandler(sender.isOn)
    }

    @objc private func recordedTrackColorChanged(_ sender: UIColorWell) {
        guard let selectedColor = sender.selectedColor else { return }
        recordedTrackColor = selectedColor
        recordedTrackColorChangeHandler(selectedColor)
    }

    @objc private func goToLineColorChanged(_ sender: UIColorWell) {
        guard let selectedColor = sender.selectedColor else { return }
        goToLineColor = selectedColor
        goToLineColorChangeHandler(selectedColor)
    }

    @objc private func snailTrailColorChanged(_ sender: UIColorWell) {
        guard let selectedColor = sender.selectedColor else { return }
        snailTrailColor = selectedColor
        snailTrailColorChangeHandler(selectedColor)
    }

    @objc private func importedTrackColorChanged(_ sender: UIColorWell) {
        guard let selectedColor = sender.selectedColor else { return }
        importedTrackColor = selectedColor
        importedTrackColorChangeHandler(selectedColor)
    }

    @objc private func markerColorOptionChanged(_ sender: UIColorWell) {
        guard markerColorOptions.indices.contains(sender.tag),
              let selectedColor = sender.selectedColor else { return }
        markerColorOptions[sender.tag].color = selectedColor
        markerColorChangeHandler(markerColorOptions[sender.tag].id, selectedColor)
    }

    @objc private func hillMarkerSwitchChanged(_ sender: UISwitch) {
        showsHillMarkers = sender.isOn
        hillMarkerVisibilityChangeHandler(sender.isOn)
    }

    @objc private func gridLineSwitchChanged(_ sender: UISwitch) {
        showsGridLines = sender.isOn
        gridLineVisibilityChangeHandler(sender.isOn)
    }

    @objc private func startPlaceProviderSwitchChanged(_ sender: UISwitch) {
        guard StartPlaceProvider.allCases.indices.contains(sender.tag) else { return }
        let provider = StartPlaceProvider.allCases[sender.tag]
        if sender.isOn {
            visibleStartPlaceProviders.insert(provider)
        } else {
            visibleStartPlaceProviders.remove(provider)
        }
        startPlaceProviderVisibilityChangeHandler(visibleStartPlaceProviders)
    }

    private func selectStartPlaceRouteLengthFilter(_ filter: StartPlaceRouteLengthFilter) {
        guard filter != startPlaceRouteLengthFilter else { return }
        startPlaceRouteLengthFilter = filter
        configureStartPlaceRouteLengthFilterButton()
        refreshStartPlaceProviderCountLabels()
        startPlaceRouteLengthFilterChangeHandler(filter)
    }

    @objc private func nearestHundredSetupModeChanged(_ sender: UISegmentedControl) {
        updateNearestHundredSetupModeUI()
    }

    @objc private func setNearestHundredFromGridReference() {
        let input = nearestHundredGridReferenceField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch nearestHundredFromGridReferenceHandler(input) {
        case let .success(configuration):
            nearestHundredConfiguration = configuration
            nearestHundredGridReferenceField.text = configuration.gridReference
            updateNearestHundredLabels()
            presentNearestHundredSuccessAlert(for: configuration)
        case let .failure(message):
            presentNearestHundredAlert(title: "Nearest 100 Unavailable", message: message)
        }
    }

    @objc private func setNearestHundredFromCurrentPosition() {
        switch nearestHundredFromCurrentPositionHandler() {
        case let .success(configuration):
            nearestHundredConfiguration = configuration
            updateNearestHundredLabels()
            presentNearestHundredSuccessAlert(for: configuration)
        case let .failure(message):
            presentNearestHundredAlert(title: "Nearest 100 Unavailable", message: message)
        }
    }

    @objc private func resetNearestHundred() {
        nearestHundredResetHandler()
        nearestHundredConfiguration = nil
        nearestHundredGridReferenceField.text = nil
        updateNearestHundredLabels()
        presentNearestHundredAlert(title: "Nearest 100 Reset", message: "Nearest 100 has been cleared and is no longer active.")
    }

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }
}
