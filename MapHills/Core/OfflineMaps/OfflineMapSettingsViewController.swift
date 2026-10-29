import UIKit

final class OfflineMapSettingsViewController: UITableViewController {
    private enum Row: Hashable {
        case status
        case version
        case date
        case space
        case wiFiOnly
        case primaryAction
        case checkForUpdate
        case remove
        case error
    }

    private let manager: OfflineMapDownloadManager
    private var rows: [Row] = []
    private var observer: NSObjectProtocol?

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
            break
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
            toggle.addTarget(self, action: #selector(wiFiOnlyChanged(_:)), for: .valueChanged)
            toggle.accessibilityIdentifier = "offlineMapWiFiOnlySwitch"
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
            return "Use mobile data only when this is off."
        default:
            return nil
        }
    }

    private func statusText(_ phase: OfflineMapPersistentState.Phase) -> String {
        switch phase {
        case .notInstalled: return "Not Installed"
        case .checkingManifest, .checkingForUpdate, .verifying: return "Checking"
        case .availableToDownload: return "Ready to download"
        case .waitingForNetwork: return "Waiting for Wi-Fi"
        case .downloading: return "Downloading"
        case .installing: return "Installing"
        case .ready: return "Ready"
        case .updateAvailable: return "Update ready"
        case .failed: return "Fix needed"
        }
    }

    private func isAction(_ row: Row) -> Bool {
        row == .primaryAction || row == .checkForUpdate || row == .remove
    }
}
