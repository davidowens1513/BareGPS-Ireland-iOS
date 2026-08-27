//
//  GPXAndInfoOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation

final class SavedGPXRecordingsOverlayViewController: UIViewController {
    private var items: [SavedGPXRecordingItem]
    private let openHandler: (URL) -> Void
    private let shareHandler: (URL) -> Void
    private let renameHandler: (URL, @escaping (SavedGPXRecordingItem?) -> Void) -> Void
    private let deleteHandler: (URL) -> Bool

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let totalSizeLabel = UILabel()

    init(
        items: [SavedGPXRecordingItem],
        openHandler: @escaping (URL) -> Void,
        shareHandler: @escaping (URL) -> Void,
        renameHandler: @escaping (URL, @escaping (SavedGPXRecordingItem?) -> Void) -> Void,
        deleteHandler: @escaping (URL) -> Bool
    ) {
        self.items = items
        self.openHandler = openHandler
        self.shareHandler = shareHandler
        self.renameHandler = renameHandler
        self.deleteHandler = deleteHandler
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

        // Keep the underlying map readable so the live Go To line remains visible.
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissOverlay)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = "Saved GPX Files"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Open, share, rename, or delete previously saved GPX files."
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        totalSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalSizeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        totalSizeLabel.textColor = .secondaryLabel
        totalSizeLabel.textAlignment = .center
        totalSizeLabel.numberOfLines = 1
        totalSizeLabel.text = totalSavedSizeText()

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SavedGPXCell")
        tableView.tableFooterView = UIView()

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No saved GPX files yet."
        emptyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = !items.isEmpty

        let closeButton = UIButton(type: .system)
        closeButton.configuration = .plain()
        closeButton.configuration?.title = "Done"
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleRow, subtitleLabel, totalSizeLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4

        let contentStack = UIStackView(arrangedSubviews: [headerStack, tableView, emptyLabel, closeButton])
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
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            tableView.heightAnchor.constraint(equalToConstant: 320)
        ])
    }

    @objc private func dismissOverlay() {
        dismiss(animated: true)
    }

    private func refreshUI() {
        emptyLabel.isHidden = !items.isEmpty
        totalSizeLabel.text = totalSavedSizeText()
        tableView.reloadData()
    }

    private func totalSavedSizeText() -> String {
        let totalBytes = items.reduce(Int64(0)) { partialResult, item in
            let fileSize = (try? item.fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return partialResult + Int64(fileSize)
        }

        return "Total saved: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
    }

    private func showActions(for item: SavedGPXRecordingItem) {
        let overlay = ActionOverlayViewController(
            title: item.fileURL.deletingPathExtension().lastPathComponent,
            actions: [
                .init(title: "Open", style: .normal) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.openHandler(item.fileURL)
                    }
                },
                .init(title: "Share", style: .normal) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.shareHandler(item.fileURL)
                    }
                },
                .init(title: "Rename", style: .normal) { [weak self] in
                    guard let self else { return }
                    self.renameHandler(item.fileURL) { [weak self] renamedItem in
                        guard let self, let renamedItem,
                              let index = self.items.firstIndex(where: { $0.fileURL == item.fileURL }) else { return }
                        self.items[index] = renamedItem
                        self.refreshUI()
                    }
                },
                .init(title: "Delete", style: .destructive) { [weak self] in
                    self?.showDeleteConfirmation(for: item)
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        present(overlay, animated: true)
    }

    private func showDeleteConfirmation(for item: SavedGPXRecordingItem) {
        if ProcessInfo.processInfo.environment["UITEST_AUTO_CONFIRM_SAVED_GPX_DELETE"] == "1" {
            if deleteHandler(item.fileURL) {
                items.removeAll { $0.fileURL == item.fileURL }
                refreshUI()
            }
            return
        }

        let filename = item.fileURL.deletingPathExtension().lastPathComponent
        let overlay = ConfirmationOverlayViewController(
            title: "Confirm Delete?",
            message: "Delete \(filename)?",
            confirmTitle: "Yes",
            confirmTintColor: .systemRed,
            confirmHandler: { [weak self] in
                guard let self else { return }
                if self.deleteHandler(item.fileURL) {
                    self.items.removeAll { $0.fileURL == item.fileURL }
                    self.refreshUI()
                }
            },
            cancelHandler: {}
        )
        present(overlay, animated: true)
    }
}

extension SavedGPXRecordingsOverlayViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SavedGPXCell", for: indexPath)
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.fileURL.deletingPathExtension().lastPathComponent
        content.secondaryText = item.subtitleText
        content.secondaryTextProperties.numberOfLines = 2

        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showActions(for: items[indexPath.row])
    }
}
