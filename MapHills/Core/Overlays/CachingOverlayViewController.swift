//
//  GPXAndInfoOverlays.swift
//  MapHills
//
//  Created by David Owens on 26/03/2026.
//

import UIKit
import CoreLocation

final class CachingOverlayViewController: UIViewController {
    private let actionTitleProvider: () -> String
    private var cachedAreas: [CachedOfflineArea]
    private let actionHandler: () -> Void
    private let selectHandler: (CachedOfflineArea) -> Void
    private let retryHandler: (CachedOfflineArea, @escaping (CachedOfflineArea?) -> Void) -> Void
    private let deleteAllHandler: (@escaping (Bool) -> Void) -> Void
    private let selectedDetailLevelProvider: () -> CachedAreaDetailLevel
    private let detailLevelChangeHandler: (CachedAreaDetailLevel) -> Void
    private let renameHandler: (CachedOfflineArea, @escaping (CachedOfflineArea?) -> Void) -> Void
    private let deleteHandler: (CachedOfflineArea, @escaping (Bool) -> Void) -> Void

    private let dimmingView = UIView()
    private let cardView = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let totalSizeLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let deleteAllButton = UIButton(type: .system)
    private let detailLevelControl = UISegmentedControl(items: CachedAreaDetailLevel.allCases.map(\.title))

    init(
        actionTitleProvider: @escaping () -> String,
        cachedAreas: [CachedOfflineArea],
        actionHandler: @escaping () -> Void,
        selectHandler: @escaping (CachedOfflineArea) -> Void,
        retryHandler: @escaping (CachedOfflineArea, @escaping (CachedOfflineArea?) -> Void) -> Void,
        deleteAllHandler: @escaping (@escaping (Bool) -> Void) -> Void,
        selectedDetailLevelProvider: @escaping () -> CachedAreaDetailLevel,
        detailLevelChangeHandler: @escaping (CachedAreaDetailLevel) -> Void,
        renameHandler: @escaping (CachedOfflineArea, @escaping (CachedOfflineArea?) -> Void) -> Void,
        deleteHandler: @escaping (CachedOfflineArea, @escaping (Bool) -> Void) -> Void
    ) {
        self.actionTitleProvider = actionTitleProvider
        self.cachedAreas = cachedAreas
        self.actionHandler = actionHandler
        self.selectHandler = selectHandler
        self.retryHandler = retryHandler
        self.deleteAllHandler = deleteAllHandler
        self.selectedDetailLevelProvider = selectedDetailLevelProvider
        self.detailLevelChangeHandler = detailLevelChangeHandler
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

        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissOverlay)))
        view.addSubview(dimmingView)

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let titleLabel = UILabel()
        titleLabel.text = "Caching"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        let titleRow = makeOverlayTitleRow(with: titleLabel)

        let descriptionLabel = UILabel()
        descriptionLabel.text = "Save the currently visible map area for offline use. Saved areas are named, reloaded on launch, and outlined on the map. Cached map coverage is indicated by the green marker on the caching button. Caching is only available for OpenTopo and Satellite layers."
        descriptionLabel.font = .systemFont(ofSize: 13, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center

        let detailTitleLabel = UILabel()
        detailTitleLabel.text = "Cache Level"
        detailTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        detailTitleLabel.textColor = .label
        detailTitleLabel.textAlignment = .left

        detailLevelControl.selectedSegmentIndex = CachedAreaDetailLevel.allCases.firstIndex(of: selectedDetailLevelProvider()) ?? 1
        detailLevelControl.accessibilityIdentifier = "cacheDetailLevelControl"
        detailLevelControl.selectedSegmentTintColor = .systemBlue
        detailLevelControl.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ],
            for: .normal
        )
        detailLevelControl.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 13, weight: .bold)
            ],
            for: .selected
        )
        detailLevelControl.addTarget(self, action: #selector(detailLevelChanged), for: .valueChanged)

        let detailSubtitleLabel = UILabel()
        detailSubtitleLabel.text = "Light uses fewer tiles. Deep caching uses more tiles and takes longer, but gives higher zoom detail."
        detailSubtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailSubtitleLabel.textColor = .secondaryLabel
        detailSubtitleLabel.numberOfLines = 0
        detailSubtitleLabel.textAlignment = .left

        let detailStack = UIStackView(arrangedSubviews: [detailTitleLabel, detailLevelControl, detailSubtitleLabel])
        detailStack.axis = .vertical
        detailStack.spacing = 6

        let cachedAreasTitleLabel = UILabel()
        cachedAreasTitleLabel.text = "Saved Cached Areas"
        cachedAreasTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        cachedAreasTitleLabel.textColor = .label
        cachedAreasTitleLabel.textAlignment = .left

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CachedAreaTableViewCell.self, forCellReuseIdentifier: "CachedAreaCell")
        tableView.tableFooterView = UIView()

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "No offline areas saved yet."
        emptyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .left
        emptyLabel.isHidden = !cachedAreas.isEmpty

        totalSizeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        totalSizeLabel.textColor = .secondaryLabel
        totalSizeLabel.numberOfLines = 1
        totalSizeLabel.textAlignment = .left

        let cachedAreasStack = UIStackView(arrangedSubviews: [cachedAreasTitleLabel, totalSizeLabel, tableView, emptyLabel])
        cachedAreasStack.axis = .vertical
        cachedAreasStack.spacing = 6

        actionButton.configuration = cachingActionButtonConfiguration(title: actionTitleProvider())
        actionButton.addTarget(self, action: #selector(runCachingAction), for: .touchUpInside)

        deleteAllButton.configuration = .plain()
        deleteAllButton.configuration?.title = "Delete All Caches"
        deleteAllButton.setTitleColor(.systemRed, for: .normal)
        deleteAllButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        deleteAllButton.isHidden = cachedAreas.isEmpty
        deleteAllButton.addTarget(self, action: #selector(runDeleteAllAction), for: .touchUpInside)

        let closeButton = UIButton(type: .system)
        closeButton.configuration = .plain()
        closeButton.configuration?.title = "Done"
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [titleRow, descriptionLabel, detailStack, actionButton, cachedAreasStack, deleteAllButton, closeButton])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            cardView.widthAnchor.constraint(equalToConstant: 320),

            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),

            tableView.heightAnchor.constraint(equalToConstant: 170)
        ])
        updateTotalSizeLabel()
        refreshActionState()
    }

    private func refreshUI() {
        emptyLabel.isHidden = !cachedAreas.isEmpty
        updateTotalSizeLabel()
        tableView.reloadData()
        deleteAllButton.isHidden = cachedAreas.isEmpty
        refreshActionState()
    }

    private func updateTotalSizeLabel() {
        let totalBytes = cachedAreas.reduce(UInt64(0)) { $0 + $1.byteCount }
        totalSizeLabel.text = "Total cached: \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))"
        totalSizeLabel.isHidden = cachedAreas.isEmpty
    }

    private func refreshActionState() {
        actionButton.configuration = cachingActionButtonConfiguration(title: actionTitleProvider())
    }

    private func handleRename(for area: CachedOfflineArea) {
        renameHandler(area) { [weak self] renamedArea in
            guard let self, let renamedArea,
                  let index = self.cachedAreas.firstIndex(where: { $0.id == area.id }) else { return }
            self.cachedAreas[index] = renamedArea
            self.cachedAreas.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.refreshUI()
        }
    }

    private func handleDelete(for area: CachedOfflineArea) {
        deleteHandler(area) { [weak self] deleted in
            guard let self, deleted else { return }
            self.cachedAreas.removeAll { $0.id == area.id }
            self.refreshUI()
        }
    }

    private func handleRetry(for area: CachedOfflineArea) {
        retryHandler(area) { [weak self] updatedArea in
            guard let self, let updatedArea,
                  let index = self.cachedAreas.firstIndex(where: { $0.id == area.id }) else { return }
            self.cachedAreas[index] = updatedArea
            self.refreshUI()
        }
    }

    @objc private func detailLevelChanged() {
        let selectedIndex = detailLevelControl.selectedSegmentIndex
        guard CachedAreaDetailLevel.allCases.indices.contains(selectedIndex) else { return }
        detailLevelChangeHandler(CachedAreaDetailLevel.allCases[selectedIndex])
    }

    @objc private func runCachingAction() {
        dismiss(animated: true) {
            self.actionHandler()
        }
    }

    @objc private func runDeleteAllAction() {
        deleteAllHandler { [weak self] deleted in
            guard let self, deleted else { return }
            self.cachedAreas.removeAll()
            self.refreshUI()
        }
    }

    @objc private func dismissOverlay() {
        dismiss(animated: true)
    }

    private func cachingActionButtonConfiguration(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = .systemBlue
        configuration.background.cornerRadius = 12
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.white
            ])
        )
        return configuration
    }
}

final class CachedAreaTableViewCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let labelsStackView = UIStackView()
    private let primaryActionButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private var primaryTapHandler: (() -> Void)?
    private var deleteTapHandler: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .default

        nameLabel.font = .systemFont(ofSize: 15, weight: .regular)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 1
        detailLabel.textAlignment = .left
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        labelsStackView.axis = .vertical
        labelsStackView.alignment = .fill
        labelsStackView.distribution = .fill
        labelsStackView.spacing = 2
        labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        labelsStackView.addArrangedSubview(nameLabel)
        labelsStackView.addArrangedSubview(detailLabel)

        primaryActionButton.translatesAutoresizingMaskIntoConstraints = false
        primaryActionButton.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        contentView.addSubview(labelsStackView)
        contentView.addSubview(primaryActionButton)
        contentView.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            deleteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28),

            primaryActionButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
            primaryActionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            primaryActionButton.widthAnchor.constraint(equalToConstant: 28),
            primaryActionButton.heightAnchor.constraint(equalToConstant: 28),

            labelsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            labelsStackView.trailingAnchor.constraint(equalTo: primaryActionButton.leadingAnchor, constant: -10),
            labelsStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            labelsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        area: CachedOfflineArea,
        primaryTapHandler: @escaping () -> Void,
        deleteTapHandler: @escaping () -> Void
    ) {
        nameLabel.text = area.name
        let baseDetail = [area.detailLevel.title, area.status.title, ByteCountFormatter.string(fromByteCount: Int64(area.byteCount), countStyle: .file)]
            .joined(separator: " • ")
        if let statusMessage = area.statusMessage, area.status == .failed {
            detailLabel.text = "\(baseDetail)\n\(statusMessage)"
            detailLabel.numberOfLines = 2
        } else {
            detailLabel.text = baseDetail
            detailLabel.numberOfLines = 1
        }
        self.primaryTapHandler = primaryTapHandler
        self.deleteTapHandler = deleteTapHandler
        switch area.status {
        case .ready:
            primaryActionButton.setImage(UIImage(systemName: "pencil"), for: .normal)
            primaryActionButton.tintColor = .systemBlue
            primaryActionButton.isEnabled = true
        case .partial, .failed:
            primaryActionButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
            primaryActionButton.tintColor = .systemBlue
            primaryActionButton.isEnabled = true
        case .downloading:
            primaryActionButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
            primaryActionButton.tintColor = .systemGray3
            primaryActionButton.isEnabled = false
        }
    }

    @objc private func primaryActionTapped() {
        primaryTapHandler?()
    }

    @objc private func deleteTapped() {
        deleteTapHandler?()
    }
}

extension CachingOverlayViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cachedAreas.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CachedAreaCell", for: indexPath) as! CachedAreaTableViewCell
        let area = cachedAreas[indexPath.row]
        cell.configure(
            area: area,
            primaryTapHandler: { [weak self] in
                switch area.status {
                case .ready:
                    self?.handleRename(for: area)
                case .partial, .failed:
                    self?.handleRetry(for: area)
                case .downloading:
                    break
                }
            },
            deleteTapHandler: { [weak self] in
                self?.handleDelete(for: area)
            }
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let area = cachedAreas[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true) {
            self.selectHandler(area)
        }
    }
}
