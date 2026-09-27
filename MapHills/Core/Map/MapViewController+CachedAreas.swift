import Foundation
import MapLibre
import UIKit

extension ViewController {
    func cachedOfflineArea(for id: String) -> CachedOfflineArea? {
        cachedOfflineAreas.first(where: { $0.id == id })
    }

    func showCachedAreaCallout(for annotation: MLNAnnotation, area: CachedOfflineArea) {
        dismissActiveHillCallout(animated: false)
        dismissActiveCachedAreaCallout(animated: false)

        let metrics = [
            area.detailLevel.title,
            area.status.title,
            ByteCountFormatter.string(fromByteCount: Int64(area.byteCount), countStyle: .file)
        ].joined(separator: " • ")

        let calloutView = CachedAreaCalloutView(
            annotation: annotation,
            title: area.name,
            metrics: metrics,
            primaryActionTitle: "Rename",
            primaryActionHandler: { [weak self] in
                guard let self else { return }
                self.dismissActiveCachedAreaCallout(animated: false)
                self.promptToRenameCachedOfflineArea(area) { updatedArea in
                    guard let updatedArea else { return }
                    self.showCachedAreaCallout(for: annotation, area: updatedArea)
                }
            },
            secondaryActionTitle: "Delete",
            secondaryActionHandler: { [weak self] in
                guard let self else { return }
                self.dismissActiveCachedAreaCallout(animated: false)
                self.confirmDeleteCachedOfflineArea(area) { _ in }
            }
        )

        let anchorPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
        let anchorRect = mapView.convert(
            CGRect(x: anchorPoint.x - 22, y: anchorPoint.y - 22, width: 44, height: 44),
            to: view
        )
        let constrainedRect = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 0, dy: 8)

        calloutView.presentCallout(
            from: anchorRect,
            in: view,
            constrainedTo: constrainedRect,
            animated: true
        )

        activeCachedAreaCalloutView = calloutView
        activeCachedAreaID = area.id
    }
}
