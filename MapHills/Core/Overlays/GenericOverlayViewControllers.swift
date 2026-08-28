//
//  PrimaryOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit

func makeMapInteractionLockStack(
    noteText: String,
    lockSwitch: UISwitch,
    labelFont: UIFont = .systemFont(ofSize: 14, weight: .medium),
    noteFont: UIFont = .systemFont(ofSize: 13, weight: .regular)
) -> UIStackView {
    let lockLabel = UILabel()
    lockLabel.text = "Lock map gestures"
    lockLabel.font = labelFont
    lockLabel.textColor = .label

    let lockRow = UIStackView(arrangedSubviews: [lockLabel, lockSwitch])
    lockRow.axis = .horizontal
    lockRow.alignment = .center
    lockRow.distribution = .equalSpacing

    let noteLabel = UILabel()
    noteLabel.text = noteText
    noteLabel.font = noteFont
    noteLabel.textColor = .secondaryLabel
    noteLabel.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [lockRow, noteLabel])
    stack.axis = .vertical
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
}

final class ConfirmationOverlayViewController: UIViewController {
    private let dialogTitle: String
    private let messageText: String
    private let confirmTitle: String
    private let confirmTintColor: UIColor
    private let confirmHandler: () -> Void
    private let cancelHandler: () -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()

    init(
        title: String,
        message: String,
        confirmTitle: String,
        confirmTintColor: UIColor = .systemBlue,
        confirmHandler: @escaping () -> Void,
        cancelHandler: @escaping () -> Void
    ) {
        self.dialogTitle = title
        self.messageText = message
        self.confirmTitle = confirmTitle
        self.confirmTintColor = confirmTintColor
        self.confirmHandler = confirmHandler
        self.cancelHandler = cancelHandler
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.isAccessibilityElement = true
        cardView.accessibilityIdentifier = "recordsOverlayCard"
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = dialogTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = messageText
        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let cancelButton = UIButton(type: .system)
        cancelButton.accessibilityIdentifier = "confirmationCancelButton"
        cancelButton.configuration = actionButtonConfiguration(
            title: "Cancel",
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.secondarySystemBackground
        )
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let confirmButton = UIButton(type: .system)
        confirmButton.accessibilityIdentifier = "confirmationConfirmButton"
        confirmButton.configuration = actionButtonConfiguration(
            title: confirmTitle,
            foregroundColor: .white,
            backgroundColor: confirmTintColor
        )
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let contentStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttonStack])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            cancelButton.heightAnchor.constraint(equalToConstant: 42),
            confirmButton.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func actionButtonConfiguration(title: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseForegroundColor = foregroundColor
        configuration.baseBackgroundColor = backgroundColor
        configuration.cornerStyle = .medium
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: foregroundColor
            ])
        )
        return configuration
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.cancelHandler()
        }
    }

    @objc private func confirmTapped() {
        dismiss(animated: true) {
            self.confirmHandler()
        }
    }
}

final class SelectionOverlayViewController: UIViewController {
    struct Option {
        let title: String
        let isSelected: Bool
        let handler: () -> Void
    }

    private let dialogTitle: String
    private let messageText: String?
    private let options: [Option]

    private let dimmingView = UIView()
    private let cardView = UIView()

    init(title: String, message: String? = nil, options: [Option]) {
        self.dialogTitle = title
        self.messageText = message
        self.options = options
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = dialogTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        contentStack.addArrangedSubview(titleLabel)

        if let messageText, !messageText.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = messageText
            messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
            messageLabel.textColor = .secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            contentStack.addArrangedSubview(messageLabel)
        }

        let optionsStack = UIStackView()
        optionsStack.axis = .vertical
        optionsStack.spacing = 10

        for option in options {
            let button = UIButton(type: .system)
            button.configuration = optionButtonConfiguration(title: option.title, isSelected: option.isSelected)
            button.addAction(UIAction { [weak self] _ in
                self?.dismiss(animated: true) {
                    option.handler()
                }
            }, for: .touchUpInside)
            optionsStack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        }

        contentStack.addArrangedSubview(optionsStack)

        let footerContainerView = UIView()
        footerContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(footerContainerView)

        let doneButton = UIButton(type: .system)
        doneButton.configuration = .plain()
        doneButton.configuration?.title = "Done"
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        footerContainerView.addSubview(doneButton)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            footerContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            footerContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            footerContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            footerContainerView.heightAnchor.constraint(equalToConstant: 32),

            doneButton.centerXAnchor.constraint(equalTo: footerContainerView.centerXAnchor),
            doneButton.centerYAnchor.constraint(equalTo: footerContainerView.centerYAnchor),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: -20)
        ])
    }

    private func optionButtonConfiguration(title: String, isSelected: Bool) -> UIButton.Configuration {
        let foregroundColor: UIColor = isSelected ? .white : .systemBlue
        let backgroundColor: UIColor = isSelected ? .systemBlue : .secondarySystemBackground
        return actionButtonConfiguration(
            title: isSelected ? "\(title)  ✓" : title,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }

    private func actionButtonConfiguration(title: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseForegroundColor = foregroundColor
        configuration.baseBackgroundColor = backgroundColor
        configuration.cornerStyle = .medium
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: foregroundColor
            ])
        )
        return configuration
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

final class ActionOverlayViewController: UIViewController {
    enum ActionStyle {
        case normal
        case destructive
        case cancel
    }

    struct Action {
        let title: String
        let style: ActionStyle
        let handler: () -> Void
    }

    private let dialogTitle: String
    private let messageText: String?
    private let actions: [Action]
    private let preferredActionTitle: String?

    private let dimmingView = UIView()
    private let cardView = UIView()

    init(title: String, message: String? = nil, preferredActionTitle: String? = nil, actions: [Action]) {
        self.dialogTitle = title
        self.messageText = message
        self.actions = actions
        self.preferredActionTitle = preferredActionTitle
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = dialogTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        contentStack.addArrangedSubview(titleLabel)

        if let messageText, !messageText.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = messageText
            messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
            messageLabel.textColor = .secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            contentStack.addArrangedSubview(messageLabel)
        }

        for action in actions {
            let button = UIButton(type: .system)
            let foregroundColor: UIColor
            let backgroundColor: UIColor
            let isPreferredAction = action.title == preferredActionTitle
            switch action.style {
            case .normal:
                if isPreferredAction {
                    foregroundColor = .white
                    backgroundColor = .systemBlue
                } else {
                    foregroundColor = .systemBlue
                    backgroundColor = .secondarySystemBackground
                }
            case .destructive:
                foregroundColor = .white
                backgroundColor = .systemRed
            case .cancel:
                foregroundColor = .systemBlue
                backgroundColor = UIColor.secondarySystemBackground
            }

            button.configuration = actionButtonConfiguration(
                title: action.title,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor
            )
            button.addAction(UIAction { [weak self] _ in
                self?.dismiss(animated: true) {
                    action.handler()
                }
            }, for: .touchUpInside)
            button.heightAnchor.constraint(equalToConstant: 42).isActive = true
            contentStack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
    }

    private func actionButtonConfiguration(title: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseForegroundColor = foregroundColor
        configuration.baseBackgroundColor = backgroundColor
        configuration.cornerStyle = .medium
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: foregroundColor
            ])
        )
        return configuration
    }

    @objc private func cancelTapped() {
        if let cancelAction = actions.first(where: { $0.style == .cancel }) {
            dismiss(animated: true) {
                cancelAction.handler()
            }
        } else {
            dismiss(animated: true)
        }
    }
}

final class TextInputOverlayViewController: UIViewController {
    private let dialogTitle: String
    private let messageText: String?
    private let placeholderText: String
    private let initialText: String
    private let confirmTitle: String
    private let confirmHandler: (String) -> Void
    private let cancelHandler: () -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let textField = UITextField()

    init(
        title: String,
        message: String? = nil,
        placeholder: String,
        initialText: String = "",
        confirmTitle: String,
        confirmHandler: @escaping (String) -> Void,
        cancelHandler: @escaping () -> Void = {}
    ) {
        self.dialogTitle = title
        self.messageText = message
        self.placeholderText = placeholder
        self.initialText = initialText
        self.confirmTitle = confirmTitle
        self.confirmHandler = confirmHandler
        self.cancelHandler = cancelHandler
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = dialogTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        contentStack.addArrangedSubview(titleLabel)

        if let messageText, !messageText.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = messageText
            messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
            messageLabel.textColor = .secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            contentStack.addArrangedSubview(messageLabel)
        }

        textField.borderStyle = .roundedRect
        textField.placeholder = placeholderText
        textField.text = initialText
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.accessibilityIdentifier = "textInputField"
        contentStack.addArrangedSubview(textField)

        let cancelButton = UIButton(type: .system)
        cancelButton.configuration = actionButtonConfiguration(
            title: "Cancel",
            foregroundColor: .systemBlue,
            backgroundColor: UIColor.secondarySystemBackground
        )
        cancelButton.accessibilityIdentifier = "textInputCancelButton"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let confirmButton = UIButton(type: .system)
        confirmButton.configuration = actionButtonConfiguration(
            title: confirmTitle,
            foregroundColor: .white,
            backgroundColor: .systemBlue
        )
        confirmButton.accessibilityIdentifier = "textInputConfirmButton"
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually
        contentStack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            cancelButton.heightAnchor.constraint(equalToConstant: 42),
            confirmButton.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    private func actionButtonConfiguration(title: String, foregroundColor: UIColor, backgroundColor: UIColor) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseForegroundColor = foregroundColor
        configuration.baseBackgroundColor = backgroundColor
        configuration.cornerStyle = .medium
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: foregroundColor
            ])
        )
        return configuration
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.cancelHandler()
        }
    }

    @objc private func confirmTapped() {
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        dismiss(animated: true) {
            self.confirmHandler(text)
        }
    }
}
