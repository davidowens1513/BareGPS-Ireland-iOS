import CoreLocation
import UIKit

extension ViewController {
    @objc func showAbout() {
        let aboutViewController = AboutOverlayViewController(aboutText: regionDefinition.aboutText)
        present(aboutViewController, animated: true)
    }

    @objc func showWeather() {
        let centerCoordinate = mapView.centerCoordinate
        let weatherViewController = WeatherOverlayViewController(
            coordinate: centerCoordinate,
            locationTitle: weatherLocationTitle(for: centerCoordinate),
            displayUnitSystem: selectedDisplayUnitSystem,
            forecastProvider: { [weatherForecastService] coordinate in
                try await weatherForecastService.forecast(for: coordinate)
            }
        )
        topmostPresentingViewController().present(weatherViewController, animated: true)
    }

    func weatherLocationTitle(for coordinate: CLLocationCoordinate2D) -> String {
        if let selectedPeak = selectedPeak() {
            return selectedPeak.name
        }
        if let nearbyPeak = nearestPeak(from: filteredPeaks(), to: coordinate, withinMeters: 5_000) {
            return nearbyPeak.name
        }
        if let gridReference = irishNationalGridReference(for: coordinate) {
            return "Grid Ref: \(gridReference)"
        }
        return String(format: "Map centre %.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    func nearestPeak(to coordinate: CLLocationCoordinate2D, withinMeters maximumDistance: CLLocationDistance) -> Peak? {
        nearestPeak(from: peaks, to: coordinate, withinMeters: maximumDistance)
    }

    func nearestPeak(from candidatePeaks: [Peak], to coordinate: CLLocationCoordinate2D, withinMeters maximumDistance: CLLocationDistance) -> Peak? {
        let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var closestPeak: Peak?
        var closestDistance = maximumDistance

        for peak in candidatePeaks {
            let peakLocation = CLLocation(latitude: peak.latitude, longitude: peak.longitude)
            let distance = peakLocation.distance(from: centerLocation)
            if distance <= closestDistance {
                closestDistance = distance
                closestPeak = peak
            }
        }

        return closestPeak
    }

    func selectedPeak() -> Peak? {
        guard let selectedPeakID else { return nil }
        return peaks.first(where: { $0.id == selectedPeakID })
    }

    @objc func showRecords() {
        let recordsViewController = RecordsOverlayViewController(
            peaks: peaks,
            startPlaces: startPlaces,
            displayMode: .records,
            loggedPeakIDs: loggedPeakController.loggedPeakIDs,
            toggleLoggedStateHandler: { [weak self] peak, completion in
                self?.toggleLoggedState(for: peak, completion: completion)
            },
            openStartPlaceHandler: { [weak self] startPlace in
                self?.focusOnStartPlace(startPlace, invocationSource: .other)
            }
        )
        present(recordsViewController, animated: true)
    }

    @objc func showSearch() {
        dismissOpenHillAndStartPlaceCallouts()
        let searchViewController = RecordsOverlayViewController(
            peaks: peaks,
            startPlaces: startPlaces,
            displayMode: .search,
            loggedPeakIDs: loggedPeakController.loggedPeakIDs,
            toggleLoggedStateHandler: { [weak self] peak, completion in
                self?.toggleLoggedState(for: peak, completion: completion)
            },
            openStartPlaceHandler: { [weak self] startPlace in
                self?.focusOnStartPlace(
                    startPlace,
                    placementMode: .belowAnchor,
                    invocationSource: .search,
                    animated: false
                )
            }
        )
        present(searchViewController, animated: true)
    }

    func dismissOpenHillAndStartPlaceCallouts() {
        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
    }

    @objc func showSettings() {
        let settingsViewController = SettingsOverlayViewController(
            selectedDisplayUnitSystem: selectedDisplayUnitSystem,
            selectedMapOrientationMode: selectedMapOrientationMode,
            isMapInteractionLocked: isMapInteractionLocked,
            selectedTrackRecordingQuality: selectedTrackRecordingQuality,
            showsCompactRecordingGrid: showsCompactRecordingGrid,
            showsSnailTrail: showsSnailTrail,
            snailTrailColor: snailTrailColor,
            goToLineColor: goToLineColor,
            recordedTrackColor: recordedTrackColor,
            importedTrackColor: importedTrackColor,
            markerColorOptions: markerColorOptions(),
            showsHillMarkers: showsHillMarkers,
            visibleStartPlaceProviders: visibleStartPlaceProviders,
            startPlaceRouteLengthFilter: startPlaceRouteLengthFilter,
            localHundredConfiguration: localHundredConfiguration,
            currentPositionGridReference: currentLocalHundredPositionGridReference(),
            displayUnitSystemChangeHandler: { [weak self] displayUnitSystem in
                guard let self else { return }
                self.saveDisplayUnitSystem(displayUnitSystem)
                self.updateLiveGPXStatsCard()
                if let overlay = self.goToOverlayViewController {
                    self.updateGoToOverlayNavigation(for: overlay.target)
                }
                self.reloadPeakAnnotations()
            },
            mapOrientationModeChangeHandler: { [weak self] mapOrientationMode in
                self?.saveMapOrientationMode(mapOrientationMode)
            },
            mapInteractionLockChangeHandler: { [weak self] isLocked in
                self?.saveMapInteractionLocked(isLocked)
            },
            trackRecordingQualityChangeHandler: { [weak self] trackRecordingQuality in
                self?.saveTrackRecordingQuality(trackRecordingQuality)
            },
            compactRecordingGridChangeHandler: { [weak self] showsCompactRecordingGrid in
                self?.saveShowsCompactRecordingGrid(showsCompactRecordingGrid)
            },
            snailTrailVisibilityChangeHandler: { [weak self] showsSnailTrail in
                self?.saveShowsSnailTrail(showsSnailTrail)
            },
            snailTrailColorChangeHandler: { [weak self] color in
                self?.saveSnailTrailColor(color)
            },
            goToLineColorChangeHandler: { [weak self] color in
                self?.saveGoToLineColor(color)
            },
            recordedTrackColorChangeHandler: { [weak self] color in
                guard let self else { return }
                self.saveRecordedTrackColor(color)
                self.refreshTrailOverlay()
            },
            importedTrackColorChangeHandler: { [weak self] color in
                guard let self else { return }
                self.saveImportedTrackColor(color)
                self.refreshImportedGPXTrackAnnotations()
            },
            markerColorChangeHandler: { [weak self] id, color in
                guard let self else { return }
                self.saveMarkerColor(color, for: id)
                self.reloadPeakAnnotations()
                self.reloadStartPlaceAnnotations()
                self.reloadSavedWaypointAnnotations()
            },
            hillMarkerVisibilityChangeHandler: { [weak self] showsHillMarkers in
                self?.saveShowsHillMarkers(showsHillMarkers)
            },
            startPlaceProviderVisibilityChangeHandler: { [weak self] providers in
                self?.saveVisibleStartPlaceProviders(providers)
            },
            startPlaceRouteLengthFilterChangeHandler: { [weak self] filter in
                self?.saveStartPlaceRouteLengthFilter(filter)
            },
            startPlaceProviderCountProvider: { [weak self] provider, routeLengthFilter in
                self?.visibleStartPlaceCount(for: provider, routeLengthFilter: routeLengthFilter) ?? 0
            },
            localHundredFromGridReferenceHandler: { [weak self] input in
                guard let self else {
                    return .failure("Nearest 100 setup is unavailable right now.")
                }
                return self.configureLocalHundred(fromGridReference: input)
            },
            localHundredFromCurrentPositionHandler: { [weak self] in
                guard let self else {
                    return .failure("Nearest 100 setup is unavailable right now.")
                }
                return self.configureLocalHundredFromCurrentPosition()
            },
            localHundredResetHandler: { [weak self] in
                self?.clearLocalHundredConfiguration()
            }
        )
        settingsOverlayViewController = settingsViewController
        present(settingsViewController, animated: true)
    }

    @objc func showMenu() {
        let heightOptions = HeightFilterBand.allCases.map { band in
            MenuOption(
                id: band.rawValue,
                title: band.title,
                countText: "(\(peaks.filter { band.includes(height: $0.heightM) }.count))",
                isSelected: selectedHeightBands.contains(band)
            )
        }
        let classificationOptions = classificationSections(for: Set(allClassificationCodes())).flatMap { section in
            [MenuOption.sectionHeader(section.title)] + section.codes.map { code in
                let isLocalHundred = code == "L100"
                let isLocalHundredReady = localHundredConfiguration != nil
                let displayAbbreviation = abbreviatedHillCardClassificationName(for: code)
                let displayTitle = if let displayAbbreviation {
                    "\(classificationDisplayName(for: code)) (\(displayAbbreviation))"
                } else {
                    classificationDisplayName(for: code)
                }
                return MenuOption(
                    id: code,
                    title: displayTitle,
                    countText: isLocalHundred && !isLocalHundredReady
                        ? "(Set up)"
                        : "(\(peaks.filter { classificationCodes(for: $0).contains(code) }.count))",
                    isSelected: selectedClassificationCodes.contains(code),
                    isSectionHeader: false,
                    isEnabled: !isLocalHundred || isLocalHundredReady
                )
            }
        }

        let menuViewController = MenuOverlayViewController(
            selectedSchema: selectedFilterSchema,
            optionsBySchema: [
                .height: heightOptions,
                .classification: classificationOptions
            ],
            visibleHillCount: filteredPeaks().count,
            visibleHillCountProvider: { [weak self] in
                self?.filteredPeaks().count ?? 0
            },
            selectedMarkerColorSchema: selectedMarkerColorSchema,
            markerColorOptionsBySchema: [.classification: markerColorOptions()],
            toggleHandler: { [weak self] schema, id, isSelected in
                guard let self else { return }

                switch schema {
                case .height:
                    if isSelected {
                        self.selectedClassificationCodes.removeAll()
                    }
                    guard let band = HeightFilterBand(rawValue: id) else { return }
                    if isSelected {
                        self.selectedHeightBands.insert(band)
                    } else {
                        self.selectedHeightBands.remove(band)
                    }
                case .classification:
                    if isSelected {
                        self.selectedHeightBands.removeAll()
                    }
                    if isSelected {
                        self.selectedClassificationCodes.insert(id)
                    } else {
                        self.selectedClassificationCodes.remove(id)
                    }
                }

                self.persistFilterState()
                self.reloadPeakAnnotations()
                self.updateMenuFilterIndicatorAppearance()
            },
            schemaChangeHandler: { [weak self] schema in
                self?.selectedFilterSchema = schema
                self?.persistFilterState()
            },
            markerColorChangeHandler: { [weak self] id, color in
                guard let self else { return }
                self.saveMarkerColor(color, for: id)
                self.reloadPeakAnnotations()
                self.reloadStartPlaceAnnotations()
                self.reloadSavedWaypointAnnotations()
            },
            markerColorSchemaChangeHandler: { [weak self] schema in
                guard let self else { return }
                self.saveMarkerColorSchema(.classification)
                self.reloadPeakAnnotations()
            },
            filteredPeaksProvider: { [weak self] in
                self?.filteredPeaks() ?? []
            },
            isPeakLoggedProvider: { [weak self] peak in
                self?.isPeakLogged(peak) ?? false
            },
            classificationCodesProvider: { peak in
                classificationCodes(for: peak)
            },
            classificationDisplayNameProvider: { [weak self] code in
                self?.classificationDisplayName(for: code) ?? code
            },
            currentFilterDescriptionProvider: { [weak self] in
                self?.currentFilterDescriptionText() ?? "Filter unavailable"
            }
        )

        present(menuViewController, animated: true)
    }

    func showAdvancedFilterEditor() {
        let classificationOptions = allClassificationCodes().map { code in
            MenuOption(
                id: code,
                title: classificationDisplayName(for: code),
                countText: "(\(peaks.filter { classificationCodes(for: $0).contains(code) }.count))",
                isSelected: advancedHillFilter.selectedClassificationCodes.contains(code)
            )
        }

        let editorViewController = AdvancedFilterOverlayViewController(
            classificationOptions: classificationOptions,
            currentFilter: advancedHillFilter,
            savedPresets: savedAdvancedHillFilterPresets,
            applyHandler: { [weak self] filter in
                guard let self else { return }
                self.advancedHillFilter = filter
                self.selectedHillFilterMode = .advanced
                self.persistFilterState()
                self.reloadPeakAnnotations()
                self.updateMenuFilterIndicatorAppearance()
            },
            savePresetHandler: { [weak self] preset in
                guard let self else { return }
                if let existingIndex = self.savedAdvancedHillFilterPresets.firstIndex(where: { $0.id == preset.id }) {
                    self.savedAdvancedHillFilterPresets[existingIndex] = preset
                } else {
                    self.savedAdvancedHillFilterPresets.append(preset)
                }
                self.savedAdvancedHillFilterPresets.sort {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                self.persistFilterState()
            },
            deletePresetHandler: { [weak self] presetID in
                guard let self else { return }
                self.savedAdvancedHillFilterPresets.removeAll { $0.id == presetID }
                self.persistFilterState()
            }
        )

        topmostPresentingViewController().present(editorViewController, animated: true)
    }

    @objc func showCaching() {
        let cachingViewController = CachingOverlayViewController(
            actionTitleProvider: { [weak self] in
                guard let self else { return "Save Visible Area for Offline Use" }
                if self.offlinePack != nil {
                    return "Downloading…"
                }
                if !self.canCacheCurrentMapLayer() {
                    return "Offline Save Unavailable"
                }
                return "Save Visible Area for Offline Use"
            },
            cachedAreas: cachedOfflineAreas,
            actionHandler: { [weak self] in
                self?.downloadOffline()
            },
            selectHandler: { [weak self] area in
                self?.focusMap(on: area)
            },
            retryHandler: { [weak self] area, completion in
                self?.resumeCachedOfflineArea(area, completion: completion)
            },
            deleteAllHandler: { [weak self] completion in
                self?.confirmDeleteAllCachedOfflineAreas(completion: completion)
            },
            selectedDetailLevelProvider: { [weak self] in
                self?.selectedCacheDetailLevel ?? .standard
            },
            detailLevelChangeHandler: { [weak self] detailLevel in
                self?.selectedCacheDetailLevel = detailLevel
            },
            renameHandler: { [weak self] area, completion in
                self?.promptToRenameCachedOfflineArea(area, completion: completion)
            },
            deleteHandler: { [weak self] area, completion in
                self?.confirmDeleteCachedOfflineArea(area, completion: completion)
            }
        )
        present(cachingViewController, animated: true)
    }
}
