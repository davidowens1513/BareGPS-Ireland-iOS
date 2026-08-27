import CoreLocation
import MapLibre
import UIKit

extension ViewController {
    func goToTarget(for waypoint: SavedWaypoint) -> GoToTarget {
        let gridReference = irishNationalGridReference(for: waypoint.coordinate)
        let fallbackReference = String(format: "%.5f, %.5f", waypoint.latitude, waypoint.longitude)
        let subtitle = "Grid Ref: \(gridReference ?? fallbackReference)"
        return GoToTarget(title: waypoint.name, subtitle: subtitle, coordinate: waypoint.coordinate)
    }

    func presentMapLongPressActions(for coordinate: CLLocationCoordinate2D, sourcePoint: CGPoint) {
        let overlay = ActionOverlayViewController(
            title: "Map Point",
            actions: [
                .init(title: "Go To", style: .normal) { [weak self] in
                    self?.startGoTo(for: self?.goToTarget(for: coordinate) ?? GoToTarget(title: "Selected Map Point", subtitle: nil, coordinate: coordinate))
                },
                .init(title: "Save Waypoint", style: .normal) { [weak self] in
                    self?.presentSaveWaypointPrompt(for: coordinate)
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func presentSaveWaypointPrompt(for coordinate: CLLocationCoordinate2D) {
        let overlay = TextInputOverlayViewController(
            title: "Save Waypoint",
            placeholder: "Waypoint name",
            initialText: defaultSavedWaypointName(for: coordinate),
            confirmTitle: "Save"
        ) { [weak self] text in
            guard let self, !text.isEmpty else { return }
            self.saveWaypoint(named: text, coordinate: coordinate)
        }
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func defaultSavedWaypointName(for coordinate: CLLocationCoordinate2D) -> String {
        WaypointPresentation.defaultName(gridReference: irishNationalGridReference(for: coordinate))
    }

    func saveWaypoint(named name: String, coordinate: CLLocationCoordinate2D) {
        _ = savedWaypointController.saveWaypoint(named: name, coordinate: coordinate)
        reloadSavedWaypointAnnotations()
    }

    @discardableResult
    func updateWaypoint(_ waypoint: SavedWaypoint, withName name: String) -> SavedWaypoint? {
        let updatedWaypoint = savedWaypointController.updateWaypoint(waypoint, withName: name)
        reloadSavedWaypointAnnotations()
        return updatedWaypoint
    }

    @discardableResult
    func deleteWaypoint(_ waypoint: SavedWaypoint) -> Bool {
        let deleted = savedWaypointController.deleteWaypoint(waypoint)
        guard deleted else { return false }
        reloadSavedWaypointAnnotations()
        return true
    }

    func reloadSavedWaypointAnnotations() {
        if !savedWaypointAnnotations.isEmpty {
            mapView.removeAnnotations(savedWaypointAnnotations)
            savedWaypointAnnotations.removeAll()
        }

        let annotations = savedWaypointController.waypoints.map { waypoint in
            WaypointPresentation.annotation(
                for: waypoint,
                gridReference: irishNationalGridReference(for: waypoint.coordinate)
            )
        }

        savedWaypointAnnotations = annotations
        if !annotations.isEmpty {
            mapView.addAnnotations(annotations)
        }
    }

    func presentWaypointActions(for waypoint: SavedWaypoint, sourceAnnotation: MLNAnnotation) {
        let overlay = ActionOverlayViewController(
            title: waypoint.name,
            message: irishNationalGridReference(for: waypoint.coordinate),
            actions: [
                .init(title: "Go To", style: .normal) { [weak self] in
                    self?.startGoTo(for: self?.goToTarget(for: waypoint) ?? GoToTarget(title: waypoint.name, subtitle: nil, coordinate: waypoint.coordinate))
                },
                .init(title: "Rename", style: .normal) { [weak self] in
                    self?.presentRenameWaypointPrompt(waypoint)
                },
                .init(title: "Delete", style: .destructive) { [weak self] in
                    self?.deleteWaypoint(waypoint)
                },
                .init(title: "Cancel", style: .cancel, handler: {})
            ]
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func presentRenameWaypointPrompt(_ waypoint: SavedWaypoint, completion: ((SavedWaypoint?) -> Void)? = nil) {
        let overlay = TextInputOverlayViewController(
            title: "Rename Waypoint",
            placeholder: "Waypoint name",
            initialText: waypoint.name,
            confirmTitle: "Save",
            confirmHandler: { [weak self] text in
                guard let self, !text.isEmpty else { return }
                let updatedWaypoint = self.updateWaypoint(waypoint, withName: text)
                completion?(updatedWaypoint)
            },
            cancelHandler: {
                completion?(nil)
            }
        )
        topmostPresentingViewController().present(overlay, animated: true)
    }

    func sortedSavedWaypoints() -> [SavedWaypoint] {
        savedWaypointController.sortedWaypoints()
    }

    func waypointSubtitleText(for waypoint: SavedWaypoint) -> String {
        WaypointPresentation.subtitleText(
            for: waypoint,
            gridReference: irishNationalGridReference(for: waypoint.coordinate)
        )
    }

    func openWaypointOnMap(_ waypoint: SavedWaypoint) {
        mapView.setCenter(waypoint.coordinate, animated: true)
    }

    @objc func showWaypoints() {
        let waypointsViewController = WaypointsOverlayViewController(
            items: sortedSavedWaypoints(),
            subtitleProvider: { [weak self] waypoint in
                self?.waypointSubtitleText(for: waypoint) ?? ""
            },
            openHandler: { [weak self] waypoint in
                self?.openWaypointOnMap(waypoint)
            },
            goToHandler: { [weak self] waypoint in
                guard let self else { return }
                self.startGoTo(for: self.goToTarget(for: waypoint))
            },
            renameHandler: { [weak self] waypoint, completion in
                self?.presentRenameWaypointPrompt(waypoint, completion: completion)
            },
            deleteHandler: { [weak self] waypoint in
                self?.deleteWaypoint(waypoint) ?? false
            }
        )
        present(waypointsViewController, animated: true)
    }
}
