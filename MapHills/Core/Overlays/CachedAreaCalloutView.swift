import UIKit
import MapLibre

final class CachedAreaCalloutView: UIView, MLNCalloutView {
    var representedObject: MLNAnnotation
    var leftAccessoryView = UIView(frame: .zero)
    var rightAccessoryView = UIView(frame: .zero)
    weak var delegate: MLNCalloutViewDelegate?

    private let titleLabel = UILabel()
    private let cacheTagLabel = UILabel()
    private let metricsLabel = UILabel()
    private let footerStack = UIStackView()
    private let containerView = UIView()
    private let primaryActionButton = UIButton(type: .system)
    private let secondaryActionButton = UIButton(type: .system)
    private let primaryActionHandler: () -> Void
    private let secondaryActionHandler: () -> Void

    var isAnchoredToAnnotation: Bool {
        true
    }

    var dismissesAutomatically: Bool {
        true
    }

    init(
        annotation: MLNAnnotation,
        title: String,
        metrics: String,
        primaryActionTitle: String,
        primaryActionHandler: @escaping () -> Void,
        secondaryActionTitle: String,
        secondaryActionHandler: @escaping () -> Void
    ) {
        self.representedObject = annotation
        self.primaryActionHandler = primaryActionHandler
        self.secondaryActionHandler = secondaryActionHandler
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

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = title

        cacheTagLabel.font = .systemFont(ofSize: 13, weight: .bold)
        cacheTagLabel.textColor = .secondaryLabel
        cacheTagLabel.textAlignment = .right
        cacheTagLabel.text = "Cached"
        cacheTagLabel.setContentHuggingPriority(.required, for: .horizontal)
        cacheTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        metricsLabel.font = .systemFont(ofSize: 13, weight: .regular)
        metricsLabel.textColor = .secondaryLabel
        metricsLabel.numberOfLines = 0
        metricsLabel.text = metrics

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, cacheTagLabel])
        titleRow.axis = .horizontal
        titleRow.alignment = .firstBaseline
        titleRow.spacing = 8

        primaryActionButton.configuration = actionButtonConfiguration(
            title: primaryActionTitle,
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.systemBlue.withAlphaComponent(0.10)
        )
        primaryActionButton.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)

        secondaryActionButton.configuration = actionButtonConfiguration(
            title: secondaryActionTitle,
            foregroundColor: .systemRed,
            backgroundColor: UIColor.systemRed.withAlphaComponent(0.10)
        )
        secondaryActionButton.addTarget(self, action: #selector(secondaryActionTapped), for: .touchUpInside)

        footerStack.axis = .horizontal
        footerStack.alignment = .fill
        footerStack.distribution = .fillEqually
        footerStack.spacing = 8
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerStack.addArrangedSubview(secondaryActionButton)
        footerStack.addArrangedSubview(primaryActionButton)

        let contentStack = UIStackView(arrangedSubviews: [titleRow, metricsLabel, footerStack])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 280)
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
            outgoing.font = .systemFont(ofSize: 14, weight: .semibold)
            return outgoing
        }
        return configuration
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
        let verticalGap: CGFloat = 32
        let fittedHeight = systemLayoutSizeFitting(
            CGSize(width: preferredWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let availableAbove = rect.minY - constrainedRect.minY
        let availableBelow = constrainedRect.maxY - rect.maxY
        let opensAboveAnnotation = availableAbove >= fittedHeight + verticalGap || availableAbove >= availableBelow
        let leadingX = min(max(rect.midX - (preferredWidth / 2), constrainedRect.minX + 12), constrainedRect.maxX - preferredWidth - 12)

        var constraints = [
            widthAnchor.constraint(equalToConstant: preferredWidth),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingX),
            topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: constrainedRect.minY + 8),
            bottomAnchor.constraint(lessThanOrEqualTo: view.topAnchor, constant: constrainedRect.maxY - 8)
        ]

        if opensAboveAnnotation {
            constraints.append(bottomAnchor.constraint(equalTo: view.topAnchor, constant: rect.minY - verticalGap))
        } else {
            constraints.append(topAnchor.constraint(equalTo: view.topAnchor, constant: rect.maxY + verticalGap))
        }

        NSLayoutConstraint.activate(constraints)
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
        UIEdgeInsets(top: -140, left: -24, bottom: -24, right: -24)
    }

    @objc private func primaryActionTapped() {
        primaryActionHandler()
    }

    @objc private func secondaryActionTapped() {
        secondaryActionHandler()
    }
}
