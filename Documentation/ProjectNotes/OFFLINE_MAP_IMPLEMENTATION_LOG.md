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
- Connected URL-session waiting callbacks to persistent Waiting for Wi-Fi/Network state and return to Downloading when transfer progress resumes.
- Prevented Wi-Fi-only policy changes during an active network transfer so changing the switch cannot cancel or invalidate an in-progress background download.
- Added a small local download log containing time, file ID, pack events, and error text only.

### App integration

- Map styles now use an installed pack's MBTiles with the bundled style, fonts, sprites, townlands, and legend resources.
- The packaged MBTiles remain a development fallback until R2 is live; no OpenBareMap bundle content was changed.
- After R2 became live and the phone reported the downloaded pack Ready, removed only `basemap.mbtiles`, `topography.mbtiles`, `hillshade.mbtiles`, `grid.mbtiles`, and `coast.mbtiles` from the packaged bundle. Verified source copies remain in Git history, the Desktop R2 upload folder, and R2.
- If neither an installed pack nor the development fallback exists, startup uses OpenTopo and offers the map download once the main screen appears.
- OpenBareMap remains in the layer chooser with download, progress, update, and repair status; unavailable selection opens map management rather than loading a blank style.
- Settings now opens an Offline Map screen with status, progress, version, install date, space, Wi-Fi-only default, download/retry/update/remove actions, error text, and removal confirmation.

### Automated coverage

- Expanded the offline-map suite to cover malformed JSON; pack, schema, host, protocol, path, file-set, size, hash, and overflow rejection; missing or damaged files; invalid and incomplete SQLite databases; traversal resistance; active-record rollback; preservation of the old map; relaunch identity restoration; backup exclusion; free-space margin; cancellation; network policy; and launch-offer policy.
- Added deterministic UI coverage for both first-launch choices, Settings and map-layer routes into OpenBareMap management, and reachability at an accessibility text size. UI-only launch controls isolate these flows without changing normal app behavior or deleting an installed map.
- Added a spoken accessibility label to the Wi-Fi-only download switch.

### Remaining-work implementation — 30 October 2026

- Section 1.1: added an in-progress Cancel Download action for Downloading and Waiting for Wi-Fi/Network. It confirms cancellation, calls cancel on every background task, deletes only the current staging folder and transfer record, preserves any prior active map, returns to Ready or Not Installed as appropriate, and ignores late cancelled-task callbacks. Cancellation is idempotent.
- Section 1.4: chose update discovery when the OpenBareMap management screen opens, while retaining the manual Check for Update action. A newer manifest now produces an opt-in alert showing map version, download size, and publication date, with Update Map and Later actions and a clear statement that the current map remains usable.
- Section 1.5: activation now moves the candidate pack into place while retaining the prior active record, prepares and validates the candidate style through the same OpenBareMap/MapLibre style integration used by the app, commits the new active record only after that succeeds, rolls the candidate back on failure, and removes obsolete pack directories only after successful activation.
- Section 1.7: the Wi-Fi-only control now explains that it is locked during an active transfer and that changes apply to the next download. The disabled switch has an explicit accessibility hint. Network policy tests confirm that Wi-Fi-only blocks cellular, expensive, and constrained paths; disabling Wi-Fi-only permits cellular and expensive paths while Low Data Mode/constrained paths remain blocked.
- Section 1.8: extracted the first-launch offer rule into a tested policy. The offer appears at most twice, never when an installed map is recorded, and the Later path cannot invoke the network request.
- Per owner direction, sections 1.2, 1.3, and 1.6 were dropped. Section 1.9 remains deferred for owner review.
- No OpenBareMap map, style, legend, font, sprite, townland, attribution, or bundle resource was changed in this pass.

## Verification Record

- Baseline `MapHills` build before this implementation: passed.
- App build: passed after implementation.
- Build for testing: passed.
- Offline-map unit tests: 8 passed, 0 failed after connectivity-state hardening.
- Full active plan: 55 passed, 2 unrelated existing resource-data tests failed, and 16 UI tests were not run after those failures. The failures were `provinceTopFiftyUsesHighestProminentHillsPerProvince` and missing `OutscapeTrails.geojson`; neither area was changed by this work.
- Device-interaction check: blocked before launch because the available Xcode destinations do not include the iOS 27+ simulator required by the interaction tool. No runtime UI failure was observed.
- Before live-R2 approval, the OpenBareMap bundle diff was empty. The final packaging step now records exactly five deliberate MBTiles deletions and no other OpenBareMap changes.
- Post-removal app build: passed. Built app scan found no `.mbtiles` files; Debug device app size is approximately 127 MB.
- Post-removal phone test: passed. The smaller build was installed over the existing app, and OpenBareMap continued to work from the previously downloaded R2 pack with the bundled MBTiles absent.
- Clean-install phone test: passed. With no prior app data and no bundled MBTiles, the app offered the map download, installed the live R2 pack to Ready, loaded OpenBareMap offline, and reopened successfully in Airplane Mode.
- Remaining-work build for testing: passed after sections 1.1, 1.4, 1.5, 1.7, and 1.8 were implemented.
- Offline-map delivery tests: 16 passed, 0 failed, including cancellation with and without a prior map, activation rollback, obsolete-pack cleanup, Wi-Fi/cellular/constrained policy, two-launch limit, installed-map suppression, and passive Later actions.
- Full active plan after this pass: 77 passed and 6 failed. The two existing resource/classification failures remained (`PT50` classification data and missing `OutscapeTrails.geojson`), and four unrelated UI flows failed. No offline-map delivery test failed.
- Section 2 build for testing: passed with no compiler diagnostics in the changed app and UI-test files.
- Section 2 offline-map delivery suite: 31 passed, 0 failed.
- Section 2 focused UI suite: first-launch Later/Download routes, Settings/layer management routes, and accessibility-size reachability passed.

## External Work Deliberately Deferred

- Uploading a large R2 test object.
- Uploading production MBTiles and `manifest-v1.json`.
- Public privacy/support page changes.
- TestFlight and App Store Connect work.
