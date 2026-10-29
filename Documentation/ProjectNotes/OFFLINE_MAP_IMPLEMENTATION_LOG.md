# Offline Map Implementation Log

## Baseline

- Started: 29 October 2026
- Baseline commit: `acab282`
- Baseline working tree: clean
- OpenBareMap policy during implementation: do not alter the finished map. After the live R2 pack passed an end-to-end phone download, the five packaged MBTiles were deliberately removed from the app source as the planned final packaging step; all style, font, sprite, townland, attribution, integration, manifest, and legend resources remain.
- Commit/push policy: no commit or push until owner review and approval

## Rollback

Until the work is approved, all app changes can be inspected with `git diff` and rolled back file by file. New files are listed below as they are added. The bundled OpenBareMap remains the development fallback until live R2 assets exist.

## Change Record

### Core foundation

- Added the five-file manifest model and defensive checks for schema, app version, file set, path, HTTPS host, byte totals, hashes, and maximum pack size.
- Added the Application Support store, staging folders, atomic activation record, activation rollback, backup exclusion, free-space check, map removal, and persistent state.
- Added exact-byte, streaming SHA-256, and SQLite `quick_check` verification before activation.
- Added a persistent transfer context, fixed background-session identifier, task/file matching, aggregate progress, relaunch reconciliation, and the AppDelegate background completion hook.
- Added HTTP status, final URL, host, content-type, network, storage, and verification failure handling. The prior active pack is retained on update failure.
- Added a small local download log containing time, file ID, pack events, and error text only.

### App integration

- Map styles now use an installed pack's MBTiles with the bundled style, fonts, sprites, townlands, and legend resources.
- The packaged MBTiles remain a development fallback until R2 is live; no OpenBareMap bundle content was changed.
- After R2 became live and the phone reported the downloaded pack Ready, removed only `basemap.mbtiles`, `topography.mbtiles`, `hillshade.mbtiles`, `grid.mbtiles`, and `coast.mbtiles` from the packaged bundle. Verified source copies remain in Git history, the Desktop R2 upload folder, and R2.
- If neither an installed pack nor the development fallback exists, startup uses OpenTopo and offers the map download once the main screen appears.
- OpenBareMap remains in the layer chooser with download, progress, update, and repair status; unavailable selection opens map management rather than loading a blank style.
- Settings now opens an Offline Map screen with status, progress, version, install date, space, Wi-Fi-only default, download/retry/update/remove actions, error text, and removal confirmation.

### Automated coverage

- Added tests for a valid manifest, rejected host, rejected minimum app version, wrong byte total, atomic store activation, and removal scope.

## Verification Record

- Baseline `MapHills` build before this implementation: passed.
- App build: passed after implementation.
- Build for testing: passed.
- Offline-map unit tests: 6 passed, 0 failed.
- Full active plan: 55 passed, 2 unrelated existing resource-data tests failed, and 16 UI tests were not run after those failures. The failures were `provinceTopFiftyUsesHighestProminentHillsPerProvince` and missing `OutscapeTrails.geojson`; neither area was changed by this work.
- Device-interaction check: blocked before launch because the available Xcode destinations do not include the iOS 27+ simulator required by the interaction tool. No runtime UI failure was observed.
- Before live-R2 approval, the OpenBareMap bundle diff was empty. The final packaging step now records exactly five deliberate MBTiles deletions and no other OpenBareMap changes.
- Post-removal app build: passed. Built app scan found no `.mbtiles` files; Debug device app size is approximately 127 MB.
- Post-removal phone test: passed. The smaller build was installed over the existing app, and OpenBareMap continued to work from the previously downloaded R2 pack with the bundled MBTiles absent.
- Clean-install phone test: passed. With no prior app data and no bundled MBTiles, the app offered the map download, installed the live R2 pack to Ready, loaded OpenBareMap offline, and reopened successfully in Airplane Mode.

## External Work Deliberately Deferred

- Uploading a large R2 test object.
- Uploading production MBTiles and `manifest-v1.json`.
- Public privacy/support page changes.
- TestFlight and App Store Connect work.
