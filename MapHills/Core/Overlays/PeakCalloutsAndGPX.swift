//
//  HillCalloutsAndGPX.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation
import MapLibre

private enum CalloutLayoutMetrics {
    static let belowAnchorGap: CGFloat = 28
    static let automaticVerticalGap: CGFloat = 56
    static let leftRailReservedWidth: CGFloat = 72
    static let rightRailReservedWidth: CGFloat = 84
}

final class HillCalloutView: UIView, MLNCalloutView {
    enum PlacementMode {
        case automatic
        case belowAnchor
    }

    var representedObject: MLNAnnotation
    var leftAccessoryView = UIView(frame: .zero)
    var rightAccessoryView = UIView(frame: .zero)
    weak var delegate: MLNCalloutViewDelegate?

    private let titleLabel = UILabel()
    private let alternateNameLabel = UILabel()
    private let rangeLabel = UILabel()
    private let classificationLabel = UILabel()
    private let metricsLabel = UILabel()
    private let gridReferenceLabel = UILabel()
    private let primaryActionButton = UIButton(type: .system)
    private let secondaryActionButton = UIButton(type: .system)
    private let tertiaryActionButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let footerStack = UIStackView()
    private let containerView = UIView()
    private let primaryActionHandler: () -> Void
    private let secondaryActionHandler: (() -> Void)?
    private let tertiaryActionHandler: (() -> Void)?
    private let startPlaceActions: [CalloutButtonAction]
    private let placementMode: PlacementMode
    private var startPlaceButtons: [UIButton] = []

    var isAnchoredToAnnotation: Bool {
        true
    }

    var dismissesAutomatically: Bool {
        true
    }

    init(
        annotation: MLNAnnotation,
        title: String,
        alternateName: String?,
        rangeName: String?,
        classification: String?,
        metrics: String,
        gridReference: String?,
        primaryActionTitle: String,
        primaryActionHandler: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        secondaryActionHandler: (() -> Void)? = nil,
        tertiaryActionTitle: String? = nil,
        tertiaryActionHandler: (() -> Void)? = nil,
        startPlaceActions: [CalloutButtonAction] = [],
        placementMode: PlacementMode = .automatic
    ) {
        self.representedObject = annotation
        self.primaryActionHandler = primaryActionHandler
        self.secondaryActionHandler = secondaryActionHandler
        self.tertiaryActionHandler = tertiaryActionHandler
        self.startPlaceActions = startPlaceActions
        self.placementMode = placementMode
        super.init(frame: .zero)

        backgroundColor = .clear

        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 14
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.18
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        containerView.addSubview(scrollView)

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = title
        titleLabel.accessibilityIdentifier = "hillCalloutTitleLabel"

        let hillMarkerIconView = UIImageView(
            image: UIImage(
                systemName: "triangle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            )?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        )
        hillMarkerIconView.translatesAutoresizingMaskIntoConstraints = false
        hillMarkerIconView.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            hillMarkerIconView.widthAnchor.constraint(equalToConstant: 24),
            hillMarkerIconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        let trailingSpacer = UIView()
        trailingSpacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            trailingSpacer.widthAnchor.constraint(equalToConstant: 24),
            trailingSpacer.heightAnchor.constraint(equalToConstant: 24)
        ])

        titleLabel.textAlignment = .center
        let titleRow = UIStackView(arrangedSubviews: [hillMarkerIconView, titleLabel, trailingSpacer])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 10
        titleRow.setContentCompressionResistancePriority(.required, for: .vertical)
        titleRow.setContentHuggingPriority(.required, for: .vertical)

        alternateNameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        alternateNameLabel.textColor = .secondaryLabel
        alternateNameLabel.numberOfLines = 0
        alternateNameLabel.text = alternateName.map { "(\($0))" }
        alternateNameLabel.isHidden = alternateName == nil
        alternateNameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        alternateNameLabel.setContentHuggingPriority(.required, for: .vertical)

        rangeLabel.font = .systemFont(ofSize: 14, weight: .black)
        rangeLabel.textColor = .label
        rangeLabel.numberOfLines = 0
        rangeLabel.text = rangeName
        rangeLabel.isHidden = rangeName == nil
        rangeLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        rangeLabel.setContentHuggingPriority(.required, for: .vertical)

        classificationLabel.font = .systemFont(ofSize: 13, weight: .bold)
        classificationLabel.textColor = .secondaryLabel
        classificationLabel.numberOfLines = 0
        classificationLabel.textAlignment = .left
        classificationLabel.text = classification
        classificationLabel.isHidden = classification == nil
        classificationLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        classificationLabel.setContentHuggingPriority(.required, for: .vertical)

        metricsLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        metricsLabel.textColor = .secondaryLabel
        metricsLabel.numberOfLines = 0
        metricsLabel.textAlignment = .left
        metricsLabel.text = metrics
        metricsLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        metricsLabel.setContentHuggingPriority(.required, for: .vertical)

        // Keep the grid ref on its own row so it survives narrower callout layouts.
        gridReferenceLabel.font = .systemFont(ofSize: 14, weight: .black)
        gridReferenceLabel.textColor = .label
        gridReferenceLabel.numberOfLines = 1
        gridReferenceLabel.textAlignment = .left
        gridReferenceLabel.adjustsFontSizeToFitWidth = true
        gridReferenceLabel.minimumScaleFactor = 0.8
        gridReferenceLabel.text = gridReference
        gridReferenceLabel.isHidden = gridReference == nil
        gridReferenceLabel.accessibilityIdentifier = "hillCalloutGridReferenceLabel"
        gridReferenceLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        gridReferenceLabel.setContentHuggingPriority(.required, for: .vertical)

        primaryActionButton.setTitle(primaryActionTitle, for: .normal)
        primaryActionButton.configuration = calloutActionButtonConfiguration(
            title: primaryActionTitle,
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
        )
        primaryActionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .black)
        primaryActionButton.titleLabel?.numberOfLines = 1
        primaryActionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        primaryActionButton.titleLabel?.minimumScaleFactor = 0.8
        primaryActionButton.accessibilityIdentifier = "hillCalloutPrimaryActionButton"
        primaryActionButton.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)

        secondaryActionButton.setTitle(secondaryActionTitle, for: .normal)
        secondaryActionButton.configuration = calloutActionButtonConfiguration(
            title: secondaryActionTitle ?? "",
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
        )
        secondaryActionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .black)
        secondaryActionButton.titleLabel?.numberOfLines = 1
        secondaryActionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        secondaryActionButton.titleLabel?.minimumScaleFactor = 0.8
        secondaryActionButton.accessibilityIdentifier = "hillCalloutSecondaryActionButton"
        secondaryActionButton.addTarget(self, action: #selector(secondaryActionTapped), for: .touchUpInside)
        secondaryActionButton.isHidden = secondaryActionTitle == nil || secondaryActionHandler == nil

        if let mountainViewsImage = UIImage(named: ActiveRegion.current.externalDataProviderAssetName) {
            tertiaryActionButton.configuration = calloutImageButtonConfiguration(
                image: mountainViewsImage,
                backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
            )
        } else {
            tertiaryActionButton.setTitle(tertiaryActionTitle, for: .normal)
            tertiaryActionButton.configuration = calloutActionButtonConfiguration(
                title: tertiaryActionTitle ?? "",
                foregroundColor: .systemBlue,
                backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
            )
        }
        tertiaryActionButton.titleLabel?.numberOfLines = 1
        tertiaryActionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        tertiaryActionButton.titleLabel?.minimumScaleFactor = 0.8
        tertiaryActionButton.imageView?.contentMode = .scaleAspectFit
        tertiaryActionButton.accessibilityIdentifier = "hillCalloutTertiaryActionButton"
        tertiaryActionButton.addTarget(self, action: #selector(tertiaryActionTapped), for: .touchUpInside)
        tertiaryActionButton.isHidden = tertiaryActionTitle == nil || tertiaryActionHandler == nil

        footerStack.axis = .horizontal
        footerStack.alignment = .fill
        footerStack.distribution = .fillEqually
        footerStack.spacing = 8
        footerStack.setContentCompressionResistancePriority(.required, for: .vertical)
        footerStack.setContentHuggingPriority(.required, for: .vertical)
        if !secondaryActionButton.isHidden {
            footerStack.addArrangedSubview(secondaryActionButton)
        }
        footerStack.addArrangedSubview(primaryActionButton)
        if !tertiaryActionButton.isHidden {
            footerStack.addArrangedSubview(tertiaryActionButton)
        }

        contentStack.axis = .vertical
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(titleRow)
        contentStack.addArrangedSubview(alternateNameLabel)
        contentStack.addArrangedSubview(rangeLabel)
        contentStack.addArrangedSubview(classificationLabel)
        let dataSourceLabel = UILabel()
        dataSourceLabel.font = .systemFont(ofSize: 13, weight: .regular)
        dataSourceLabel.textColor = .secondaryLabel
        dataSourceLabel.numberOfLines = 0
        dataSourceLabel.textAlignment = .left
        dataSourceLabel.text = "Data: Hills: MountainViews.ie"
        dataSourceLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        dataSourceLabel.setContentHuggingPriority(.required, for: .vertical)

        contentStack.addArrangedSubview(metricsLabel)
        contentStack.addArrangedSubview(gridReferenceLabel)
        contentStack.addArrangedSubview(dataSourceLabel)
        contentStack.addArrangedSubview(footerStack)

        if !startPlaceActions.isEmpty {
            let separatorView = UIView()
            separatorView.translatesAutoresizingMaskIntoConstraints = false
            separatorView.backgroundColor = .separator
            NSLayoutConstraint.activate([
                separatorView.heightAnchor.constraint(equalToConstant: 1)
            ])

            let startPlaceIconView = UIImageView(
                image: UIImage(
                    systemName: "figure.walk.circle.fill",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
                )?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            )
            startPlaceIconView.contentMode = .scaleAspectFit
            startPlaceIconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                startPlaceIconView.widthAnchor.constraint(equalToConstant: 24),
                startPlaceIconView.heightAnchor.constraint(equalToConstant: 24)
            ])

            let iconRow = UIStackView(arrangedSubviews: [UIView(), startPlaceIconView, UIView()])
            iconRow.axis = .horizontal
            iconRow.alignment = .center
            iconRow.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

            let startPlaceButtonSection = UIStackView()
            startPlaceButtonSection.axis = .vertical
            startPlaceButtonSection.alignment = .fill
            startPlaceButtonSection.distribution = .fillEqually
            startPlaceButtonSection.spacing = 6
            startPlaceButtonSection.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            startPlaceButtonSection.setContentHuggingPriority(.defaultLow, for: .vertical)

            let actionGroups = stride(from: 0, to: startPlaceActions.count, by: 2).map { startIndex in
                Array(startPlaceActions[startIndex..<min(startIndex + 2, startPlaceActions.count)])
            }

            for actionGroup in actionGroups {
                let row = UIStackView()
                row.axis = .horizontal
                row.alignment = .fill
                row.distribution = .fillEqually
                row.spacing = 8

                for action in actionGroup {
                    let button = UIButton(type: .system)
                    let actionTintColor = action.tintColor ?? .systemGreen
                    button.configuration = calloutActionButtonConfiguration(
                        title: truncatedStartPlaceButtonTitle(action.title),
                        foregroundColor: actionTintColor,
                        backgroundColor: actionTintColor.withAlphaComponent(0.10)
                    )
                    button.contentHorizontalAlignment = .leading
                    button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
                    button.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
                    button.titleLabel?.adjustsFontSizeToFitWidth = true
                button.titleLabel?.minimumScaleFactor = 0.7
                button.titleLabel?.numberOfLines = 1
                button.titleLabel?.lineBreakMode = .byTruncatingTail
                button.translatesAutoresizingMaskIntoConstraints = false
                button.heightAnchor.constraint(equalToConstant: 26).isActive = true
                button.tag = startPlaceButtons.count
                button.addTarget(self, action: #selector(startPlaceButtonTapped(_:)), for: .touchUpInside)
                row.addArrangedSubview(button)
                startPlaceButtons.append(button)
                }

                while row.arrangedSubviews.count < 2 {
                    let spacer = UIView()
                    row.addArrangedSubview(spacer)
                }

                startPlaceButtonSection.addArrangedSubview(row)
            }

            contentStack.addArrangedSubview(separatorView)
            contentStack.addArrangedSubview(iconRow)
            contentStack.addArrangedSubview(startPlaceButtonSection)
            contentStack.setCustomSpacing(4, after: iconRow)
        }

        contentStack.setCustomSpacing(2, after: titleRow)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -28)
        ])

        for button in startPlaceButtons {
            button.configuration = compactStartPlaceButtonConfiguration(from: button.configuration)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func calloutActionButtonConfiguration(
        title: String,
        foregroundColor: UIColor,
        backgroundColor: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = foregroundColor
        configuration.background.backgroundColor = backgroundColor
        configuration.background.cornerRadius = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16, weight: .black)
            return outgoing
        }
        return configuration
    }

    private func calloutImageButtonConfiguration(
        image: UIImage,
        backgroundColor: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.image = resizedCalloutButtonImage(from: image, maxDimension: 75)
        configuration.imagePlacement = .all
        configuration.background.backgroundColor = backgroundColor
        configuration.background.cornerRadius = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
        return configuration
    }

    private func compactStartPlaceButtonConfiguration(from configuration: UIButton.Configuration?) -> UIButton.Configuration? {
        guard var configuration else { return nil }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 11, weight: .bold)
            return outgoing
        }
        return configuration
    }

    private func truncatedStartPlaceButtonTitle(_ title: String, maximumCharacterCount: Int = 15) -> String {
        guard title.count > maximumCharacterCount else { return title }
        let prefixCount = max(1, maximumCharacterCount - 3)
        return String(title.prefix(prefixCount)) + "..."
    }

    private func resizedCalloutButtonImage(from image: UIImage, maxDimension: CGFloat) -> UIImage {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return image }

        let scale = min(maxDimension / imageSize.width, maxDimension / imageSize.height)
        guard scale < 1 else { return image }

        let targetSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func presentCallout(
        from rect: CGRect,
        in view: UIView,
        constrainedTo constrainedRect: CGRect,
        animated: Bool
    ) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)

        let availableWidth = min(constrainedRect.width - 24, 280)
        let preferredWidth = max(220, availableWidth)
        let contentWidth = preferredWidth - 28
        let fittedContentHeight = ceil(contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
        let horizontalGap: CGFloat = 18
        let minimumLeading = constrainedRect.minX + CalloutLayoutMetrics.leftRailReservedWidth
        let maximumLeading = constrainedRect.maxX - preferredWidth - CalloutLayoutMetrics.rightRailReservedWidth
        let centeredLeadingX = rect.midX - (preferredWidth / 2)
        let annotationIsOnLeftHalf = rect.midX < constrainedRect.midX
        let preferredLeadingX = annotationIsOnLeftHalf
            ? rect.maxX + horizontalGap
            : rect.minX - horizontalGap - preferredWidth
        let clampedLeadingX = min(max(preferredLeadingX, minimumLeading), maximumLeading)

        switch placementMode {
        case .automatic:
            let verticalGap: CGFloat = CalloutLayoutMetrics.automaticVerticalGap
            let maximumAvailableHeight = constrainedRect.height - 16
            let fittedHeight = min(maximumAvailableHeight, fittedContentHeight + 24 + 2)
            let availableBelow = constrainedRect.maxY - rect.maxY
            let requiredVerticalSpace = fittedHeight + verticalGap + 8
            let brandingReservedWidth: CGFloat = 176
            let brandingReservedHeight: CGFloat = 72
            let overlapsBrandingZone = clampedLeadingX < constrainedRect.minX + brandingReservedWidth
            let minimumTop = overlapsBrandingZone
                ? constrainedRect.minY + brandingReservedHeight
                : constrainedRect.minY + 8
            let usableAvailableAbove = rect.minY - minimumTop
            let opensAboveAnnotation =
                usableAvailableAbove >= requiredVerticalSpace ||
                (usableAvailableAbove > availableBelow && availableBelow < requiredVerticalSpace)

            var constraints = [
                widthAnchor.constraint(equalToConstant: preferredWidth),
                heightAnchor.constraint(equalToConstant: fittedHeight),
                leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: clampedLeadingX),
                topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: minimumTop),
                bottomAnchor.constraint(lessThanOrEqualTo: view.topAnchor, constant: constrainedRect.maxY - 8)
            ]

            if opensAboveAnnotation {
                constraints.append(bottomAnchor.constraint(equalTo: view.topAnchor, constant: rect.minY - verticalGap))
            } else {
                constraints.append(topAnchor.constraint(equalTo: view.topAnchor, constant: rect.maxY + verticalGap))
            }

            NSLayoutConstraint.activate(constraints)

        case .belowAnchor:
            let verticalGap: CGFloat = CalloutLayoutMetrics.belowAnchorGap
            let fixedTop = max(rect.maxY + verticalGap, constrainedRect.minY + 8)
            let maximumAvailableHeight = max(180, constrainedRect.maxY - fixedTop - 8)
            let fittedHeight = min(maximumAvailableHeight, fittedContentHeight + 24 + 2)
            let centeredClampedLeadingX = min(max(centeredLeadingX, minimumLeading), maximumLeading)

            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: preferredWidth),
                heightAnchor.constraint(equalToConstant: fittedHeight),
                leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: centeredClampedLeadingX),
                topAnchor.constraint(equalTo: view.topAnchor, constant: fixedTop)
            ])
        }

        view.layoutIfNeeded()

        if animated {
            alpha = 0
            transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.animate(withDuration: 0.2) {
                self.alpha = 1
                self.transform = .identity
            }
        }
    }

    func dismissCallout(animated: Bool) {
        let animations = {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 8)
        }

        let completion: (Bool) -> Void = { _ in
            self.removeFromSuperview()
            self.transform = .identity
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }

    func marginInsetsHintForPresentation(from rect: CGRect) -> UIEdgeInsets {
        UIEdgeInsets(top: -170, left: -28, bottom: -24, right: -28)
    }

    @objc private func primaryActionTapped() {
        primaryActionHandler()
    }

    @objc private func secondaryActionTapped() {
        secondaryActionHandler?()
    }

    @objc private func tertiaryActionTapped() {
        tertiaryActionHandler?()
    }

    @objc private func startPlaceButtonTapped(_ sender: UIButton) {
        guard startPlaceActions.indices.contains(sender.tag) else { return }
        startPlaceActions[sender.tag].handler()
    }
}

final class StartPlaceCalloutView: UIView, MLNCalloutView {
    enum PlacementMode {
        case automatic
        case belowAnchor
    }

    var representedObject: MLNAnnotation
    var leftAccessoryView = UIView(frame: .zero)
    var rightAccessoryView = UIView(frame: .zero)
    weak var delegate: MLNCalloutViewDelegate?
    var didRequestDismissal: (() -> Void)?

    private let containerView = UIView()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let directionsButton = UIButton(type: .system)
    private let googleDirectionsButton = UIButton(type: .system)
    private let mountainViewsStartPlaceButton = UIButton(type: .system)
    private let directionsHandler: () -> Void
    private let googleDirectionsHandler: () -> Void
    private let mountainViewsStartPlaceHandler: (() -> Void)?
    private let nearbyHillActions: [StartPlaceNearbyHillAction]
    private let walkSummaries: [StartPlaceWalkSummary]
    private let providerColor: UIColor
    private let placementMode: PlacementMode
    private var nearbyHillButtons: [UIButton] = []

    var isAnchoredToAnnotation: Bool {
        true
    }

    var dismissesAutomatically: Bool {
        true
    }

    init(
        annotation: MLNAnnotation,
        title: String,
        fullName: String,
        gridReference: String,
        height: String,
        status: String,
        parking: String,
        provider: StartPlaceProvider,
        providerColor: UIColor,
        walkSummaries: [StartPlaceWalkSummary],
        nearbyHillActions: [StartPlaceNearbyHillAction],
        directionsHandler: @escaping () -> Void,
        googleDirectionsHandler: @escaping () -> Void,
        mountainViewsStartPlaceHandler: (() -> Void)? = nil,
        placementMode: PlacementMode = .automatic
    ) {
        self.representedObject = annotation
        self.directionsHandler = directionsHandler
        self.googleDirectionsHandler = googleDirectionsHandler
        self.mountainViewsStartPlaceHandler = mountainViewsStartPlaceHandler
        self.nearbyHillActions = nearbyHillActions
        self.walkSummaries = walkSummaries
        self.providerColor = providerColor
        self.placementMode = placementMode
        super.init(frame: .zero)

        backgroundColor = .clear

        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 14
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.18
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        containerView.addSubview(scrollView)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .left
        titleLabel.text = title

        let startPlaceIconView = UIImageView(
            image: UIImage(
                systemName: "figure.walk.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            )?.withTintColor(providerColor, renderingMode: .alwaysOriginal)
        )
        startPlaceIconView.contentMode = .scaleAspectFit
        startPlaceIconView.setContentHuggingPriority(.required, for: .horizontal)
        startPlaceIconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            startPlaceIconView.widthAnchor.constraint(equalToConstant: 24),
            startPlaceIconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        let providerAccentView = UIView()
        providerAccentView.backgroundColor = providerColor
        providerAccentView.layer.cornerRadius = 2
        providerAccentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            providerAccentView.widthAnchor.constraint(equalToConstant: 4),
            providerAccentView.heightAnchor.constraint(equalToConstant: 24)
        ])

        let titleRow = UIStackView(arrangedSubviews: [providerAccentView, startPlaceIconView, titleLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .top
        titleRow.spacing = 8

        func makeDetailLabel(_ text: String, weight: UIFont.Weight = .semibold) -> UILabel {
            let label = UILabel()
            label.font = .systemFont(ofSize: 13, weight: weight)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.textAlignment = .left
            label.text = text
            return label
        }

        contentStack.axis = .vertical
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(titleRow)
        let usesTrailCardLayout = !walkSummaries.isEmpty || provider == .coillte || provider == .sportIreland || provider == .outscape
        if !usesTrailCardLayout, !fullName.isEmpty, fullName != title {
            contentStack.addArrangedSubview(makeDetailLabel("Short Name: \(fullName)", weight: .bold))
        }
        let gridReferenceLabel = makeDetailLabel("Grid Ref: \(gridReference)", weight: .heavy)
        gridReferenceLabel.textColor = .label
        contentStack.addArrangedSubview(gridReferenceLabel)
        if !usesTrailCardLayout {
            contentStack.addArrangedSubview(makeDetailLabel(height))
        }
        if !status.isEmpty, !usesTrailCardLayout {
            contentStack.addArrangedSubview(makeDetailLabel("Status: \(status)", weight: .bold))
        }
        if !usesTrailCardLayout {
            contentStack.addArrangedSubview(makeDetailLabel("Parking: \(parking)"))
        }

        if usesTrailCardLayout {
            let walksTitleLabel = makeDetailLabel("Walks beginning or ending here", weight: .heavy)
            walksTitleLabel.textColor = .label
            contentStack.addArrangedSubview(walksTitleLabel)

            if walkSummaries.isEmpty {
                contentStack.addArrangedSubview(makeDetailLabel("No linked walks supplied"))
            } else {
                for (index, summary) in walkSummaries.enumerated() {
                    contentStack.addArrangedSubview(makeWalkSummaryButton(summary, tag: index))
                }
            }
        }

        let hillIconView = UIImageView(
            image: UIImage(
                systemName: "triangle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            )?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        )
        hillIconView.contentMode = .scaleAspectFit
        hillIconView.setContentHuggingPriority(.required, for: .horizontal)
        hillIconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            hillIconView.widthAnchor.constraint(equalToConstant: 24),
            hillIconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        let hillIconRow = UIStackView(arrangedSubviews: [hillIconView])
        hillIconRow.axis = .horizontal
        hillIconRow.alignment = .center
        hillIconRow.spacing = 8
        let hillIconRowSpacer = UIView()
        hillIconRow.addArrangedSubview(hillIconRowSpacer)

        if let mountainViewsImage = UIImage(named: ActiveRegion.current.externalDataProviderAssetName),
           mountainViewsStartPlaceHandler != nil {
            mountainViewsStartPlaceButton.configuration = imageButtonConfiguration(
                image: mountainViewsImage,
                backgroundColor: UIColor.systemGreen.withAlphaComponent(0.10)
            )
            mountainViewsStartPlaceButton.accessibilityLabel = "Open MountainViews starting place"
            mountainViewsStartPlaceButton.addTarget(self, action: #selector(mountainViewsStartPlaceButtonTapped), for: .touchUpInside)
            mountainViewsStartPlaceButton.imageView?.contentMode = .scaleAspectFit
            NSLayoutConstraint.activate([
                mountainViewsStartPlaceButton.widthAnchor.constraint(equalToConstant: 54),
                mountainViewsStartPlaceButton.heightAnchor.constraint(equalToConstant: 24)
            ])
            hillIconRow.addArrangedSubview(mountainViewsStartPlaceButton)
        }

        contentStack.addArrangedSubview(hillIconRow)

        if nearbyHillActions.isEmpty {
            contentStack.addArrangedSubview(makeDetailLabel("None within 6.0 km"))
        } else {
            for action in nearbyHillActions {
                let button = UIButton(type: .system)
                button.configuration = actionButtonConfiguration(
                    title: action.title,
                    foregroundColor: .label,
                    backgroundColor: UIColor.systemGray5
                )
                button.contentHorizontalAlignment = .leading
                button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
                button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = .systemFont(ofSize: 12, weight: .bold)
                    return outgoing
                }
                button.titleLabel?.numberOfLines = 1
                button.titleLabel?.lineBreakMode = .byTruncatingTail
                button.titleLabel?.adjustsFontSizeToFitWidth = false
                button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                button.setContentHuggingPriority(.defaultLow, for: .horizontal)
                button.translatesAutoresizingMaskIntoConstraints = false
                button.heightAnchor.constraint(equalToConstant: 28).isActive = true
                button.tag = nearbyHillButtons.count
                button.addTarget(self, action: #selector(nearbyHillButtonTapped(_:)), for: .touchUpInside)
                nearbyHillButtons.append(button)

                let metricsLabel = makeDetailLabel(action.metrics, weight: .regular)
                metricsLabel.font = .systemFont(ofSize: 12, weight: .regular)
                metricsLabel.setContentHuggingPriority(.required, for: .horizontal)
                metricsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

                let row = UIStackView(arrangedSubviews: [button, metricsLabel])
                row.axis = .horizontal
                row.alignment = .center
                row.spacing = 8
                contentStack.addArrangedSubview(row)
            }
        }

        var dataSourceParts = ["Location: \(placeDataSourceName(for: provider))"]
        if !walkSummaries.isEmpty || provider == .coillte || provider == .sportIreland || provider == .outscape {
            dataSourceParts.append("Walk: \(walkDataSourceName(for: provider))")
        }
        if !nearbyHillActions.isEmpty {
            dataSourceParts.append("Hills: MountainViews.ie")
        }
        let dataText = "Data: \(dataSourceParts.joined(separator: " - "))"
        contentStack.addArrangedSubview(makeDetailLabel(dataText, weight: .regular))

        directionsButton.configuration = actionButtonConfiguration(
            title: "Directions (Apple Maps)",
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
        )
        directionsButton.addTarget(self, action: #selector(directionsButtonTapped), for: .touchUpInside)

        googleDirectionsButton.configuration = actionButtonConfiguration(
            title: "Directions (Google Maps)",
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
        )
        googleDirectionsButton.addTarget(self, action: #selector(googleDirectionsButtonTapped), for: .touchUpInside)

        let directionsStack = UIStackView(arrangedSubviews: [directionsButton, googleDirectionsButton])
        directionsStack.axis = .vertical
        directionsStack.alignment = .fill
        directionsStack.distribution = .fill
        directionsStack.spacing = 8
        contentStack.addArrangedSubview(directionsStack)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -28)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func actionButtonConfiguration(
        title: String,
        foregroundColor: UIColor,
        backgroundColor: UIColor
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = foregroundColor
        configuration.background.backgroundColor = backgroundColor
        configuration.background.cornerRadius = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 14, weight: .bold)
            return outgoing
        }
        return configuration
    }

    private func imageButtonConfiguration(image: UIImage, backgroundColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.image = resizedImage(image, fitting: CGSize(width: 50, height: 20))
        configuration.imagePlacement = .all
        configuration.baseForegroundColor = .label
        configuration.background.backgroundColor = backgroundColor
        configuration.background.cornerRadius = 4
        configuration.imagePadding = 0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        return configuration
    }

    private func resizedImage(_ image: UIImage, fitting targetSize: CGSize) -> UIImage {
        let scale = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func placeDataSourceName(for provider: StartPlaceProvider) -> String {
        switch provider {
        case .mountainViews:
            return "MountainViews.ie"
        case .coillte:
            return "Coillte"
        case .sportIreland:
            return "Sport Ireland"
        case .outscape:
            return "Outscape NI"
        }
    }

    private func walkDataSourceName(for provider: StartPlaceProvider) -> String {
        switch provider {
        case .coillte:
            return "Coillte"
        case .sportIreland:
            return "Sport Ireland"
        case .outscape:
            return "Outscape NI"
        case .mountainViews:
            return "Not supplied"
        }
    }

    private func makeWalkSummaryButton(_ summary: StartPlaceWalkSummary, tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = summary.name
        configuration.subtitle = "Length: \(summary.length) • Ascent: \(summary.ascent)"
        configuration.image = UIImage(systemName: "point.topleft.down.curvedto.point.bottomright.up")
        configuration.imagePadding = 8
        configuration.imagePlacement = .leading
        configuration.baseForegroundColor = providerColor
        configuration.background.backgroundColor = providerColor.withAlphaComponent(0.08)
        configuration.background.cornerRadius = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 13, weight: .bold)
            return outgoing
        }
        configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 12, weight: .regular)
            outgoing.foregroundColor = UIColor.secondaryLabel
            return outgoing
        }
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.numberOfLines = 0
        button.tag = tag
        button.addTarget(self, action: #selector(walkSummaryButtonTapped(_:)), for: .touchUpInside)
        return button
    }

    func presentCallout(
        from rect: CGRect,
        in view: UIView,
        constrainedTo constrainedRect: CGRect,
        animated: Bool
    ) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)

        let usableHorizontalWidth = constrainedRect.width - CalloutLayoutMetrics.leftRailReservedWidth - CalloutLayoutMetrics.rightRailReservedWidth - 24
        let availableWidth = min(usableHorizontalWidth, 320)
        let preferredWidth = max(280, availableWidth)
        let contentWidth = preferredWidth - 28
        let fittedContentHeight = ceil(contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
        let maximumAvailableHeight = constrainedRect.height - 16
        let fittedHeight = min(maximumAvailableHeight, fittedContentHeight + 24)
        let availableBelow = constrainedRect.maxY - rect.maxY
        let verticalGap: CGFloat = CalloutLayoutMetrics.automaticVerticalGap
        let minimumLeading = constrainedRect.minX + CalloutLayoutMetrics.leftRailReservedWidth
        let maximumLeading = constrainedRect.maxX - preferredWidth - CalloutLayoutMetrics.rightRailReservedWidth
        let sidePreferredLeadingX: CGFloat = rect.midX < constrainedRect.midX
            ? rect.maxX + 18
            : rect.minX - 18 - preferredWidth
        let centeredLeadingX = rect.midX - (preferredWidth / 2)
        let clampedSideLeadingX = min(max(sidePreferredLeadingX, minimumLeading), maximumLeading)
        let clampedCenteredLeadingX = min(max(centeredLeadingX, minimumLeading), maximumLeading)
        let requiredVerticalSpace = fittedHeight + verticalGap + 8
        let opensAboveAnnotation = rect.minY >= requiredVerticalSpace || availableBelow < requiredVerticalSpace
        let leadingX = placementMode == .belowAnchor ? clampedCenteredLeadingX : clampedSideLeadingX
        let verticalConstraint: NSLayoutConstraint = placementMode == .belowAnchor
            ? topAnchor.constraint(equalTo: view.topAnchor, constant: max(rect.maxY + CalloutLayoutMetrics.belowAnchorGap, constrainedRect.minY + 8))
            : (
                opensAboveAnnotation
                ? bottomAnchor.constraint(equalTo: view.topAnchor, constant: rect.minY - verticalGap)
                : topAnchor.constraint(equalTo: view.topAnchor, constant: rect.maxY + verticalGap)
            )

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: preferredWidth),
            heightAnchor.constraint(equalToConstant: fittedHeight),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingX),
            topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: constrainedRect.minY + 8),
            bottomAnchor.constraint(lessThanOrEqualTo: view.topAnchor, constant: constrainedRect.maxY - 8),
            verticalConstraint
        ])

        view.layoutIfNeeded()

        if animated {
            alpha = 0
            transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.animate(withDuration: 0.2) {
                self.alpha = 1
                self.transform = .identity
            }
        }
    }

    func dismissCallout(animated: Bool) {
        let animations = {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 8)
        }

        let completion: (Bool) -> Void = { _ in
            self.removeFromSuperview()
            self.transform = .identity
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }

    func marginInsetsHintForPresentation(from rect: CGRect) -> UIEdgeInsets {
        UIEdgeInsets(top: -170, left: -28, bottom: -24, right: -28)
    }

    @objc private func directionsButtonTapped() {
        directionsHandler()
    }

    @objc private func googleDirectionsButtonTapped() {
        googleDirectionsHandler()
    }

    @objc private func mountainViewsStartPlaceButtonTapped() {
        mountainViewsStartPlaceHandler?()
    }

    @objc private func walkSummaryButtonTapped(_ sender: UIButton) {
        guard walkSummaries.indices.contains(sender.tag) else { return }
        walkSummaries[sender.tag].selectionHandler()
    }

    @objc private func nearbyHillButtonTapped(_ sender: UIButton) {
        guard nearbyHillActions.indices.contains(sender.tag) else { return }
        nearbyHillActions[sender.tag].handler()
    }
}
