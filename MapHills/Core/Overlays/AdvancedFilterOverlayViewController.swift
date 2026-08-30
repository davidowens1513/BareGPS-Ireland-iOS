//
//  PrimaryOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit

final class AdvancedFilterOverlayViewController: UIViewController {
    private let classificationOptions: [MenuOption]
    private var selectedClassificationCodes: Set<String>
    private var minimumHeightMeters: Double?
    private var maximumHeightMeters: Double?
    private var combinationMode: AdvancedFilterCombinationMode
    private var savedPresets: [AdvancedHillFilterPreset]
    private let applyHandler: (AdvancedHillFilter) -> Void
    private let savePresetHandler: (AdvancedHillFilterPreset) -> Void
    private let deletePresetHandler: (String) -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let contentScrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let classificationStackView = UIStackView()
    private let presetsStackView = UIStackView()
    private let combinationModeControl = UISegmentedControl(items: AdvancedFilterCombinationMode.allCases.map(\.title))
    private let minimumHeightField = UITextField()
    private let maximumHeightField = UITextField()
    private let summaryLabel = UILabel()

    init(
        classificationOptions: [MenuOption],
        currentFilter: AdvancedHillFilter,
        savedPresets: [AdvancedHillFilterPreset],
        applyHandler: @escaping (AdvancedHillFilter) -> Void,
        savePresetHandler: @escaping (AdvancedHillFilterPreset) -> Void,
        deletePresetHandler: @escaping (String) -> Void
    ) {
        self.classificationOptions = classificationOptions
        self.selectedClassificationCodes = Set(currentFilter.selectedClassificationCodes)
        self.minimumHeightMeters = currentFilter.minimumHeightMeters
        self.maximumHeightMeters = currentFilter.maximumHeightMeters
        self.combinationMode = currentFilter.combinationMode
        self.savedPresets = savedPresets
        self.applyHandler = applyHandler
        self.savePresetHandler = savePresetHandler
        self.deletePresetHandler = deletePresetHandler
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

        let titleLabel = makeOverlayTitleLabel("Advanced Filter")
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let logicHeaderLabel = sectionHeaderLabel(text: "Logic")
        styleSegmentedControl(combinationModeControl)
        combinationModeControl.selectedSegmentIndex = combinationMode.rawValue
        combinationModeControl.addTarget(self, action: #selector(combinationModeChanged(_:)), for: .valueChanged)

        let heightsHeaderLabel = sectionHeaderLabel(text: "Height Range (m)")
        configureHeightField(minimumHeightField, placeholder: "Min")
        configureHeightField(maximumHeightField, placeholder: "Max")
        minimumHeightField.text = minimumHeightMeters.map { String(Int($0.rounded())) }
        maximumHeightField.text = maximumHeightMeters.map { String(Int($0.rounded())) }

        let heightsRow = UIStackView(arrangedSubviews: [minimumHeightField, maximumHeightField])
        heightsRow.axis = .horizontal
        heightsRow.spacing = 12
        heightsRow.distribution = .fillEqually

        let classificationsHeaderLabel = sectionHeaderLabel(text: "Classifications")
        classificationStackView.axis = .vertical
        classificationStackView.spacing = 10

        let presetsHeaderLabel = sectionHeaderLabel(text: "Saved Schemes")
        presetsStackView.axis = .vertical
        presetsStackView.spacing = 10

        let savePresetButton = UIButton(type: .system)
        savePresetButton.configuration = makeOverlayPlainButtonConfiguration(title: "Save Scheme")
        savePresetButton.contentHorizontalAlignment = .leading
        savePresetButton.addTarget(self, action: #selector(promptToSavePreset), for: .touchUpInside)

        let applyButton = UIButton(type: .system)
        applyButton.configuration = prominentButtonConfiguration(title: "Apply Advanced Filter", color: .systemBlue)
        applyButton.addTarget(self, action: #selector(applyAdvancedFilter), for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.configuration = makeOverlayPlainButtonConfiguration(title: "Done")
        doneButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        summaryLabel.font = OverlayChromeStyle.bodyFont
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 0

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(titleRow)
        contentStack.addArrangedSubview(makeSectionContainer(arrangedSubviews: [logicHeaderLabel, combinationModeControl]))
        contentStack.addArrangedSubview(makeSectionContainer(arrangedSubviews: [heightsHeaderLabel, heightsRow]))
        contentStack.addArrangedSubview(makeSectionContainer(arrangedSubviews: [classificationsHeaderLabel, classificationStackView]))
        contentStack.addArrangedSubview(makeSectionContainer(arrangedSubviews: [presetsHeaderLabel, presetsStackView, savePresetButton]))
        contentStack.addArrangedSubview(summaryLabel)
        contentStack.addArrangedSubview(applyButton)
        contentStack.addArrangedSubview(doneButton)

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
            cardView.widthAnchor.constraint(equalToConstant: 340),
            cardView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: 0.84),

            contentScrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentScrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentScrollView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            contentStack.leadingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentScrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: contentScrollView.frameLayoutGuide.widthAnchor)
        ])

        rebuildClassificationRows()
        rebuildPresetRows()
        updateSummary()
    }

    @objc private func dismissOverlay() {
        dismiss(animated: true)
    }

    @objc private func combinationModeChanged(_ sender: UISegmentedControl) {
        guard let mode = AdvancedFilterCombinationMode(rawValue: sender.selectedSegmentIndex) else { return }
        combinationMode = mode
        updateSummary()
    }

    @objc private func applyAdvancedFilter() {
        updateHeightsFromFields()
        applyHandler(currentFilter())
        dismiss(animated: true)
    }

    @objc private func promptToSavePreset() {
        updateHeightsFromFields()

        let overlay = TextInputOverlayViewController(
            title: "Save Filter Scheme",
            message: "Choose a name for this advanced filter.",
            placeholder: "Scheme name",
            confirmTitle: "Save"
        ) { [weak self] enteredName in
            guard let self else { return }
            let presetName = enteredName.isEmpty ? "Advanced Filter" : enteredName
            let preset = AdvancedHillFilterPreset(
                id: UUID().uuidString,
                name: presetName,
                filter: self.currentFilter()
            )
            self.savedPresets.append(preset)
            self.savedPresets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.savePresetHandler(preset)
            self.rebuildPresetRows()
        }
        present(overlay, animated: true)
    }

    @objc private func classificationButtonTapped(_ sender: UIButton) {
        guard classificationOptions.indices.contains(sender.tag) else { return }
        let code = classificationOptions[sender.tag].id
        if selectedClassificationCodes.contains(code) {
            selectedClassificationCodes.remove(code)
        } else {
            selectedClassificationCodes.insert(code)
        }
        rebuildClassificationRows()
        updateSummary()
    }

    @objc private func minimumHeightChanged(_ sender: UITextField) {
        minimumHeightMeters = parsedHeight(from: sender.text)
        updateSummary()
    }

    @objc private func maximumHeightChanged(_ sender: UITextField) {
        maximumHeightMeters = parsedHeight(from: sender.text)
        updateSummary()
    }

    private func rebuildClassificationRows() {
        classificationStackView.arrangedSubviews.forEach { view in
            classificationStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, option) in classificationOptions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.contentHorizontalAlignment = .leading
            button.tintColor = .systemBlue
            button.configuration = checkboxConfiguration(
                title: option.title,
                countText: option.countText,
                isSelected: selectedClassificationCodes.contains(option.id)
            )
            button.addTarget(self, action: #selector(classificationButtonTapped(_:)), for: .touchUpInside)
            classificationStackView.addArrangedSubview(button)
        }
    }

    private func rebuildPresetRows() {
        presetsStackView.arrangedSubviews.forEach { view in
            presetsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !savedPresets.isEmpty else {
            let emptyLabel = UILabel()
            emptyLabel.text = "No saved schemes yet."
            emptyLabel.font = OverlayChromeStyle.bodyFont
            emptyLabel.textColor = .secondaryLabel
            presetsStackView.addArrangedSubview(emptyLabel)
            return
        }

        for preset in savedPresets {
            let nameLabel = UILabel()
            nameLabel.text = preset.name
            nameLabel.font = OverlayChromeStyle.sectionTitleFont
            nameLabel.textColor = .label

            let summaryLabel = UILabel()
            summaryLabel.text = summaryText(for: preset.filter)
            summaryLabel.font = OverlayChromeStyle.supportingFont
            summaryLabel.textColor = .secondaryLabel
            summaryLabel.numberOfLines = 0

            let applyButton = UIButton(type: .system)
            applyButton.configuration = buttonConfiguration(title: "Apply", color: .systemBlue)
            applyButton.addAction(UIAction { _ in
                self.load(filter: preset.filter)
                self.applyHandler(preset.filter)
                self.dismiss(animated: true)
            }, for: .touchUpInside)

            let deleteButton = UIButton(type: .system)
            deleteButton.configuration = buttonConfiguration(title: "Delete", color: .systemRed)
            deleteButton.addAction(UIAction { _ in
                self.savedPresets.removeAll { $0.id == preset.id }
                self.deletePresetHandler(preset.id)
                self.rebuildPresetRows()
            }, for: .touchUpInside)

            let buttonRow = UIStackView(arrangedSubviews: [applyButton, deleteButton])
            buttonRow.axis = .horizontal
            buttonRow.spacing = 12
            buttonRow.distribution = .fillEqually

            let presetStack = UIStackView(arrangedSubviews: [nameLabel, summaryLabel, buttonRow])
            presetStack.axis = .vertical
            presetStack.spacing = 6

            let container = makeSectionContainer(arrangedSubviews: [presetStack])
            presetsStackView.addArrangedSubview(container)
        }
    }

    private func load(filter: AdvancedHillFilter) {
        selectedClassificationCodes = Set(filter.selectedClassificationCodes)
        minimumHeightMeters = filter.minimumHeightMeters
        maximumHeightMeters = filter.maximumHeightMeters
        combinationMode = filter.combinationMode
        combinationModeControl.selectedSegmentIndex = combinationMode.rawValue
        minimumHeightField.text = minimumHeightMeters.map { String(Int($0.rounded())) }
        maximumHeightField.text = maximumHeightMeters.map { String(Int($0.rounded())) }
        rebuildClassificationRows()
        updateSummary()
    }

    private func currentFilter() -> AdvancedHillFilter {
        updateHeightsFromFields()
        return AdvancedHillFilter(
            selectedClassificationCodes: Array(selectedClassificationCodes).sorted(),
            minimumHeightMeters: minimumHeightMeters,
            maximumHeightMeters: maximumHeightMeters,
            combinationMode: combinationMode
        )
    }

    private func updateHeightsFromFields() {
        minimumHeightMeters = parsedHeight(from: minimumHeightField.text)
        maximumHeightMeters = parsedHeight(from: maximumHeightField.text)
    }

    private func updateSummary() {
        summaryLabel.text = summaryText(for: currentFilter())
    }

    private func summaryText(for filter: AdvancedHillFilter) -> String {
        guard !filter.isEmpty else {
            return "No advanced conditions set. All hills will be shown."
        }

        var parts: [String] = []
        if !filter.selectedClassificationCodes.isEmpty {
            let names = classificationOptions
                .filter { filter.selectedClassificationCodes.contains($0.id) }
                .map(\.title)
                .sorted()
            parts.append(names.joined(separator: ", "))
        }

        let minimumHeight = filter.normalizedMinimumHeightMeters
        let maximumHeight = filter.normalizedMaximumHeightMeters
        switch (minimumHeight, maximumHeight) {
        case let (.some(minimumHeight), .some(maximumHeight)):
            parts.append("\(Int(minimumHeight.rounded()))-\(Int(maximumHeight.rounded()))m")
        case let (.some(minimumHeight), nil):
            parts.append("\(Int(minimumHeight.rounded()))m and up")
        case let (nil, .some(maximumHeight)):
            parts.append("up to \(Int(maximumHeight.rounded()))m")
        case (nil, nil):
            break
        }

        let logicPrefix = filter.combinationMode == .matchAll ? "Match all" : "Match any"
        return "\(logicPrefix): \(parts.joined(separator: " • "))"
    }

    private func parsedHeight(from text: String?) -> Double? {
        guard let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedText.isEmpty else {
            return nil
        }
        return Double(trimmedText)
    }

    private func configureHeightField(_ textField: UITextField, placeholder: String) {
        textField.borderStyle = .roundedRect
        textField.keyboardType = .decimalPad
        textField.placeholder = placeholder
        textField.addTarget(self, action: #selector(minimumHeightChanged(_:)), for: .editingChanged)
        if placeholder == "Max" {
            textField.removeTarget(self, action: #selector(minimumHeightChanged(_:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(maximumHeightChanged(_:)), for: .editingChanged)
        }
    }

    private func sectionHeaderLabel(text: String) -> UILabel {
        return makeOverlaySectionTitleLabel(text)
    }

    private func makeSectionContainer(arrangedSubviews: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = OverlayChromeStyle.sectionCornerRadius
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.separator.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14)
        ])

        return container
    }

    private func styleSegmentedControl(_ control: UISegmentedControl) {
        control.selectedSegmentTintColor = .systemBlue
        control.backgroundColor = UIColor.secondarySystemBackground
        control.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.label
        ], for: .normal)
        control.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white
        ], for: .selected)
    }

    private func checkboxConfiguration(title: String, countText: String?, isSelected: Bool) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: isSelected ? "checkmark.square.fill" : "square")
        configuration.imagePadding = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)

        var attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.label
            ])
        )
        if let countText {
            attributedTitle.append(
                AttributedString(
                    " \(countText)",
                    attributes: AttributeContainer([
                        .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: UIColor.secondaryLabel
                    ])
                )
            )
        }
        configuration.attributedTitle = attributedTitle
        return configuration
    }

    private func buttonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        makeOverlayPlainButtonConfiguration(title: title, foregroundColor: color)
    }

    private func prominentButtonConfiguration(title: String, color: UIColor) -> UIButton.Configuration {
        makeOverlayButtonConfiguration(title: title, foregroundColor: .white, backgroundColor: color)
    }
}
