//
//  MapViewController+Annotations.swift
//  Maphills
//
//  Created by Codex on 07/07/2026.
//

import Foundation
import MapLibre
import UIKit

struct StartPlaceAnnotationLayoutItem {
    let key: String
    let startPlace: StartPlace
    let latitude: Double
    let longitude: Double
}

enum StartPlaceAnnotationLayout {
    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    /// Preserves the previous "first group anchor within five metres" behaviour,
    /// but only examines anchors in neighbouring five-metre spatial buckets.
    static func makeItems(from places: [StartPlace]) -> [StartPlaceAnnotationLayoutItem] {
        makeGroups(from: places).flatMap { group in
            group.enumerated().map { index, startPlace in
                let coordinate = displayCoordinate(for: startPlace, at: index, groupCount: group.count)
                return StartPlaceAnnotationLayoutItem(
                    key: selectionKey(for: startPlace),
                    startPlace: startPlace,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        }
    }

    static func makeGroups(from places: [StartPlace]) -> [[StartPlace]] {
        let sortedPlaces = places.sorted {
            if $0.provider != $1.provider {
                return $0.provider.rawValue < $1.provider.rawValue
            }
            return $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }

        let referenceLatitudeRadians = 53.5 * .pi / 180
        let metresPerLongitudeDegree = 111_320.0 * cos(referenceLatitudeRadians)
        let bucketSizeMetres = 5.0
        var groups: [[StartPlace]] = []
        var anchorBuckets: [Cell: [Int]] = [:]

        func cell(for place: StartPlace) -> Cell {
            Cell(
                x: Int(floor(place.longitude * metresPerLongitudeDegree / bucketSizeMetres)),
                y: Int(floor(place.latitude * 111_320.0 / bucketSizeMetres))
            )
        }

        for place in sortedPlaces {
            let placeCell = cell(for: place)
            var candidateGroupIndices: [Int] = []
            // Projection scale varies slightly across Ireland. Two cells of
            // padding keeps every possible five-metre neighbour in scope.
            for xOffset in -2...2 {
                for yOffset in -2...2 {
                    candidateGroupIndices.append(contentsOf: anchorBuckets[
                        Cell(x: placeCell.x + xOffset, y: placeCell.y + yOffset)
                    ] ?? [])
                }
            }

            let matchingGroupIndex = candidateGroupIndices.sorted().first { groupIndex in
                guard let anchor = groups[groupIndex].first else { return false }
                return distanceMeters(from: place, to: anchor) <= bucketSizeMetres
            }

            if let matchingGroupIndex {
                groups[matchingGroupIndex].append(place)
            } else {
                let groupIndex = groups.count
                groups.append([place])
                anchorBuckets[placeCell, default: []].append(groupIndex)
            }
        }

        return groups
    }

    private static func distanceMeters(from lhs: StartPlace, to rhs: StartPlace) -> Double {
        let latitude1 = lhs.latitude * .pi / 180
        let latitude2 = rhs.latitude * .pi / 180
        let latitudeDelta = latitude2 - latitude1
        let longitudeDelta = (rhs.longitude - lhs.longitude) * .pi / 180
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2) * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return 6_371_000 * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }

    private static func displayCoordinate(
        for startPlace: StartPlace,
        at index: Int,
        groupCount: Int
    ) -> CLLocationCoordinate2D {
        guard groupCount > 1, index > 0 else { return startPlace.coordinate }
        let offsetCount = max(groupCount - 1, 1)
        let radius = min(24.0, 14.0 + Double(groupCount) * 1.5)
        let angle = 2 * Double.pi * Double(index - 1) / Double(offsetCount)
        let north = sin(angle) * radius
        let east = cos(angle) * radius
        let latitudeDelta = north / 111_320.0
        let metresPerLongitudeDegree = 111_320.0 * max(cos(startPlace.latitude * .pi / 180), 0.0001)
        return CLLocationCoordinate2D(
            latitude: startPlace.latitude + latitudeDelta,
            longitude: startPlace.longitude + east / metresPerLongitudeDegree
        )
    }

    private static func selectionKey(for startPlace: StartPlace) -> String {
        let latitude = String(format: "%.6f", startPlace.latitude)
        let longitude = String(format: "%.6f", startPlace.longitude)
        return "\(startPlace.provider.rawValue)|\(startPlace.id)|\(latitude)|\(longitude)"
    }
}

extension ViewController {

    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
        annotation is GPXWaypointAnnotation
    }

    func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
        if annotation is StartPlaceSelectionAnnotation {
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }

        if let irelandPlaceAnnotation = annotation as? IrelandPlaceSelectionAnnotation,
           irelandPlaceAnnotation.place != nil {
            return
        }

        if annotation is GoToPolyline {
            mapView.deselectAnnotation(annotation, animated: false)
            guard activeGoToTarget != nil else { return }
            presentCancelGoToConfirmation()
            return
        }

        if annotation is GoToTargetAnnotation {
            mapView.deselectAnnotation(annotation, animated: false)
            guard activeGoToTarget != nil else { return }
            presentCancelGoToConfirmation()
            return
        }

        if annotation is CoillteTrailPolyline || annotation is SportIrelandTrailPolyline || annotation is OutscapeTrailPolyline {
            mapView.deselectAnnotation(annotation, animated: false)
            presentSelectedProviderTrailActions()
            return
        }

        if let startPlaceAnnotation = annotation as? StartPlaceAnnotation,
           let startPlace = startPlaceAnnotation.startPlace {
            guard !isRefreshingStartPlaceSelectionState else { return }
            let previousStartPlaceSelectionKey = selectedStartPlaceKey
            let startPlaceSelectionKey = selectionKey(for: startPlace)
            selectedStartPlaceKey = startPlaceSelectionKey
            isRefreshingStartPlaceSelectionState = true
            if let previousStartPlaceSelectionKey,
               previousStartPlaceSelectionKey != startPlaceSelectionKey {
                _ = refreshStartPlaceAnnotation(forSelectionKey: previousStartPlaceSelectionKey)
            }
            let refreshedAnnotation = refreshStartPlaceAnnotation(forSelectionKey: startPlaceSelectionKey)
                ?? self.startPlaceAnnotation(forSelectionKey: startPlaceSelectionKey)
            if let refreshedAnnotation {
                mapView.selectAnnotation(refreshedAnnotation, animated: false, completionHandler: nil)
            }
            isRefreshingStartPlaceSelectionState = false

            let activeAnnotation = refreshedAnnotation ?? startPlaceAnnotation
            guard let startPlaceForHalo = activeAnnotation.startPlace else { return }
            showSelectedStartPlaceHalo(for: activeAnnotation)
            let placementMode = pendingStartPlaceCalloutPlacementMode ?? .belowAnchor
            pendingStartPlaceCalloutPlacementMode = nil
            positionCoordinateForCallout(startPlaceForHalo.coordinate)
            showStartPlaceCallout(for: activeAnnotation, placementMode: placementMode)
            return
        }

        if let savedWaypointAnnotation = annotation as? SavedWaypointAnnotation,
           let waypoint = savedWaypointAnnotation.waypoint {
            mapView.deselectAnnotation(annotation, animated: false)
            presentWaypointActions(for: waypoint, sourceAnnotation: annotation)
            return
        }

        guard let transition = peakAnnotationPresentationStore.selectionTransition(
            for: annotation,
            isRefreshingSelectionState: isRefreshingSelectionState
        ) else { return }

        dismissActiveHillCallout(animated: false)
        dismissActiveStartPlaceCallout(animated: false)
        selectedPeakID = transition.selectedPeakID
        isRefreshingSelectionState = true
        reloadPeakAnnotations(selecting: transition.selectedPeakID)
        isRefreshingSelectionState = false

        guard let calloutPeakID = transition.calloutPeakID else { return }
        if let peakAnnotation = annotation as? PeakAnnotation,
           let peak = peakAnnotation.peak {
            positionCoordinateForCallout(peak.coordinate)
            presentHillCalloutWhenReady(for: peak, placementMode: .belowAnchor, selectionToken: pendingPeakCalloutSelectionToken)
            return
        }
        presentHillCalloutWhenReady(forPeakID: calloutPeakID)
    }

    func mapView(_ mapView: MLNMapView, didDeselect annotation: MLNAnnotation) {
        if annotation is StartPlaceSelectionAnnotation { return }

        if annotation is IrelandPlaceSelectionAnnotation {
            return
        }

        if let startPlaceAnnotation = annotation as? StartPlaceAnnotation,
           let startPlace = startPlaceAnnotation.startPlace {
            guard !isRefreshingStartPlaceSelectionState else { return }
            let deselectedStartPlaceSelectionKey = selectionKey(for: startPlace)
            dismissActiveStartPlaceCallout(animated: false)
            removeSelectedStartPlaceHalo()
            selectedStartPlaceKey = nil
            isRefreshingStartPlaceSelectionState = true
            _ = refreshStartPlaceAnnotation(forSelectionKey: deselectedStartPlaceSelectionKey)
            isRefreshingStartPlaceSelectionState = false
            return
        }

        guard let transition = peakAnnotationPresentationStore.deselectionTransition(
            for: annotation,
            selectedPeakID: selectedPeakID,
            isRefreshingSelectionState: isRefreshingSelectionState
        ) else { return }

        dismissActiveHillCallout(animated: false)
        selectedPeakID = transition.selectedPeakID
        isRefreshingSelectionState = true
        reloadPeakAnnotations()
        isRefreshingSelectionState = false
    }

    func mapView(_ mapView: MLNMapView, calloutViewFor annotation: MLNAnnotation) -> MLNCalloutView? {
        nil
    }

    func mapView(_ mapView: MLNMapView, imageFor annotation: MLNAnnotation) -> MLNAnnotationImage? {
        let zoomPresentation = MapAnnotationImages.ZoomPresentation(zoomLevel: mapView.zoomLevel)

        if let haloAnnotation = annotation as? StartPlaceSelectionAnnotation {
            let reuseIdentifier = "start-place-selection-\(colorCacheKey(for: haloAnnotation.markerColor))-\(zoomPresentation.rawValue)"
            if let existingImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                return existingImage
            }

            return MLNAnnotationImage(
                image: zoomDependentStartPlaceImage(
                    markerColor: haloAnnotation.markerColor,
                    isSelected: true,
                    zoomPresentation: zoomPresentation
                ),
                reuseIdentifier: reuseIdentifier
            )
        }

        if let startPlaceAnnotation = annotation as? StartPlaceAnnotation,
           let startPlace = startPlaceAnnotation.startPlace {
            startPlaceAnnotation.zoomPresentationRawValue = zoomPresentation.rawValue
            let startPlaceSelectionKey = selectionKey(for: startPlace)
            let isSelected = startPlaceSelectionKey == selectedStartPlaceKey
            let startPlaceMarkerColor = markerColor(for: startPlace)
            let selectionStateKey = isSelected ? "selected" : "normal"
            let reuseIdentifier = "start-place-\(startPlace.provider.rawValue)-\(colorCacheKey(for: startPlaceMarkerColor))-\(selectionStateKey)-\(zoomPresentation.rawValue)"
            if let existingImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                return existingImage
            }

            return MLNAnnotationImage(
                image: startPlaceAnnotationImage(
                    for: startPlace,
                    isSelected: isSelected,
                    zoomPresentation: zoomPresentation
                ),
                reuseIdentifier: reuseIdentifier
            )
        }

        if annotation is IrelandPlaceSelectionAnnotation {
            let reuseIdentifier = "ireland-place-selection"
            if let existingImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                return existingImage
            }

            return MLNAnnotationImage(
                image: MapAnnotationImages.goToTargetMarkerImage(color: .systemGreen),
                reuseIdentifier: reuseIdentifier
            )
        }

        if annotation is GoToTargetAnnotation {
            let reuseIdentifier = "goto-target"
            if let existingImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                existingImage.image = goToTargetAnnotationImage()
                return existingImage
            }

            return MLNAnnotationImage(
                image: goToTargetAnnotationImage(),
                reuseIdentifier: reuseIdentifier
            )
        }

        if annotation is SavedWaypointAnnotation {
            let reuseIdentifier = "saved-waypoint"
            if let existingImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                existingImage.image = savedWaypointAnnotationImage()
                return existingImage
            }

            return MLNAnnotationImage(
                image: savedWaypointAnnotationImage(),
                reuseIdentifier: reuseIdentifier
            )
        }

        guard let peakAnnotation = annotation as? PeakAnnotation,
              let peak = peakAnnotation.peak else {
            return nil
        }
        peakAnnotation.zoomPresentationRawValue = zoomPresentation.rawValue

        let isLogged = isPeakLogged(peak)
        let isSelected = peakAnnotationPresentationStore.isSelectedPeak(peak, selectedPeakID: selectedPeakID)
        let optionID = markerColorOptionID(for: peak, isLogged: isLogged)
        let colorKey = colorCacheKey(for: resolvedMarkerColor(for: optionID, defaultColor: defaultMarkerColor(for: optionID)))
        let selectionKey = isSelected ? "selected" : "normal"
        let reuseIdentifier = "\(optionID)-peak-annotation-\(colorKey)-\(selectionKey)-\(zoomPresentation.rawValue)"

        if let existingImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
            return existingImage
        }

        return MLNAnnotationImage(
            image: annotationImage(
                for: peak,
                isLogged: isLogged,
                isSelected: isSelected,
                zoomPresentation: zoomPresentation
            ),
            reuseIdentifier: reuseIdentifier
        )
    }

    func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
        if annotation is GoToPolyline {
            return goToLineColor.withAlphaComponent(0.95)
        }

        if annotation is CachedAreaBorderPolyline {
            return UIColor.systemGreen
        }

        if annotation is CachedAreaPolygon {
            return UIColor.systemGreen.withAlphaComponent(0.95)
        }

        if annotation is TrailPolyline {
            return recordedTrackColor
        }

        if annotation is BreadcrumbPolyline {
            return snailTrailColor
        }

        if annotation is ImportedGPXPolyline {
            return importedTrackColor
        }

        if annotation is CoillteTrailPolyline {
            return resolvedMarkerColor(for: "coillteStartPoints", defaultColor: .systemBrown)
        }

        if annotation is SportIrelandTrailPolyline {
            return resolvedMarkerColor(for: "sportIrelandStartPoints", defaultColor: .systemPurple)
        }

        if annotation is OutscapeTrailPolyline {
            return resolvedMarkerColor(for: "outscapeStartPoints", defaultColor: .systemOrange)
        }

        if annotation is MLNPolyline {
            return .systemBlue
        }

        return .systemBlue
    }

    func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
        if annotation is GoToPolyline {
            return 4
        }

        if annotation is CachedAreaBorderPolyline {
            return 5
        }

        if annotation is TrailPolyline {
            return 4
        }

        if annotation is BreadcrumbPolyline {
            return 3
        }

        if annotation is CoillteTrailPolyline {
            return 5
        }

        if annotation is SportIrelandTrailPolyline {
            return 5
        }

        if annotation is OutscapeTrailPolyline {
            return 5
        }

        return 3
    }

    func mapView(_ mapView: MLNMapView, fillColorForPolygonAnnotation annotation: MLNPolygon) -> UIColor {
        if annotation is CachedAreaPolygon {
            return UIColor.systemGreen.withAlphaComponent(0.16)
        }

        return UIColor.systemBlue.withAlphaComponent(0.08)
    }

    func mapView(_ mapView: MLNMapView, alphaForShapeAnnotation annotation: MLNShape) -> CGFloat {
        if annotation is CachedAreaPolygon {
            return 1
        }

        return 1
    }
    // MARK: - Peak Annotations

    func addPeakAnnotations() {
        guard showsHillMarkers else {
            showHillCountOverlay(for: 0)
            return
        }

        let visiblePeaks = filteredPeaks()
        let annotations = peakAnnotationPresentationStore.makePeakAnnotations(
            from: visiblePeaks,
            subtitleProvider: { [weak self] peak in
                self?.subtitle(for: peak) ?? ""
            }
        )

        // Add all pins to the map in one go.
        mapView.addAnnotations(annotations)
        showHillCountOverlay(for: visiblePeaks.count)
    }

    func addStartPlaceAnnotations() {
        scheduleStartPlaceAnnotationLayout(forceImageRefresh: false)
    }

    func visibleStartPlaceCount(for provider: StartPlaceProvider, routeLengthFilter: StartPlaceRouteLengthFilter) -> Int {
        startPlaces.filter { startPlace in
            startPlace.provider == provider
                && startPlacePassesRouteLengthFilter(startPlace, routeLengthFilter: routeLengthFilter)
        }.count
    }

    func groupedOverlappingStartPlaces(_ places: [StartPlace]) -> [[StartPlace]] {
        StartPlaceAnnotationLayout.makeGroups(from: places)
    }

    func displayCoordinate(for startPlace: StartPlace, at index: Int, inGroupOf groupCount: Int) -> CLLocationCoordinate2D {
        guard groupCount > 1, index > 0 else {
            return startPlace.coordinate
        }

        let offsetCount = max(groupCount - 1, 1)
        let offsetRadiusMeters = min(24.0, 14.0 + Double(groupCount) * 1.5)
        let angle = (2 * Double.pi * Double(index - 1)) / Double(offsetCount)
        let northOffsetMeters = sin(angle) * offsetRadiusMeters
        let eastOffsetMeters = cos(angle) * offsetRadiusMeters
        return coordinate(startPlace.coordinate, offsetByNorthMeters: northOffsetMeters, eastMeters: eastOffsetMeters)
    }

    func coordinate(_ coordinate: CLLocationCoordinate2D, offsetByNorthMeters northMeters: CLLocationDistance, eastMeters: CLLocationDistance) -> CLLocationCoordinate2D {
        let metersPerLatitudeDegree = 111_320.0
        let latitudeDelta = northMeters / metersPerLatitudeDegree
        let latitudeRadians = coordinate.latitude * Double.pi / 180
        let metersPerLongitudeDegree = metersPerLatitudeDegree * max(cos(latitudeRadians), 0.0001)
        let longitudeDelta = eastMeters / metersPerLongitudeDegree
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeDelta,
            longitude: coordinate.longitude + longitudeDelta
        )
    }

    func reloadStartPlaceAnnotations(forceImageRefresh: Bool = false) {
        let wasRefreshingStartPlaceSelectionState = isRefreshingStartPlaceSelectionState
        isRefreshingStartPlaceSelectionState = true
        defer {
            isRefreshingStartPlaceSelectionState = wasRefreshingStartPlaceSelectionState
        }
        scheduleStartPlaceAnnotationLayout(forceImageRefresh: forceImageRefresh)
    }

    private func scheduleStartPlaceAnnotationLayout(forceImageRefresh: Bool) {
        startPlaceAnnotationLayoutGeneration += 1
        let generation = startPlaceAnnotationLayoutGeneration
        startPlaceAnnotationLayoutWorkItem?.cancel()
        let places = displayedStartPlaces()

        let workItem = DispatchWorkItem { [weak self] in
            let items = StartPlaceAnnotationLayout.makeItems(from: places)
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.startPlaceAnnotationLayoutGeneration else { return }
                self.applyStartPlaceAnnotationLayout(items, forceImageRefresh: forceImageRefresh)
            }
        }
        startPlaceAnnotationLayoutWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    private func applyStartPlaceAnnotationLayout(
        _ items: [StartPlaceAnnotationLayoutItem],
        forceImageRefresh: Bool
    ) {
        let existing = startPlaceAnnotations(from: mapView.annotations)
        var existingByKey: [String: StartPlaceAnnotation] = [:]
        for annotation in existing {
            guard let startPlace = annotation.startPlace else { continue }
            existingByKey[selectionKey(for: startPlace)] = annotation
        }
        let desiredKeys = Set(items.map(\.key))
        var removals = existing.filter { annotation in
            guard let startPlace = annotation.startPlace else { return true }
            return forceImageRefresh || !desiredKeys.contains(selectionKey(for: startPlace))
        }
        var additions: [StartPlaceAnnotation] = []
        let presentation = MapAnnotationImages.ZoomPresentation(zoomLevel: mapView.zoomLevel)

        for item in items {
            let coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
            if !forceImageRefresh,
               let annotation = existingByKey.removeValue(forKey: item.key),
               abs(annotation.coordinate.latitude - coordinate.latitude) < 0.0000001,
               abs(annotation.coordinate.longitude - coordinate.longitude) < 0.0000001 {
                continue
            }
            if let annotation = existingByKey.removeValue(forKey: item.key),
               !removals.contains(where: { $0 === annotation }) {
                removals.append(annotation)
            }
            let annotation = StartPlaceAnnotation()
            annotation.coordinate = coordinate
            annotation.title = item.startPlace.shortDisplayName
            annotation.startPlace = item.startPlace
            annotation.zoomPresentationRawValue = presentation.rawValue
            additions.append(annotation)
        }

        if !removals.isEmpty {
            deselectAnnotationsBeforeRemoval(removals)
            mapView.removeAnnotations(removals)
        }
        if forceImageRefresh { startPlaceMarkerImageCache.removeAll() }
        if !additions.isEmpty { mapView.addAnnotations(additions) }

        if let selectedStartPlaceKey,
           let annotation = startPlaceAnnotation(forSelectionKey: selectedStartPlaceKey) {
            mapView.selectAnnotation(annotation, animated: false, completionHandler: nil)
            showSelectedStartPlaceHalo(for: annotation)
        }
    }

    func startPlacePassesRouteLengthFilter(
        _ startPlace: StartPlace,
        routeLengthFilter: StartPlaceRouteLengthFilter? = nil
    ) -> Bool {
        startPlaceWalkSummaryProvider.startPlacePassesRouteLengthFilter(
            startPlace,
            routeLengthFilter: routeLengthFilter ?? startPlaceRouteLengthFilter
        )
    }

    func routeLengthPassesFilter(
        _ lengthMeters: Double?,
        routeLengthFilter: StartPlaceRouteLengthFilter? = nil
    ) -> Bool {
        StartPlaceWalkSummaryProvider.routeLengthPassesFilter(
            lengthMeters,
            routeLengthFilter: routeLengthFilter ?? startPlaceRouteLengthFilter
        )
    }

    func showSelectedStartPlaceHalo(for annotation: StartPlaceAnnotation) {
        removeSelectedStartPlaceHalo()
        guard let startPlace = annotation.startPlace else { return }
        let haloAnnotation = StartPlaceSelectionAnnotation()
        haloAnnotation.coordinate = annotation.coordinate
        haloAnnotation.markerColor = markerColor(for: startPlace)
        selectedStartPlaceHaloAnnotation = haloAnnotation
        mapView.addAnnotation(haloAnnotation)
    }

    func removeSelectedStartPlaceHalo() {
        if let selectedStartPlaceHaloAnnotation {
            mapView.removeAnnotation(selectedStartPlaceHaloAnnotation)
            self.selectedStartPlaceHaloAnnotation = nil
        }
    }

    func reloadStartPlaceAnnotationsPreservingSelection() {
        isRefreshingStartPlaceSelectionState = true
        reloadStartPlaceAnnotations()
        isRefreshingStartPlaceSelectionState = false
    }

    func refreshZoomDependentAnnotationImages() {
        let presentation = MapAnnotationImages.ZoomPresentation(zoomLevel: mapView.zoomLevel)
        let previousPresentation = annotationZoomPresentation
        annotationZoomPresentation = presentation
        guard previousPresentation != nil else { return }
        refreshVisibleAnnotations(for: presentation)
    }

    private func refreshVisibleAnnotations(for presentation: MapAnnotationImages.ZoomPresentation) {
        let bounds = mapView.visibleCoordinateBounds
        let allAnnotations = mapView.annotations ?? []
        let visibleStartPlaces = allAnnotations.compactMap { $0 as? StartPlaceAnnotation }.filter {
            coordinate($0.coordinate, isInside: bounds)
                && $0.zoomPresentationRawValue != presentation.rawValue
        }
        let visiblePeaks = allAnnotations.compactMap { $0 as? PeakAnnotation }.filter {
            coordinate($0.coordinate, isInside: bounds)
                && $0.zoomPresentationRawValue != presentation.rawValue
        }

        let startPlaceReplacements = visibleStartPlaces.compactMap { annotation -> StartPlaceAnnotation? in
            guard let startPlace = annotation.startPlace else { return nil }
            let replacement = StartPlaceAnnotation()
            replacement.coordinate = annotation.coordinate
            replacement.title = annotation.title
            replacement.subtitle = annotation.subtitle
            replacement.startPlace = startPlace
            replacement.zoomPresentationRawValue = presentation.rawValue
            return replacement
        }
        let peakReplacements = visiblePeaks.compactMap { annotation -> PeakAnnotation? in
            guard let peak = annotation.peak else { return nil }
            let replacement = PeakAnnotation()
            replacement.coordinate = annotation.coordinate
            replacement.title = annotation.title
            replacement.subtitle = annotation.subtitle
            replacement.peak = peak
            replacement.zoomPresentationRawValue = presentation.rawValue
            return replacement
        }

        let removals: [MLNAnnotation] = visibleStartPlaces + visiblePeaks
        let additions: [MLNAnnotation] = startPlaceReplacements + peakReplacements
        guard !removals.isEmpty else { return }
        isRefreshingSelectionState = true
        isRefreshingStartPlaceSelectionState = true
        mapView.removeAnnotations(removals)
        mapView.addAnnotations(additions)
        isRefreshingSelectionState = false
        isRefreshingStartPlaceSelectionState = false

        if let selectedStartPlaceKey,
           let annotation = startPlaceAnnotation(forSelectionKey: selectedStartPlaceKey) {
            mapView.selectAnnotation(annotation, animated: false, completionHandler: nil)
            showSelectedStartPlaceHalo(for: annotation)
        }
        if let selectedPeakID,
           let annotation = peakAnnotationPresentationStore.peakAnnotation(for: selectedPeakID, in: mapView.annotations) {
            mapView.selectAnnotation(annotation, animated: false, completionHandler: nil)
        }
    }

    private func coordinate(_ coordinate: CLLocationCoordinate2D, isInside bounds: MLNCoordinateBounds) -> Bool {
        coordinate.latitude >= bounds.sw.latitude
            && coordinate.latitude <= bounds.ne.latitude
            && coordinate.longitude >= bounds.sw.longitude
            && coordinate.longitude <= bounds.ne.longitude
    }

    func filteredPeaks() -> [Peak] {
        hillFilterEngine.filteredPeaks(
            from: peaks,
            mode: .simple,
            schema: selectedFilterSchema,
            selectedHeightBands: selectedHeightBands,
            selectedClassificationCodes: selectedClassificationCodes,
            advancedHillFilter: advancedHillFilter
        )
    }

    func advancedFilterSummaryText() -> String {
        hillFilterEngine.advancedFilterSummaryText(advancedHillFilter)
    }

    func currentFilterDescriptionText() -> String {
        switch selectedFilterSchema {
        case .classification:
            guard !selectedClassificationCodes.isEmpty else {
                return "Classification • All classifications"
            }
            let names = classificationSections(for: selectedClassificationCodes)
                .flatMap(\.codes)
                .map { classificationDisplayName(for: $0) }
            return "Classification • \(names.joined(separator: ", "))"
        case .height:
            guard !selectedHeightBands.isEmpty else {
                return "Height • All heights"
            }
            let titles = HeightFilterBand.allCases
                .filter { selectedHeightBands.contains($0) }
                .map(\.title)
            return "Height • \(titles.joined(separator: ", "))"
        }
    }

    func reloadPeakAnnotations(selecting peakID: String? = nil) {
        // Peak marker artwork depends on logged/selected state, so we rebuild the
        // peak annotations when those states change rather than mutating in place.
        removePeakAnnotations()

        addPeakAnnotations()

        guard
            let peakID,
            let refreshedAnnotation = peakAnnotationPresentationStore.peakAnnotation(for: peakID, in: mapView.annotations)
        else {
            return
        }

        mapView.selectAnnotation(refreshedAnnotation, animated: false, completionHandler: nil)
    }

    func saveShowsHillMarkers(_ showsHillMarkers: Bool) {
        self.showsHillMarkers = showsHillMarkers
        preferencesStore.saveShowsHillMarkers(showsHillMarkers)
        if !showsHillMarkers {
            selectedPeakID = nil
            mapView.selectedAnnotations = []
            dismissActiveHillCallout(animated: false)
            removePeakAnnotations()
        } else {
            reloadPeakAnnotations()
        }
    }

    func removePeakAnnotations() {
        let existingAnnotations = peakAnnotationPresentationStore.peakAnnotations(from: mapView.annotations)
        if !existingAnnotations.isEmpty {
            mapView.removeAnnotations(existingAnnotations)
        }
    }

    func peakAnnotation(for peakID: String) -> PeakAnnotation? {
        peakAnnotationPresentationStore.peakAnnotation(for: peakID, in: mapView.annotations)
    }

    func startPlaceAnnotations(from annotations: [MLNAnnotation]?) -> [StartPlaceAnnotation] {
        annotations?.compactMap { $0 as? StartPlaceAnnotation } ?? []
    }

    func dismissActiveHillCallout(animated: Bool) {
        activeHillCalloutView?.dismissCallout(animated: animated)
        activeHillCalloutView = nil
    }

    func dismissActiveStartPlaceCallout(animated: Bool) {
        activeStartPlaceCalloutView?.dismissCallout(animated: animated)
        activeStartPlaceCalloutView = nil
    }

    func dismissActiveCachedAreaCallout(animated: Bool) {
        activeCachedAreaCalloutView?.dismissCallout(animated: animated)
        activeCachedAreaCalloutView = nil
        activeCachedAreaID = nil
    }


}
