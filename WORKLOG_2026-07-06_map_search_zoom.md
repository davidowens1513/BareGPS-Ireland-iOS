# Map Search Zoom Update

- Date: 2026-07-06
- Scope: map-based search selection in `Core/Map/MapViewController.swift`
- Change: search-triggered hill and start-place selection now use zoom `14.0`; other selection paths recenter on the tapped item at the current zoom, with clamped anchors and shared left-edge clearance
- Notes: preserved existing behavior that avoids zooming out if the current zoom is already closer than the target
