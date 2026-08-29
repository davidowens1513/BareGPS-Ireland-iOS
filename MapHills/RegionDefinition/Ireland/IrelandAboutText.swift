enum IrelandAboutText {
    static let text = """

Overview
\(AppBranding.displayName) helps you explore and log hills across Ireland. The app uses hill data and hill lists provided by MountainViews.ie, with start-place and trail information from MountainViews.ie, Coillte, Sport Ireland and Outdoor Recreation NI / Outscape.

The app provides full GPX recording, importing, Go-To and saving and exporting/sharing facilities. It provides a bespoke bundled hiking-focused layer (OpenOnzyMap) to ensure coverage in areas of reduced cellular signal, as well as providing caching to allow offline access to OpenTopo Map or Satellite layers.

This is free software. Comments and requests are welcome.

Features
The app allows you to:
- import, record, save, reopen, and share GPX tracks, with selectable recording detail levels.

- Access a bundled offline-safe Hiking map (OpenOnzyMap).

- cache the visible map area (OpenTopoMap or Satellite) for offline use, with saved cache sizes, statuses, retry/resume support, and reusable named cached areas.

- switch between north-up and heads-up map orientation, with a live position and heading indicator on the map.

- customise hill marker colours and recorded and imported track colours.

- show hills on a live map using simple filters, based on hill categories or height. 

- use either metric or imperial units.

- search the map for hills, known starting/parking points, and Irish places such as towns, villages, and cities. Search only applies to currently filtered and displayed hills and starting points. You can also search the full hill database from the Log Register.

- show known starting/parking points for walks within a defined distance from the hills.

- tap a hill (triangle within a circle - customisable colour) on the map to view its name, height, range, prominence, grid reference, and distance from your location. You can also tap the MountainViews.ie (MV) logo to visit the corresponding hill page. Where there are starting places nearby, they will also be indicated on the card. These are tappable to display the starting point details.

- tap a starting point (walking man icon - customisable colour) to view its name, grid reference and height, as well as parking details where available. Where there are close hills, you can also view a list of the nearest, together with their distance and height differential. These are tappable to open the relevant hill card. A link for directions via Apple and Google Maps is also provided, as is a link to the appropriate page on MountainViews.ie.

- use Go To for a selected hill to open a live compass with distance, direction, heading, and key hill metrics, while also showing a persistent guidance line on the map. Go To is also operable to a randomly chosen location by using a long press on the map. 

- a long press on the map also offers the option of creating a personal waypoint. These can be saved, and are displayed on map using a user defined colour. Tapping them offers the choice of Go To, rename, delete or cancel.

- mark hills as logged, review your logged total in the Log Register and export your logs.

- search the Log Register and quickly log or unlog hills.

- tap the weather icon to launch a 24 hour weather forecast for the selected hill, or, if no hill is currently selected, for the visible hill closest to the centre of the screen. If no hills qualify, the app will use the centre of the screen and return a Grid Reference. 

- in settings, turn on additional start-point datasets from Coillte, Sport Ireland and Outscape and display these on the map. Tapping these points gives details of any routes to or from the point, which can then be displayed on the map. These routes include all the major National Trails and Looped walks throughout the country, together with Northern Ireland off-road trails from Outscape. Given the primary purpose of this app is to facilitate climbing hills, these datasets are toggled off by default. However they do provide additional starting points to access the hills, and they are also of interest to the general walker.

Recording a GPX

Metrics Grids
In Settings, under Recording Display, you can choose between two metrics grids on the map. The options are a full metrics display with recording controls and a compact display, which is the default, without recording controls.

Recording using full on-map grid
When using the full grid, a long tap makes the grid active and usable for 20 seconds, after which it becomes inactive in order to prevent accidental operation.

Recording using compact on-map grid
Tap the [icon] button in the right column and a dialog including recording controls will open.

Using Recording Controls
Tap Start to begin recording, Stop to end the current track, Discard to throw away a recording you do not want to keep, and Save to keep it on the device.

Menus

Location Permissions and Data
\(AppBranding.displayName) requests location access so it can show your position on the map, calculate distance and bearing to hills, provide live elevation and grid references, support Go To Hill navigation, and record GPX tracks.

During an active GPX recording session, the app can continue recording while minimised or when the screen is locked, so your walk can be recorded continuously.

When prompted, or later in Settings, choose the location access option that allows active walk recording and navigation features to work as expected. We recommend choosing While Using the App and turning on Precise Location.

\(AppBranding.displayName) shares no data with third parties.  All data is retained locally on the user's device unless the user chooses to share it, e.g. uploading a saved track to a track sharing site.

MountainViews.ie
MountainViews.ie (MV) is the primary source for walker-provided hill information in Ireland. 

This app uses MV solely as its provider of hill data. The app provides, on each hill card, a method of opening the corresponding MV page for the relevant hill. As well as much of the data in the app, there are more details of the characteristics of the hill itself and possible approaches, dangers etc., as well as suggested walks and downloadable GPS tracks. MV also provide many of the starting/parking places shown on the map and on the Hill and Starting Points cards. Further information on these starting points can be accessed by clicking on the MV logo.

Additional Providers
The app can also display optional starting points and provider routes from Coillte, Sport Ireland and Outdoor Recreation NI / Outscape. These are turned off by default, which can be changed in Settings. They can add useful context for walkers looking for recognised trails, forest routes, nearby access points or alternative walking options.

Coillte provides 755 start points and 436 route records in the current app data. These are mainly forest and recreational walking routes, and are useful where a hill or approach lies close to a Coillte recreational site.

Sport Ireland provides 1,466 start points and 1,013 route records in the current app data. These include national trails, looped walks and Get Ireland Active route information, and are useful for identifying established walking routes and trailheads across the country.

Outdoor Recreation NI / Outscape provides 129 start points and 129 route records in the current app data. This is a curated subset of Northern Ireland off-road trail data, reduced from a larger source inventory to avoid showing large numbers of short fragments, rights of way and utility paths that are less useful as walking-route markers.

OpenOnzyMap
OpenOnzyMap is an hiking-focused offline-safe map, which is bundled with the app and thus can function in areas without cellular coverage. It includes local MBTiles, local Open Sans glyphs, and a custom cartographic style. The Map was built with OpenStreetMap, Tilemaker, QGIS, GDAL and SQLite.

[[openonzy-map-legend]]

OpenOnzyMap data sources: OpenStreetMap contributors, Geofabrik Ireland and Northern Ireland extract dated 2026-08-25, osmdata.openstreetmap.de land polygons, and SRTM 1 Arc-Second Global Version 3.

Safety
Note that, for your own safety, you should not rely solely on this app, or any app, for your navigation and safety in the hills.  Possession of a map and compass and/or a dedicated GPS unit, and the ability to use them correctly, is an essential precaution. While phones have improved immeasurably in recent years, shortcomings in battery life, waterproofing and signal mean they are not yet suitable as a sole navigation device in the hills. 

Where starting places are shown, note that these are known walk starting places within a defined distance from the relevant hill. They are displayed in order of their closeness to the relevant hill, in a straight line. They may not necessarily be the best or most straightforward starting places for a particular hill. Nor may the distance given be the actual distance walked; it is unusual to be able to walk directly towards a summit, so these figures should be treated as a minimum. In addition, where an ascent is provided, this is a net ascent; there may be both ascent and descent in walking between any 2 points. You should satisfy yourself as to the characteristics of any particular walk and your ability to undertake this walk by using a combination of information sources before selecting your target hill and starting place.

Weather forecasts, supplied by Met Éireann, are given as a service. Note however, that these forecasts are not specific mountain forecasts, but relate to the low-lying area surrounding a hill rather than the hill itself.  Conditions on a significant hill are likely to be both windier and colder than the forecast indicates.

Your safety is your responsibility. Take that responsibility seriously.

Private Land
Note that the existence of a starting/parking place does not imply entitlement to walk over any private land towards a particular hill. Where a landowner objects to walkers crossing his land, you should not attempt to do so. If this situation occurs you should advise MV and/or this app, through the support email. MV and/or BareGPS Ireland may respond by flagging any restrictions on the starting place or should the situation warrant it, by removing it from the database entirely.

Credits
AppsbyOnzy@gmail.com
Hill Data & Lists, MountainViews Starting Points: MountainViews.ie
Coillte Start Points & Trail Data: Coillte Recreation Information, published by Coillte via data.gov.ie, licensed under Creative Commons Attribution 4.0 International (CC BY 4.0).
Sport Ireland Start Points & Trail Data: Get Ireland Active - Sport Ireland 2023, published by Sport Ireland via data.gov.ie, licensed under Creative Commons Attribution 4.0 International (CC BY 4.0).
Outdoor Recreation NI / Outscape Trail Data: NI Off Road Trails Layer from the GreenspaceNI Map, created by Outscape for DAERA and DFI on behalf of the Strategic Outdoor Recreation Group (SORG), using data harmonised, combined and enhanced from Ordnance Survey of Northern Ireland, Northern Ireland Environment Agency, Outdoor Recreation Northern Ireland, DAERA, councils and other providers. Product currency stated by source: June 2024, annual update cycle. Attribution: © Crown copyright and database right Land & Property Services (2024) NIMA MOU577.2.
Weather Data: Met Éireann
Map Rendering: MapLibre
OpenOnzyMap data sources: OpenStreetMap contributors, Geofabrik Ireland and Northern Ireland extract dated 2026-08-25, osmdata.openstreetmap.de land polygons, and SRTM 1 Arc-Second Global Version 3.
Basemap data: © OpenStreetMap contributors
Topographic map data: © OpenStreetMap contributors, SRTM
Topographic map style: © OpenTopoMap (CC-BY-SA)
Standard map tiles: © OpenStreetMap contributors
Satellite imagery: Sources: Esri, Maxar, Earthstar Geographics, USDA, USGS
"""
}
