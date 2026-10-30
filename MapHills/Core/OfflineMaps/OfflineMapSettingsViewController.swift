import UIKit

enum OfflineMapUpdateOfferDecision {
    case update
    case later

    var startsDownload: Bool {
        self == .update
    }

    func performDownload(_ download: () -> Void) {
        guard startsDownload else { return }
        download()
    }
}

final class OfflineMapSettingsViewController: UITableViewController {
    private enum Row: Hashable {
        case status
        case version
        case date
        case space
        case wiFiOnly
        case primaryAction
        case cancelDownload
        case checkForUpdate
        case remove
        case error
    }

    private let manager: OfflineMapDownloadManager
    private var rows: [Row] = []
    private var observer: NSObjectProtocol?
    private var hasStartedAutomaticCheck = false
    private var presentedUpdatePackVersion: String?

    init(manager: OfflineMapDownloadManager) {
        self.manager = manager
        super.init(style: .insetGrouped)
        title = "OpenBareMap"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let logo = overlayLogoImage() {
            let size = CGSize(width: 18, height: 18)
            let renderedLogo = UIGraphicsImageRenderer(size: size).image { _ in
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4).addClip()
                logo.draw(in: CGRect(origin: .zero, size: size))
            }.withRenderingMode(.alwaysOriginal)
            let logoView = UIImageView(frame: CGRect(origin: .zero, size: size))
            logoView.image = renderedLogo
            logoView.contentMode = .scaleAspectFit
            logoView.isUserInteractionEnabled = false
            let logoItem = UIBarButtonItem(customView: logoView)
            if #available(iOS 26.0, *) {
                logoItem.hidesSharedBackground = true
            }
            navigationItem.leftBarButtonItem = logoItem
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OfflineMapCell")
        observer = NotificationCenter.default.addObserver(
            forName: .offlineMapStateDidChange,
            object: manager,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentUpdateOfferIfNeeded()
        guard !hasStartedAutomaticCheck else { return }
        hasStartedAutomaticCheck = true
        let phase = manager.state.phase
        if phase == .notInstalled || phase == .ready || phase == .failed {
            manager.checkForUpdate()
        }
    }

    private func reload() {
        let state = manager.state
        rows = [.status]

        if state.activeMap != nil {
            rows += [.version, .date, .space]
        }
        rows.append(.wiFiOnly)

        switch state.phase {
        case .notInstalled, .availableToDownload, .failed:
            rows.append(.primaryAction)
        case .downloading, .waitingForNetwork, .checkingManifest, .checkingForUpdate,
             .verifying, .installing:
            if state.isNetworkTransferActive {
                rows.append(.cancelDownload)
            }
        case .ready:
            rows.append(.checkForUpdate)
        case .updateAvailable:
            rows.append(.primaryAction)
        }

        if state.activeMap != nil {
            rows.append(.remove)
        }
        if state.lastError != nil {
            rows.append(.error)
        }
        tableView.reloadData()
        presentUpdateOfferIfNeeded()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "OfflineMapCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = title(for: row)
        configuration.secondaryText = detail(for: row)
        configuration.secondaryTextProperties.color = row == .error ? .systemRed : .secondaryLabel
        cell.contentConfiguration = configuration
        cell.accessoryView = nil
        cell.accessoryType = isAction(row) ? .disclosureIndicator : .none
        cell.selectionStyle = isAction(row) ? .default : .none

        if row == .wiFiOnly {
            let toggle = UISwitch()
            toggle.isOn = manager.wiFiOnly
            toggle.isEnabled = !manager.state.isNetworkTransferActive
            toggle.addTarget(self, action: #selector(wiFiOnlyChanged(_:)), for: .valueChanged)
            toggle.accessibilityIdentifier = "offlineMapWiFiOnlySwitch"
            toggle.accessibilityLabel = "Wi-Fi Only"
            toggle.accessibilityHint = toggle.isEnabled
                ? "Turn off to allow map downloads on cellular data."
                : "This setting cannot be changed while a map download is active."
            cell.accessoryView = toggle
        }
        cell.accessibilityIdentifier = "offlineMap.\(String(describing: row))"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        switch row {
        case .primaryAction:
            let phase = manager.state.phase
            if phase == .availableToDownload || phase == .updateAvailable {
                manager.downloadOfferedMap()
            } else {
                manager.checkForUpdate()
            }
        case .checkForUpdate:
            manager.checkForUpdate()
        case .cancelDownload:
            confirmCancellation()
        case .remove:
            confirmRemoval()
        default:
            break
        }
    }

    @objc private func wiFiOnlyChanged(_ sender: UISwitch) {
        manager.wiFiOnly = sender.isOn
    }

    private func confirmRemoval() {
        let alert = UIAlertController(
            title: "Remove Offline Map?",
            message: "The app will use an online map until you download OpenBareMap again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Keep Map", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove Map", style: .destructive) { [weak self] _ in
            do {
                try self?.manager.removeMap()
            } catch {
                self?.showError(error.localizedDescription)
            }
        })
        present(alert, animated: true)
    }

    private func confirmCancellation() {
        let state = manager.state
        let isNearlyComplete = state.bytesExpected > 0 &&
            Double(state.bytesReceived) / Double(state.bytesExpected) >= 0.8
        let message = isNearlyComplete
            ? "This download is nearly complete. Cancel it and delete the downloaded work files?"
            : "Cancel this download and delete the downloaded work files?"
        let alert = UIAlertController(
            title: "Cancel Download?",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Keep Downloading", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Download", style: .destructive) { [weak self] _ in
            self?.manager.cancelDownload()
        })
        present(alert, animated: true)
    }

    private func presentUpdateOfferIfNeeded() {
        guard viewIfLoaded?.window != nil,
              manager.state.phase == .updateAvailable,
              let manifest = manager.offeredManifest,
              presentedUpdatePackVersion != manifest.packVersion,
              presentedViewController == nil else { return }
        presentedUpdatePackVersion = manifest.packVersion

        let size = ByteCountFormatter.string(fromByteCount: manifest.totalBytes, countStyle: .file)
        let date = manifest.publishedAt.map {
            DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none)
        } ?? "Date not supplied"
        let message = "Version \(manifest.mapVersion) • \(size) • \(date)\n\nYour current map will remain ready to use if you choose Later."
        let alert = UIAlertController(title: "OpenBareMap Update", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Later", style: .cancel) { [weak self] _ in
            OfflineMapUpdateOfferDecision.later.performDownload {
                self?.manager.downloadOfferedMap()
            }
        })
        alert.addAction(UIAlertAction(title: "Update Map", style: .default) { [weak self] _ in
            OfflineMapUpdateOfferDecision.update.performDownload {
                self?.manager.downloadOfferedMap()
            }
        })
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Map Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func title(for row: Row) -> String {
        switch row {
        case .status: return "Status"
        case .version: return "Map Version"
        case .date: return "Map Date"
        case .space: return "Space Used"
        case .wiFiOnly: return "Wi-Fi Only"
        case .checkForUpdate: return "Check for Update"
        case .cancelDownload: return "Cancel Download"
        case .remove: return "Remove Map"
        case .error: return "Last Error"
        case .primaryAction:
            switch manager.state.phase {
            case .availableToDownload: return "Download Map"
            case .updateAvailable: return "Update Map"
            case .failed: return "Try Again"
            default: return "Find Map"
            }
        }
    }

    private func detail(for row: Row) -> String? {
        let state = manager.state
        switch row {
        case .status:
            if state.phase == .downloading, state.bytesExpected > 0 {
                let percent = Int((Double(state.bytesReceived) / Double(state.bytesExpected)) * 100)
                return "Downloading — \(min(max(percent, 0), 100))%"
            }
            return statusText(state.phase)
        case .version:
            return state.activeMap?.mapVersion
        case .date:
            guard let activeMap = state.activeMap else { return nil }
            let date = activeMap.publishedAt ?? activeMap.installedAt
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        case .space:
            guard let bytes = state.activeMap?.totalBytes else { return nil }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .error:
            return state.lastError
        case .wiFiOnly:
            return state.isNetworkTransferActive
                ? "This cannot be changed while a map download is active."
                : "Turn this off to allow map downloads on cellular data. The change applies to the next download."
        default:
            return nil
        }
    }

    private func statusText(_ phase: OfflineMapPersistentState.Phase) -> String {
        switch phase {
        case .notInstalled: return "Not Installed"
        case .checkingManifest: return "Checking for Download"
        case .checkingForUpdate: return "Checking for Update"
        case .verifying: return "Verifying Download"
        case .availableToDownload: return "Ready to download"
        case .waitingForNetwork: return manager.wiFiOnly ? "Waiting for Wi-Fi" : "Waiting for Network"
        case .downloading: return "Downloading"
        case .installing: return "Installing"
        case .ready: return "Ready"
        case .updateAvailable: return "Update ready"
        case .failed: return "Fix needed"
        }
    }

    private func isAction(_ row: Row) -> Bool {
        row == .primaryAction || row == .cancelDownload || row == .checkForUpdate || row == .remove
    }
}
