//
//  GPXAndInfoOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation

final class WaypointsOverlayViewController: UIViewController {
    private var items: [SavedWaypoint]
    private let subtitleProvider: (SavedWaypoint) -> String
    private let openHandler: (SavedWaypoint) -> Void
    private let goToHandler: (SavedWaypoint) -> Void
    private let renameHandler: (SavedWaypoint, @escaping (SavedWaypoint?) -> Void) -> Void
    private let deleteHandler: (SavedWaypoint) -> Bool

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    init(
        items: [SavedWaypoint],
        subtitleProvider: @escaping (SavedWaypoint) -> String,
        openHandler: @escaping (SavedWaypoint) -> Void,
        goToHandler: @escaping (SavedWaypoint) -> Void,
        renameHandler: @escaping (SavedWaypoint, @escaping (SavedWaypoint?) -> Void) -> Void,
        deleteHandler: @escaping (SavedWaypoint) -> Bool
    ) {
        self.items = items
        self.subtitleProvider = subtitleProvider
        self.openHandler = openHandler
        self.goToHandler = goToHandler
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissOverlay)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = "Waypoints"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.accessibilityIdentifier = "waypointsTitleLabel"
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Saved waypoints. Open them on the map, use Go To, rename, or delete."
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "WaypointCell")
        tableView.tableFooterView = UIView()
        tableView.accessibilityIdentifier = "waypointsTableView"

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No saved waypoints yet."
        emptyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = !items.isEmpty
        emptyLabel.accessibilityIdentifier = "waypointsEmptyLabel"

        let closeButton = UIButton(type: .system)
        closeButton.configuration = .plain()
        closeButton.configuration?.title = "Done"
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [titleRow, subtitleLabel, tableView, emptyLabel, closeButton])
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
        tableView.reloadData()
    }

    private func showActions(for item: SavedWaypoint, sourceView: UIView) {
        let overlay = ActionOverlayViewController(
            title: item.name,
            message: subtitleProvider(item),
            actions: [
                .init(title: "Open on Map", style: .normal) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.openHandler(item)
                    }
                },
                .init(title: "Go To", style: .normal) { [weak self] in
                    self?.dismiss(animated: true) {
                        self?.goToHandler(item)
                    }
                },
                .init(title: "Rename", style: .normal) { [weak self] in
                    guard let self else { return }
                    self.renameHandler(item) { [weak self] renamedItem in
                        guard let self, let renamedItem,
                              let index = self.items.firstIndex(where: { $0.id == item.id }) else { return }
                        self.items[index] = renamedItem
                        self.refreshUI()
                    }
                },
                .init(title: "Delete", style: .destructive) { [weak self] in
                    guard let self else { return }
                    if self.deleteHandler(item) {
                        self.items.removeAll { $0.id == item.id }
                        self.refreshUI()
                    }
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        present(overlay, animated: true)
    }
}

extension WaypointsOverlayViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WaypointCell", for: indexPath)
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.name
        content.secondaryText = subtitleProvider(item)
        content.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        showActions(for: items[indexPath.row], sourceView: cell)
    }
}
