//
//  GPXAndInfoOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation

final class GPXOverlayViewController: UIViewController {
    private let isRecordingProvider: () -> Bool
    private let hasRecordingProvider: () -> Bool
    private let hasSavableRecordingProvider: () -> Bool
    private let hasImportedGPXProvider: () -> Bool
    private let canSaveImportedGPXProvider: () -> Bool
    private let isMapInteractionLockedProvider: () -> Bool
    private let summaryProvider: () -> GPXRecordingSummary?
    private let distanceFormatter: (CLLocationDistance) -> String
    private let elevationFormatter: (Double) -> String
    private let accuracyProvider: () -> String
    private let importHandler: () -> Void
    private let savedHandler: () -> Void
    private let waypointsHandler: () -> Void
    private let saveImportedHandler: () -> Void
    private let clearImportedHandler: () -> Void
    private let mapInteractionLockChangeHandler: (Bool) -> Void
    private let primaryRecordingHandler: () -> Void
    private let stopRecordingHandler: () -> Void
    private let saveHandler: () -> Void
    private let discardHandler: () -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let contentScrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let footerContainerView = UIView()
    private let statusContainerView = UIView()
    private let statusIconView = UIImageView()
    private let statusTitleLabel = UILabel()
    private let mapInteractionLockContainerView = UIView()
    private let mapInteractionLockSwitch = UISwitch()
    private let statsStack = UIStackView()
    private let primaryRecordingButton = UIButton(type: .system)
    private let stopRecordingButton = UIButton(type: .system)
    private let saveImportedButton = UIButton(type: .system)
    private let clearImportedButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let discardButton = UIButton(type: .system)
    private let metricsGridView = UIStackView()
    private let recordingButtonRow = UIStackView()
    private let distanceValueLabel = UILabel()
    private let timeValueLabel = UILabel()
    private let ascentValueLabel = UILabel()
    private let descentValueLabel = UILabel()
    private let elevationValueLabel = UILabel()
    private let accuracyValueLabel = UILabel()
    private let statusLabel = UILabel()
    private var refreshTimer: Timer?

    init(
        isRecordingProvider: @escaping () -> Bool,
        hasRecordingProvider: @escaping () -> Bool,
        hasSavableRecordingProvider: @escaping () -> Bool,
        hasImportedGPXProvider: @escaping () -> Bool,
        canSaveImportedGPXProvider: @escaping () -> Bool,
        isMapInteractionLockedProvider: @escaping () -> Bool,
        summaryProvider: @escaping () -> GPXRecordingSummary?,
        distanceFormatter: @escaping (CLLocationDistance) -> String,
        elevationFormatter: @escaping (Double) -> String,
        accuracyProvider: @escaping () -> String,
        importHandler: @escaping () -> Void,
        savedHandler: @escaping () -> Void,
        waypointsHandler: @escaping () -> Void,
        saveImportedHandler: @escaping () -> Void,
        clearImportedHandler: @escaping () -> Void,
        mapInteractionLockChangeHandler: @escaping (Bool) -> Void,
        primaryRecordingHandler: @escaping () -> Void,
        stopRecordingHandler: @escaping () -> Void,
        saveHandler: @escaping () -> Void,
        discardHandler: @escaping () -> Void
    ) {
        self.isRecordingProvider = isRecordingProvider
        self.hasRecordingProvider = hasRecordingProvider
        self.hasSavableRecordingProvider = hasSavableRecordingProvider
        self.hasImportedGPXProvider = hasImportedGPXProvider
        self.canSaveImportedGPXProvider = canSaveImportedGPXProvider
        self.isMapInteractionLockedProvider = isMapInteractionLockedProvider
        self.summaryProvider = summaryProvider
        self.distanceFormatter = distanceFormatter
        self.elevationFormatter = elevationFormatter
        self.accuracyProvider = accuracyProvider
        self.importHandler = importHandler
        self.savedHandler = savedHandler
        self.waypointsHandler = waypointsHandler
        self.saveImportedHandler = saveImportedHandler
        self.clearImportedHandler = clearImportedHandler
        self.mapInteractionLockChangeHandler = mapInteractionLockChangeHandler
        self.primaryRecordingHandler = primaryRecordingHandler
        self.stopRecordingHandler = stopRecordingHandler
        self.saveHandler = saveHandler
        self.discardHandler = discardHandler
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
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissOverlay)))
        view.addSubview(dimmingView)

        configureOverlayCardChrome(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.alwaysBounceVertical = true
        cardView.addSubview(contentScrollView)

        let titleLabel = makeOverlayTitleLabel("GPS Handling")
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Manage imported tracks, live recording, and saved GPX files."
        subtitleLabel.font = OverlayChromeStyle.bodyFont
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        statusContainerView.backgroundColor = UIColor.systemGray6
        statusContainerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        statusContainerView.layer.borderWidth = 1
        statusContainerView.layer.borderColor = UIColor.separator.cgColor
        statusContainerView.translatesAutoresizingMaskIntoConstraints = false

        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        statusIconView.contentMode = .scaleAspectFit
        statusIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        statusTitleLabel.font = OverlayChromeStyle.supportingFont
        statusTitleLabel.textColor = .secondaryLabel
        statusTitleLabel.text = "Recording Status"
        statusTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = OverlayChromeStyle.sectionTitleFont
        statusLabel.textColor = .label
        statusLabel.textAlignment = .left
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let fileHeaderLabel = UILabel()
        fileHeaderLabel.text = "Files"
        fileHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        fileHeaderLabel.textColor = .label
        fileHeaderLabel.textAlignment = .left

        let fileDescriptionLabel = UILabel()
        fileDescriptionLabel.text = "Import tracks, reopen saved recordings, or clear the track currently shown on the map."
        fileDescriptionLabel.font = OverlayChromeStyle.bodyFont
        fileDescriptionLabel.textColor = .secondaryLabel
        fileDescriptionLabel.numberOfLines = 0

        mapInteractionLockContainerView.backgroundColor = UIColor.secondarySystemBackground
        mapInteractionLockContainerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        mapInteractionLockContainerView.layer.borderWidth = 1
        mapInteractionLockContainerView.layer.borderColor = UIColor.separator.cgColor
        mapInteractionLockContainerView.translatesAutoresizingMaskIntoConstraints = false

        mapInteractionLockSwitch.accessibilityIdentifier = "recordingMapInteractionLockSwitch"
        mapInteractionLockSwitch.addTarget(self, action: #selector(mapInteractionLockSwitchChanged(_:)), for: .valueChanged)
        let mapInteractionLockStack = makeMapInteractionLockStack(
            noteText: "When enabled, the map ignores pan, pinch, and rotate gestures while recording.",
            lockSwitch: mapInteractionLockSwitch,
            labelFont: .systemFont(ofSize: 14, weight: .semibold)
        )

        let importButton = makeButton(title: "Import GPX File", color: .systemBlue)
        importButton.addAction(UIAction { _ in
            self.dismiss(animated: true) {
                self.importHandler()
            }
        }, for: .touchUpInside)

        let savedButton = makeButton(title: "Saved GPX Files", color: .systemBlue)
        savedButton.addAction(UIAction { _ in
            self.dismiss(animated: true) {
                self.savedHandler()
            }
        }, for: .touchUpInside)

        let waypointsButton = makeButton(title: "Waypoints", color: .systemBlue)
        waypointsButton.addAction(UIAction { _ in
            self.dismiss(animated: true) {
                self.waypointsHandler()
            }
        }, for: .touchUpInside)

        saveImportedButton.addAction(UIAction { _ in
            self.dismiss(animated: true) {
                self.saveImportedHandler()
            }
        }, for: .touchUpInside)

        clearImportedButton.addAction(UIAction { _ in
            self.dismiss(animated: true) {
                self.clearImportedHandler()
            }
        }, for: .touchUpInside)

        metricsGridView.axis = .vertical
        metricsGridView.spacing = 0
        metricsGridView.addArrangedSubview(
            metricsRow(
                leftTitle: "Distance",
                leftValueLabel: distanceValueLabel,
                rightTitle: "Time",
                rightValueLabel: timeValueLabel
            )
        )
        metricsGridView.addArrangedSubview(
            metricsRow(
                leftTitle: "Ascent",
                leftValueLabel: ascentValueLabel,
                rightTitle: "Descent",
                rightValueLabel: descentValueLabel
            )
        )
        metricsGridView.addArrangedSubview(
            metricsRow(
                leftTitle: "Elevation",
                leftValueLabel: elevationValueLabel,
                rightTitle: "Accuracy",
                rightValueLabel: accuracyValueLabel
            )
        )

        statsStack.axis = .vertical
        statsStack.alignment = .center
        statsStack.spacing = 8
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        let statsHeaderLabel = UILabel()
        statsHeaderLabel.text = "Live Stats"
        statsHeaderLabel.font = OverlayChromeStyle.sectionTitleFont
        statsHeaderLabel.textColor = .label
        statsHeaderLabel.textAlignment = .left
        statsStack.addArrangedSubview(statsHeaderLabel)
        statsStack.addArrangedSubview(metricsGridView)
        statsHeaderLabel.widthAnchor.constraint(equalTo: statsStack.widthAnchor).isActive = true
        metricsGridView.widthAnchor.constraint(equalToConstant: 220).isActive = true

        recordingButtonRow.axis = .horizontal
        recordingButtonRow.alignment = .fill
        recordingButtonRow.distribution = .fillEqually
        recordingButtonRow.spacing = 0
        recordingButtonRow.translatesAutoresizingMaskIntoConstraints = false

        primaryRecordingButton.addAction(UIAction { _ in
            self.primaryRecordingHandler()
            self.refreshContent()
        }, for: .touchUpInside)

        stopRecordingButton.addAction(UIAction { _ in
            self.stopRecordingHandler()
            self.refreshContent()
        }, for: .touchUpInside)

        saveButton.addAction(UIAction { _ in
            self.saveHandler()
            self.refreshContent()
        }, for: .touchUpInside)

        discardButton.addAction(UIAction { _ in
            self.showDiscardConfirmation()
        }, for: .touchUpInside)

        recordingButtonRow.addArrangedSubview(primaryRecordingButton)
        recordingButtonRow.addArrangedSubview(stopRecordingButton)
        recordingButtonRow.addArrangedSubview(saveButton)
        recordingButtonRow.addArrangedSubview(discardButton)
        for button in [primaryRecordingButton, stopRecordingButton, saveButton, discardButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
        }

        let fileContainerView = sectionContainerView()
        let statsContainerView = sectionContainerView()

        let fileStack = UIStackView(arrangedSubviews: [
            fileHeaderLabel,
            fileDescriptionLabel,
            importButton,
            savedButton,
            saveImportedButton,
            clearImportedButton,
            waypointsButton
        ])
        fileStack.axis = .vertical
        fileStack.spacing = 8
        fileStack.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        statusContainerView.addSubview(statusIconView)
        statusContainerView.addSubview(statusTitleLabel)
        statusContainerView.addSubview(statusLabel)
        mapInteractionLockContainerView.addSubview(mapInteractionLockStack)

        let statsContainerStack = UIStackView(arrangedSubviews: [
            mapInteractionLockContainerView,
            statsStack,
            recordingButtonRow
        ])
        statsContainerStack.axis = .vertical
        statsContainerStack.spacing = 10
        statsContainerStack.translatesAutoresizingMaskIntoConstraints = false
        statsContainerView.addSubview(statsContainerStack)
        fileContainerView.addSubview(fileStack)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(titleRow)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(statusContainerView)
        contentStack.addArrangedSubview(statsContainerView)
        contentStack.addArrangedSubview(fileContainerView)
        contentScrollView.addSubview(contentStack)

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
            cardView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: 0.88),

            footerContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            footerContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            footerContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            footerContainerView.heightAnchor.constraint(equalToConstant: 36),

            closeButton.centerXAnchor.constraint(equalTo: footerContainerView.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: footerContainerView.centerYAnchor),

            contentScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            contentScrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            contentScrollView.bottomAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: -12),

            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor),

            statusIconView.leadingAnchor.constraint(equalTo: statusContainerView.leadingAnchor, constant: 14),
            statusIconView.centerYAnchor.constraint(equalTo: statusContainerView.centerYAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 24),
            statusIconView.heightAnchor.constraint(equalToConstant: 24),

            statusTitleLabel.leadingAnchor.constraint(equalTo: statusIconView.trailingAnchor, constant: 12),
            statusTitleLabel.trailingAnchor.constraint(equalTo: statusContainerView.trailingAnchor, constant: -14),
            statusTitleLabel.topAnchor.constraint(equalTo: statusContainerView.topAnchor, constant: 10),

            statusLabel.leadingAnchor.constraint(equalTo: statusTitleLabel.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: statusTitleLabel.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: statusTitleLabel.bottomAnchor, constant: 2),
            statusLabel.bottomAnchor.constraint(equalTo: statusContainerView.bottomAnchor, constant: -10),

            statsContainerStack.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor, constant: 12),
            statsContainerStack.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor, constant: -12),
            statsContainerStack.topAnchor.constraint(equalTo: statsContainerView.topAnchor, constant: 12),
            statsContainerStack.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor, constant: -12),

            mapInteractionLockStack.leadingAnchor.constraint(equalTo: mapInteractionLockContainerView.leadingAnchor, constant: 12),
            mapInteractionLockStack.trailingAnchor.constraint(equalTo: mapInteractionLockContainerView.trailingAnchor, constant: -12),
            mapInteractionLockStack.topAnchor.constraint(equalTo: mapInteractionLockContainerView.topAnchor, constant: 12),
            mapInteractionLockStack.bottomAnchor.constraint(equalTo: mapInteractionLockContainerView.bottomAnchor, constant: -12),

            fileStack.leadingAnchor.constraint(equalTo: fileContainerView.leadingAnchor, constant: 12),
            fileStack.trailingAnchor.constraint(equalTo: fileContainerView.trailingAnchor, constant: -12),
            fileStack.topAnchor.constraint(equalTo: fileContainerView.topAnchor, constant: 12),
            fileStack.bottomAnchor.constraint(equalTo: fileContainerView.bottomAnchor, constant: -12)
        ])

        refreshContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The sheet reflects state owned by ViewController, so a lightweight timer keeps
        // the controls and live stats accurate while the overlay is visible.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshContent()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshContent() {
        // Rebuild the visible state from the latest providers each time rather than
        // caching button titles or visibility locally. This keeps the overlay in sync
        // with imported tracks, recording state, and save/discard availability.
        let isRecording = isRecordingProvider()
        let hasRecording = hasRecordingProvider()
        let hasSavableRecording = hasSavableRecordingProvider()
        let hasImportedGPX = hasImportedGPXProvider()
        let canSaveImportedGPX = canSaveImportedGPXProvider()
        let isMapInteractionLocked = isMapInteractionLockedProvider()

        if isRecording {
            statusLabel.text = "Currently recording a live GPX track."
            statusLabel.textColor = .label
            statusIconView.image = UIImage(systemName: "play.circle.fill")
            statusIconView.tintColor = .systemRed
            statusContainerView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
            statusContainerView.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.25).cgColor
        } else if hasRecording {
            statusLabel.text = "A recording is ready to resume, save, or discard."
            statusLabel.textColor = .label
            statusIconView.image = UIImage(systemName: "pause.circle.fill")
            statusIconView.tintColor = .systemBlue
            statusContainerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            statusContainerView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
        } else if hasImportedGPX {
            statusLabel.text = "An imported GPX track is currently shown on the map."
            statusLabel.textColor = .label
            statusIconView.image = UIImage(systemName: "point.topleft.down.curvedto.point.bottomright.up")
            statusIconView.tintColor = .systemGreen
            statusContainerView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)
            statusContainerView.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.25).cgColor
        } else {
            statusLabel.text = "No active recording. Start a new GPX track or import one from Files."
            statusLabel.textColor = .label
            statusIconView.image = UIImage(systemName: "play.circle.fill")
            statusIconView.tintColor = .secondaryLabel
            statusContainerView.backgroundColor = UIColor.systemGray6
            statusContainerView.layer.borderColor = UIColor.separator.cgColor
        }

        // Keep the gesture lock visible at all times so the user can see and change
        // the recording preference before starting a track.
        mapInteractionLockContainerView.isHidden = false
        mapInteractionLockSwitch.isOn = isMapInteractionLocked
        mapInteractionLockSwitch.isEnabled = true

        primaryRecordingButton.configuration = recordingButtonConfiguration(
            title: hasRecording ? "Resume" : "Start",
            systemImageName: "play.circle.fill",
            tintColor: .systemBlue
        )
        stopRecordingButton.configuration = recordingButtonConfiguration(
            title: "Stop",
            systemImageName: "stop.fill",
            tintColor: .systemRed
        )
        saveButton.configuration = recordingButtonConfiguration(
            title: "Save",
            systemImageName: "square.and.arrow.down.fill",
            tintColor: .systemBlue
        )
        discardButton.configuration = recordingButtonConfiguration(
            title: "Discard",
            systemImageName: "trash.fill",
            tintColor: .systemRed
        )
        primaryRecordingButton.isEnabled = !isRecording
        stopRecordingButton.isEnabled = isRecording
        saveButton.isEnabled = hasRecording && !isRecording && hasSavableRecording
        discardButton.isEnabled = hasRecording && !isRecording
        setRecordingButtonAlpha(primaryRecordingButton)
        setRecordingButtonAlpha(stopRecordingButton)
        setRecordingButtonAlpha(saveButton)
        setRecordingButtonAlpha(discardButton)
        saveImportedButton.configuration = buttonConfiguration(title: "Save Imported GPX", color: .systemBlue)
        saveImportedButton.isHidden = !hasImportedGPX || !canSaveImportedGPX
        clearImportedButton.configuration = buttonConfiguration(title: "Clear Imported GPX", color: .systemRed)
        clearImportedButton.isHidden = !hasImportedGPX

        if let summary = summaryProvider(), hasRecording {
            statsStack.isHidden = false
            distanceValueLabel.text = formattedDistance(summary.distanceMeters)
            timeValueLabel.text = formattedDuration(summary.duration)
            ascentValueLabel.text = formattedElevation(summary.ascentMeters)
            descentValueLabel.text = formattedElevation(summary.descentMeters)
            elevationValueLabel.text = summary.currentElevationMeters.map(formattedElevation) ?? "Unavailable"
            accuracyValueLabel.text = accuracyProvider()
        } else {
            statsStack.isHidden = true
        }
    }

    func syncMapInteractionLockState(_ isLocked: Bool) {
        mapInteractionLockContainerView.isHidden = false
        mapInteractionLockSwitch.isOn = isLocked
        refreshContent()
    }

    @objc private func mapInteractionLockSwitchChanged(_ sender: UISwitch) {
        mapInteractionLockChangeHandler(sender.isOn)
        refreshContent()
    }

    private func setRecordingButtonAlpha(_ button: UIButton) {
        button.alpha = button.isEnabled ? 1.0 : 0.45
    }

    private func recordingButtonConfiguration(title: String, systemImageName: String, tintColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = tintColor.withAlphaComponent(0.12)
        configuration.baseForegroundColor = tintColor
        configuration.cornerStyle = .medium
        configuration.image = UIImage(systemName: systemImageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        configuration.imagePlacement = .top
        configuration.imagePadding = 3
        configuration.titleAlignment = .center
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: tintColor
            ])
        )
        return configuration
    }

    private func showDiscardConfirmation() {
        let overlay = ConfirmationOverlayViewController(
            title: "Confirm Discard?",
            message: "Delete this recording?",
            confirmTitle: "Yes",
            confirmTintColor: .systemRed,
            confirmHandler: { [weak self] in
                guard let self else { return }
                self.discardHandler()
                self.refreshContent()
            },
            cancelHandler: {}
        )
        present(overlay, animated: true)
    }

    private func metricsRow(
        leftTitle: String,
        leftValueLabel: UILabel,
        rightTitle: String,
        rightValueLabel: UILabel
    ) -> UIStackView {
        // GPX stats are expressed as paired cells so the same compact "two across"
        // layout can be reused for both live and saved-recording summaries.
        let row = UIStackView(arrangedSubviews: [
            metricCell(title: leftTitle, valueLabel: leftValueLabel),
            metricCell(title: rightTitle, valueLabel: rightValueLabel)
        ])
        row.axis = .horizontal
        row.spacing = 0
        row.distribution = .fillEqually
        return row
    }

    private func sectionContainerView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.separator.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        return containerView
    }

    private func metricCell(title: String, valueLabel: UILabel) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 0
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.black.cgColor

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .right
        titleLabel.numberOfLines = 1

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 15, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 1

        let cellStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        cellStack.axis = .vertical
        cellStack.spacing = 4
        cellStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cellStack)

        NSLayoutConstraint.activate([
            cellStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            cellStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            cellStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            cellStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            container.heightAnchor.constraint(equalToConstant: 52)
        ])

        return container
    }

    private func formattedDistance(_ distanceMeters: CLLocationDistance) -> String {
        distanceFormatter(distanceMeters)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formattedElevation(_ elevationMeters: Double) -> String {
        elevationFormatter(elevationMeters)
    }

    private func makeButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .center
        button.tintColor = color
        button.configuration = buttonConfiguration(title: title, color: color)
        return button
    }

    private func buttonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        makeOverlayPlainButtonConfiguration(title: title, foregroundColor: color)
    }

    private func prominentButtonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        makeOverlayButtonConfiguration(
            title: title,
            foregroundColor: .white,
            backgroundColor: color
        )
    }

    @objc private func dismissOverlay() {
        dismiss(animated: true)
    }
}
