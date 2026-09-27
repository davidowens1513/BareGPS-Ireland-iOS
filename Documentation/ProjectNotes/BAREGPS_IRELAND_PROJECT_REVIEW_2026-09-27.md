# BareGPS Ireland Project Review

Date: 27 September 2026  
Reviewer: Codex  
Project: BareGPS Ireland / MapHills  

## Executive Summary

BareGPS Ireland is not a failed or chaotic project. It is a substantial, working, region-specific outdoor navigation app that has grown into a complex but valuable product. The current build succeeds, the app has a clear identity, and there is real test coverage around domain logic and user interface flows.

Your concern that the app has "spun out of control" is understandable, but I would describe the situation differently: the product has outgrown the informal development style that got it here. The right next move is not a rewrite. The right next move is to freeze the current master copy, bring Git under stricter discipline, make one deliberate publishing decision about map delivery, and then develop from a stable release baseline.

My overall opinion:

- Product concept: strong.
- Feature set: already more than enough for a credible first publication.
- Code quality: functional and often thoughtful, but heavy in the map and overlay layers.
- Test posture: better than many small independent apps, but still not broad enough to remove regression anxiety.
- Publication readiness: plausible after a short stabilisation phase, not after another burst of features.
- Biggest strategic decision: whether to bundle the 569 MB OpenBareMap package or move to a managed download model.

My recommended route is:

1. Treat the current app as a release candidate, not a playground.
2. Create a Git tag and stabilisation branch immediately.
3. Ship first with the bundled OpenBareMap if Apple package size and user-download tradeoffs are acceptable.
4. Defer remote map delivery until after the first stable release, unless app size becomes an App Store or user-acquisition blocker.
5. Use the next development phase to make regionalisation more coherent, not to add more unrelated features.

## What I Reviewed

I reviewed the Xcode project structure, Swift source files, packaging files, App Store material, Git status, map bundle size, test files, resource layout, and build state.

Key facts observed:

- The project builds successfully with the Xcode build tool.
- There are 52 Swift files and about 21,412 lines of Swift source.
- The main map controller is still very large: `MapViewController.swift` is about 3,127 lines.
- The map controller extension family is also substantial: for example `MapViewController+StateAndNavigation.swift` is about 1,354 lines and `MapViewController+GPXFiles.swift` is about 941 lines.
- The domain support layer is also large: `PeakSupport.swift` is about 1,611 lines.
- There is a meaningful unit test suite using Swift Testing.
- There is a meaningful UI test suite using XCTest / XCUIAutomation.
- The OpenBareMap bundle is about 569 MB.
- The full repository working directory is about 3.8 GB.
- The current Git worktree is dirty, with modified files, added scripts, generated resources, and an untracked 508 MB `Ireland-Walking-Map-0.6.0.zip`.
- Git LFS is already configured for `.mbtiles`, which is good.

## Product And Feature Assessment

BareGPS Ireland has a coherent product identity. It is not merely a generic map viewer with pins. It is a specialised Irish hillwalking companion. That is its strongest asset.

The app currently appears to support:

- Live map browsing.
- Multiple base layers, including OpenBareMap, OpenTopo, OpenStreetMap, and satellite.
- Hill markers.
- Hill search.
- Hill classification filters.
- Height filters.
- Irish grid reference support.
- Current position, heading, distance, elevation, and grid reference display.
- Go To Hill navigation.
- GPX recording.
- GPX import.
- GPX saving, reopening, renaming, deleting, export and sharing.
- Saved waypoints.
- Logged hill records.
- Offline caching for selected layers.
- Weather forecasts using Met Eireann data.
- Start places and trail summaries from multiple providers.
- App Store marketing, support, and privacy copy.

That is already a generous feature set. For a first public release, the danger is not that the app lacks features. The danger is that the user experience and reliability could be diluted by too many partially competing flows.

The strongest features for publication are:

- The custom Irish hill dataset and classifications.
- Irish grid reference handling.
- OpenBareMap as an all-island offline-capable map.
- GPX recording and import.
- Go To navigation.
- Hill logging.
- Local 100 / nearest-hundred logic.

Those are distinctive. They should be the core of the product story.

The weaker or higher-risk features are:

- Remote weather, because it depends on a third-party HTTP service and has an App Transport Security exception.
- Offline caching for external layers, because it adds support burden and download-state complexity.
- Very broad GPX file-management behavior, because file lifecycle bugs are common and can annoy users quickly.
- Too many settings, if the app is presented to first-time users without a clear default path.

My recommendation is to position the first release around "Irish hills, grid references, GPX, logging, and offline map confidence." Avoid making the first App Store story too broad.

## Adequacy For Publication

The app is close enough to publication to justify a stabilisation push. It is not yet in the "keep adding things freely" phase.

Positive publication signals:

- The project builds successfully.
- Location permission strings are present in Xcode build settings.
- Background location mode is declared, which matches active GPX recording.
- `ITSAppUsesNonExemptEncryption` is set to `NO`.
- App Store support, marketing, and privacy files exist.
- The app has a real privacy policy.
- UI tests exercise major overlays and some meaningful workflows.
- Unit tests cover grid formatting, GPX parsing, GPX summaries, stores, filters, state, and other important logic.
- The custom map bundle includes attribution and notice files.

Publication concerns:

- The current Git state is not release-clean.
- The bundled map is large at about 569 MB.
- The repository is very large at about 3.8 GB.
- A 508 MB map zip is untracked in the project root and should not remain there.
- Some resource JSON files are untracked, which makes it unclear what is source, what is generated, and what is release input.
- The app still has a large map-controller surface, which raises regression risk.
- The Info.plist declares an ATS exception for `openaccess.pf.api.met.ie`; this may be necessary, but it should be documented.
- The privacy policy mentions online map tiles and third-party providers. It should be checked against the final map-delivery decision.
- `UIFileSharingEnabled` is set to true. That may be appropriate for GPX workflows, but it should be a deliberate decision.

My verdict: publishable after a disciplined release-preparation pass. Not publishable directly from the current dirty working tree.

## Bundled Map Versus Remote Download

This is the central publication question.

The OpenBareMap bundle is about 569 MB:

- `ireland.mbtiles`: about 345 MB.
- `contours.mbtiles`: about 109 MB.
- `hillshade.mbtiles`: about 55 MB.
- `environment.mbtiles`: about 48 MB.
- `grid.mbtiles`: about 9.3 MB.
- `hiking.mbtiles`: about 3.4 MB.

There is also an untracked `Ireland-Walking-Map-0.6.0.zip` at about 508 MB.

### Option A: Bundle The Map

Advantages:

- Best first-launch experience.
- No account, server, hosting, or download entitlement issue.
- Works immediately offline.
- Fewer moving parts.
- Easier to test and support.
- Strong product message: the app includes its own Irish walking map.

Disadvantages:

- Large App Store download.
- Larger installed app.
- Every map update requires an app update.
- Git/release assets remain heavy.
- Users who only want casual use still pay the full download cost.

My view: this is the best route for a first stable release if the final App Store archive size remains acceptable and you are comfortable with the user download size.

For a specialist hillwalking app, a large offline map can be a feature, not a defect. Users who care about mountain navigation often understand offline data. The key is to present it honestly.

### Option B: Host Remotely And Download In-App

Advantages:

- Smaller app download.
- You can update map packages independently of app releases.
- You can offer regions in future.
- You can make regionalisation cleaner over time.
- Advanced users can choose what to download.

Disadvantages:

- Requires reliable hosting.
- Requires a map package manifest, versioning, checksum verification, resume logic, storage management, and error recovery.
- Requires extra App Store privacy and network disclosure review.
- Requires a clear UX for "map not yet downloaded".
- Introduces the risk of first-run disappointment if the user expects offline maps immediately.
- Creates operational responsibility: bandwidth, CDN cost, expiry, broken links, update compatibility, and support.

My view: remote download is the better long-term architecture, but not the better immediate stabilisation choice unless app size blocks publication.

### Recommended Decision

For the first public release: bundle the OpenBareMap package.

For the second major phase: design remote regional map packages properly.

Do not half-implement remote map delivery just before first publication. It is the kind of feature that looks simple but creates new classes of support failure: interrupted downloads, corrupted packages, low storage, stale manifests, checksum mismatches, hosting errors, and users launching without maps.

If you want future regionality, build it after you have one stable release and a Git workflow that protects you.

## Regionalisation Strategy

The current code already has a useful regionalisation seed:

- `RegionDefinition` protocol.
- `ActiveRegion.current`.
- `IrelandRegionDefinition`.
- Region-specific datasets and formatters.

This is promising, but it is not yet a fully region-pluggable architecture. `ActiveRegion.current` is hard-coded to Ireland, and several names and assumptions remain Ireland-specific. That is fine for BareGPS Ireland. It is not yet a reusable multi-region product engine.

Recommended regionalisation phases:

1. Stabilise BareGPS Ireland as one region.
2. Clarify what belongs to "region" versus what belongs to "app core".
3. Move datasets, map bundle metadata, about text, classification schemes, grid systems, and provider attribution behind region definitions.
4. Introduce a region package manifest for future downloadable maps.
5. Only then consider multiple regions or a generic BareGPS shell.

Do not regionalise prematurely. The current app is strongest as a specific Irish hillwalking app. Make that excellent first.

## Code Quality Assessment

The code is not reckless. It is mostly readable, explicit, and domain-aware. The problem is concentration of responsibility.

Good signs:

- The app has real domain models.
- There are stores and engines extracted out of the view controller.
- The map controller has been split across extensions.
- Unit tests exist and cover more than trivial cases.
- UI tests use accessibility identifiers.
- Map, overlay, weather, domain, lifecycle, branding, and region concerns have separate folders.
- The app avoids many obviously dangerous Swift patterns. The search for forced unwraps and force casts found very little beyond standard unavailable storyboard initialisers and one table-cell cast.

Weak signs:

- `ViewController` remains the centre of gravity for too much behavior.
- Several files exceed 700 to 1,000 lines.
- Overlay controllers repeat similar UIKit construction patterns.
- Some data loading functions fail soft by returning empty arrays, which can hide packaging problems.
- There is a lot of mutable state in the main controller.
- Some app behavior is difficult to reason about without following chains across many extension files.
- The app is UIKit-heavy and programmatic, which is valid, but it increases the need for shared UI patterns and clear ownership.

My code-quality judgement: solid enough to stabilise and ship, but too concentrated to keep growing safely without further modularisation.

## Testing Assessment

The test suite is a real asset.

Unit tests include coverage for:

- Grid coordinate formatting and parsing.
- Peak compatibility fields.
- Waypoint save, update, delete, and sort.
- GPX filename sanitising.
- GPX recording summaries.
- GPX parsing.
- Track recording policies.
- Go To session movement thresholds.
- Viewport state policy.
- Data and domain behavior.

UI tests include coverage for:

- Right-rail buttons.
- Overlay open and close behavior.
- Settings sections.
- Settings persistence.
- Local hundred controls.
- Cache detail selection.
- Saved waypoint flows.
- Go To flows.
- GPX launch/import flows.

Gaps to close before publication:

- Clean-install first launch.
- Location permission denial and later enabling.
- Background GPX recording continuation.
- Low/no network weather behavior.
- Missing or corrupted bundled map resources.
- App relaunch during an active recording.
- Low-storage behavior for GPX and offline cache.
- A smoke test that the OpenBareMap style loads.
- A test or manual checklist for App Store archive/release build, not just debug build.

I would not try to create perfect coverage before publication. I would add a short release checklist and two or three targeted tests around the riskiest flows.

## Git And Version-Control Recommendations

This is the area where I would act immediately.

Current Git state shows:

- Modified Swift files.
- Added reference setup and scripts.
- Untracked generated JSON resources.
- An untracked 508 MB zip file.
- A modified Xcode workspace file.
- Git LFS in use for `.mbtiles`.

This is too loose for a master copy. It is exactly the state that makes a project feel frightening.

Recommended immediate process:

1. Do not add features until the worktree is clean.
2. Create a safety branch now, for example `stabilise/2026-09-release`.
3. Review every untracked file and decide whether it is source, generated output, or disposable.
4. Remove generated caches such as `Scripts/__pycache__/`.
5. Move the 508 MB zip out of the repo or explicitly manage it as a release artifact, not as a loose root file.
6. Decide whether generated JSON resources are committed release inputs or generated during build. Do not leave them ambiguous.
7. Commit the current stable state in small logical commits.
8. Tag the first stabilised baseline, for example `v1.02.1-rc1`.
9. Use feature branches from then on.
10. Protect `main` mentally, even if GitHub branch protection is not yet configured.

Suggested branch model:

- `main`: stable, buildable, releasable.
- `stabilise/...`: release hardening only.
- `feature/...`: new work.
- `experiment/...`: risky ideas.
- `data/...`: map and reference-data updates.

Suggested commit discipline:

- One topic per commit.
- Commit tests with the code they verify.
- Use clear messages such as `Add OpenBareMap bundle manifest`, `Harden GPX import errors`, `Extract offline cache store`.
- Avoid committing generated junk, caches, personal notes, or temporary zips.

Recommended `.gitignore` additions if not already present:

- `Scripts/__pycache__/`
- `*.pyc`
- `.DS_Store`
- temporary export zips unless deliberately tracked
- derived local build outputs

For large assets:

- Keep `.mbtiles` in Git LFS if bundling.
- Keep release zips outside the repo or in GitHub Releases, not loose in the project root.
- Keep source data and generated app resources clearly separated.

## Publication Recommendations

Before App Store submission, I recommend this checklist:

1. Make the Git worktree clean.
2. Archive from a clean branch.
3. Confirm the final app name, bundle ID, marketing version, and build number.
4. Confirm location permission prompts on a clean device.
5. Confirm background recording behavior.
6. Confirm GPX import/export using Files.
7. Confirm OpenBareMap attribution and licences are visible.
8. Confirm Met Eireann attribution and weather error handling.
9. Confirm the privacy policy matches the exact shipped behavior.
10. Confirm whether `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are intended.
11. Confirm the app behaves acceptably with no network.
12. Confirm first launch on a device that has never installed the app.
13. Confirm app size in App Store Connect or an archive report.

My publication opinion:

- If bundling the map is acceptable, submit after stabilisation.
- If app size is unacceptable, pause publication and build a proper map-download system.
- Do not publish from the current dirty repository state.
- Do not add more major features before first publication.

## Recommended Stabilisation Plan

### Phase 1: Freeze And Clean

Goal: make the current project trustworthy.

Actions:

- Create a stabilisation branch.
- Clean the Git status.
- Classify every untracked file.
- Remove or relocate temporary zips.
- Commit generated resources intentionally or regenerate them reproducibly.
- Run a full build.
- Run unit tests.
- Run a focused UI test subset.

### Phase 2: Release Hardening

Goal: make first publication boring.

Actions:

- Test clean install.
- Test location permissions.
- Test GPX recording, import, export, and relaunch.
- Test offline map availability.
- Test weather failure.
- Review App Store copy and privacy.
- Verify licences and attribution.
- Archive a release build.

### Phase 3: Controlled Improvement

Goal: reduce fear when changing the app.

Actions:

- Extract smaller coordinators from `ViewController`.
- Split `PeakSupport.swift` by concern.
- Centralise overlay/card construction further.
- Make data-loading failures visible in debug or test builds.
- Add tests around map bundle integrity.
- Document release steps in `RELEASE_CHECKLIST.md`.

### Phase 4: Regionality

Goal: support future regions coherently.

Actions:

- Define a region package manifest.
- Separate region data from core app logic.
- Move map package metadata behind the region definition.
- Decide whether maps are bundled, downloadable, or hybrid.
- Build one additional small test region only after Ireland is stable.

## Specific Recommendations

Highest priority:

- Stop feature growth temporarily.
- Clean Git.
- Decide bundle versus remote for the first release.
- Write a release checklist.
- Add a map-resource integrity test.
- Keep OpenBareMap bundled for the first release unless size blocks publication.

Medium priority:

- Split large files gradually.
- Add a dedicated `OfflineMapPackage` or `MapPackageManifest` model.
- Move weather service endpoint and ATS rationale into documentation.
- Review first-run UX.
- Add low-network and denied-permission test cases.
- Create a `docs/` folder for release, data, map, and attribution notes.

Lower priority:

- Remote map downloads.
- Multiple regions.
- Major UI redesign.
- New feature categories.
- Broad SwiftUI migration.

## Final Opinion

BareGPS Ireland has not failed by becoming too large. It has reached the point where it needs release management.

The app has a real identity, real utility, and enough features for publication. The codebase is heavier than ideal, but it builds, it has tests, and it contains sensible domain structure. The most important change is not technical cleverness. It is discipline: clean Git, stable branches, release checklists, and deliberate decisions about large map assets.

I would aim to publish a stable, Ireland-focused version with the bundled map first. Then, after the app is public and controlled, build toward regional map packages and optional downloads. That path gives you a stable base, protects your work, and avoids turning the publication decision into another open-ended engineering project.

