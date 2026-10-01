import MapLibre
import UIKit
import UniformTypeIdentifiers

extension ViewController {
    @objc func showGPXMenu() {
        let gpxViewController = GPXOverlayViewController(
            isRecordingProvider: { [weak self] in
                self?.isTrailRecording ?? false
            },
            hasRecordingProvider: { [weak self] in
                !(self?.recordedTrailPoints.isEmpty ?? true)
            },
            hasSavableRecordingProvider: { [weak self] in
                (self?.recordedTrailPoints.count ?? 0) > 1
            },
            hasImportedGPXProvider: { [weak self] in
                self?.hasImportedGPX() ?? false
            },
            canSaveImportedGPXProvider: { [weak self] in
                self?.canSaveCurrentImportedGPX() ?? false
            },
            isMapInteractionLockedProvider: { [weak self] in
                self?.isMapInteractionLocked ?? false
            },
            summaryProvider: { [weak self] in
                self?.currentGPXRecordingSummary()
            },
            distanceFormatter: { [weak self] in
                self?.formattedDistance($0) ?? ""
            },
            elevationFormatter: { [weak self] in
                self?.formattedElevation($0) ?? ""
            },
            accuracyProvider: { [weak self] in
                self?.formattedLiveGPXAccuracy(self?.mapView.userLocation?.location) ?? "u/a"
            },
            importHandler: { [weak self] in
                self?.importGPXFromFiles()
            },
            savedHandler: { [weak self] in
                self?.showSavedGPXRecordings()
            },
            waypointsHandler: { [weak self] in
                self?.showWaypoints()
            },
            saveImportedHandler: { [weak self] in
                self?.promptForImportedGPXNameAndSave()
            },
            clearImportedHandler: { [weak self] in
                self?.clearImportedGPX()
            },
            mapInteractionLockChangeHandler: { [weak self] isLocked in
                self?.saveMapInteractionLocked(isLocked)
            },
            primaryRecordingHandler: { [weak self] in
                guard let self else { return }
                self.beginTrailRecordingFlow(startMode: .standard)
            },
            stopRecordingHandler: { [weak self] in
                guard let self else { return }
                self.stopTrailRecording()
            },
            saveHandler: { [weak self] in
                self?.promptForGPXRecordingNameAndSave()
            },
            discardHandler: { [weak self] in
                self?.discardTrailRecording()
            }
        )
        gpxOverlayViewController = gpxViewController
        present(gpxViewController, animated: true)
    }

    @objc func importGPXFromFiles() {
        let gpxType = UTType(filenameExtension: "gpx") ?? .xml
        let pickerViewController = UIDocumentPickerViewController(
            forOpeningContentTypes: [gpxType],
            asCopy: true
        )
        pickerViewController.delegate = self
        pickerViewController.allowsMultipleSelection = false
        present(pickerViewController, animated: true)
    }

    @objc func showSavedGPXRecordings() {
        let recordingsViewController = SavedGPXRecordingsOverlayViewController(
            items: savedGPXRecordingItems(),
            openHandler: { [weak self] fileURL in
                self?.importGPX(from: fileURL)
            },
            shareHandler: { [weak self] fileURL in
                self?.shareGPXFile(fileURL)
            },
            renameHandler: { [weak self] fileURL, completion in
                self?.renameSavedGPXFile(fileURL, completion: completion)
            },
            deleteHandler: { [weak self] fileURL in
                self?.deleteSavedGPXFile(fileURL) ?? false
            }
        )
        present(recordingsViewController, animated: true)
    }
}
