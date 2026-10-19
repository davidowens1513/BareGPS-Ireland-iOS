# BareGPS Ireland 2.0 — App Store and Offline Map Delivery Plan

**Prepared:** 17 October 2026  
**Purpose:** A decision paper and step-by-step implementation guide for shipping BareGPS Ireland 2.0 through the Apple App Store while delivering its large offline map reliably.

> This is a technical and product plan, not legal advice. Prices, limits, and App Store rules can change; recheck the linked primary sources immediately before release.

## Executive recommendation

Ship a small, useful app through the App Store and let the person download the offline OpenBareMap **inside the app**. Host the seven large `.mbtiles` files in a Cloudflare R2 bucket behind a custom hostname such as:

```text
https://downloads.appsbyonzy.dev/baregps-ireland/manifest-v1.json
```

Keep `baregps-style.json`, fonts, sprites, GeoJSON, and other small support files in the app. Download only these seven large files:

| File | Current disk size (approx.) |
|---|---:|
| `ireland.mbtiles` | 741 MB |
| `contours.mbtiles` | 109 MB |
| `hillshade.mbtiles` | 55 MB |
| `environment.mbtiles` | 48 MB |
| `grid.mbtiles` | 9.3 MB |
| `islands.mbtiles` | 5.9 MB |
| `hiking.mbtiles` | 3.4 MB |

The complete `OpenBareMap.bundle` currently occupies approximately **982 MB** and contains **138 files**. The seven MBTiles account for almost all of that size.

The app should remain usable without the offline pack by opening on an online map. On first launch, show a clear, dismissible card offering the Ireland offline map, its exact download/storage size, and a Download button. The same action must remain available later in Settings or the map-layer menu.

Do **not** send the person to Safari to download the map, and do **not** use Notion as a redirect in the download path. A browser cannot install the map directly into the app’s private sandbox cleanly. Notion remains suitable for the human-readable privacy and support pages, while the app uses a machine-readable manifest at a stable hostname you control.

## The important correction: 1 GB is not automatically too large for the App Store

Apple’s current maximum uncompressed size for an iOS/iPadOS app with a deployment target of iOS 9 or later is **4 GB**. The separate 500 MB figure in Apple’s table applies to the total `__TEXT` sections of executable code, not ordinary map resources. See [Apple: Maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes).

Therefore, the current map can technically remain bundled if the final thinned build stays within Apple’s limits. That is the lowest-code-risk route, and it is a valid emergency fallback. It is not the recommended product experience because every new install and many app updates would involve roughly a gigabyte of map content, even for people who do not want offline maps.

Before committing to either route, create an App Store archive and inspect its App Thinning Size Report. Finder’s source-folder size is useful but is not the final App Store download or installed size.

## What the existing app does today

The current project is a UIKit iPhone app with:

- minimum deployment target **iOS 18.2**;
- marketing version **1.02.1** and build **104** at the time of this review;
- bundle identifier `com.DavidOwens1513.BareGPSIreland.MapHills`;
- MapLibre Native as the renderer;
- online OpenTopoMap, OpenStreetMap, and satellite styles;
- an offline OpenBareMap style loaded from `OpenBareMap.bundle` in the signed app bundle;
- existing MapLibre “save visible area” support for online map layers, which is separate from the full-country OpenBareMap pack discussed here.

`MapStyleURLProvider.openBareMapStyleURL()` currently assumes this location:

```text
Bundle.main/…/OpenBareMap.bundle/
```

It then rewrites references to the seven MBTiles files, fonts, sprites, and GeoJSON into absolute local URLs before giving the temporary resolved style to MapLibre. That is good news: MapLibre already reads the MBTiles locally. The main code change is to teach the provider that small resources can come from the app bundle while downloaded MBTiles live in Application Support.

## Options considered

| Option | Advantages | Disadvantages | Verdict |
|---|---|---|---|
| Keep all maps in the app | Least new code; works offline immediately; Apple limit currently permits it | About 1 GB for every install/update; no independent map updates | Safe fallback |
| Cloudflare R2 + native in-app background download | Works with iOS 18.2; good UX; resumable; map can update independently; inexpensive | Requires download/state/storage code and maintaining hosting | **Recommended** |
| Apple-Hosted Managed Background Assets | Apple hosts and manages downloads, updates, and compression | Current Apple documentation requires apps targeting iOS 26 or later; adopting it would abandon iOS 18–25 users and adds new packaging/review workflow | Revisit later |
| Legacy On-Demand Resources | Apple hosting and familiar asset tags | An older mechanism; less strategic than Background Assets and not ideal for building a new 2026 pipeline | Do not start a new implementation |
| Open a browser and let the person download/import a ZIP | Little downloader code initially | Fragile hand-off; duplicate disk use; confusing Files/import flow; poor recovery; easy support nightmare | Reject |
| Stream individual vector tiles from a server | Small initial footprint | Changes the offline-first promise, server architecture, operating cost, and failure modes | Wrong goal |

Apple describes Managed Background Assets as available to apps targeting iOS 26 and later and supports Apple-hosted packs submitted separately through App Store Connect. It is attractive for a future release if BareGPS raises its minimum OS. See [Apple: Overview of Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs) and [Background Assets](https://developer.apple.com/documentation/backgroundassets/).

## Why native in-app download is the bulletproof route

Use a background `URLSession` with download tasks. Apple’s background session transfers run in a separate system process and can continue while the app is suspended or no longer running. The app recreates the session with the same identifier on launch so iOS can reconnect it to outstanding work. See [Apple: Downloading files in the background](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background).

This approach gives BareGPS:

- system-managed background transfer;
- progress callbacks;
- automatic continuation across ordinary suspension;
- recoverable/resumable downloads when supported;
- HTTP status checking and retry;
- direct movement of completed temporary files into the app sandbox;
- no Safari, Files app, share sheet, or manual import.

The downloaded files are data, not executable code. App Review Guideline 2.5.2 forbids downloading code that changes app features; downloadable map data is a normal asset use case. Do not place scripts, dynamic libraries, or executable content in the pack. See [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

## Proposed user experience

### First launch

The app opens normally on an online map. It does not trap the person behind a mandatory download screen.

Show a card or sheet similar to:

> **Download the Ireland offline map?**  
> Use the detailed OpenBareMap without mobile coverage. Download: 982 MB. Allow about 2 GB of free space during installation. Wi‑Fi is recommended.  
> **Download Map** · **Not Now**

The displayed byte count must come from the manifest, not a hard-coded marketing estimate.

If Low Data Mode or cellular restrictions prevent the transfer, explain that plainly. Offer “Wi‑Fi only” by default and an explicit “Allow Mobile Data” setting. Do not silently consume nearly 1 GB of cellular data.

### During download

Show:

- overall percentage and downloaded/total bytes;
- current state: Waiting, Downloading, Paused by System, Verifying, Installing, Ready, or Failed;
- Cancel and Retry actions;
- a statement that the person can use the app or leave it while downloading.

Do not promise an exact completion time. iOS and network scheduling make it unreliable.

### When ready

- Enable OpenBareMap in the map-layer picker.
- Optionally switch to it only if the person asked to do so; do not unexpectedly change the active layer.
- Show the installed pack version and size in Settings.
- Provide “Check for Update” and “Remove Offline Map”.

### If no pack is installed

The OpenBareMap row should not fail silently. Show a cloud-download icon or “Download required”. Selecting it opens the download sheet. Online layers continue working.

### Failure messages that need explicit handling

- No internet connection.
- Server returned an error or an HTML page instead of a map file.
- Insufficient free storage.
- File size mismatch.
- SHA-256 mismatch/corrupt file.
- Download canceled by the person.
- Pack is incomplete after app/device interruption.
- A newer manifest is incompatible with this app version.

Each failure must leave the last known-good installed map untouched.

## Storage design

Use a versioned directory under Application Support, for example:

```text
Library/Application Support/BareGPS/OfflineMaps/Ireland/
├── active.json
├── staging-2026.10.1/
│   ├── ireland.mbtiles
│   ├── contours.mbtiles
│   └── …
└── 2026.10.1/
    ├── manifest.json
    ├── ireland.mbtiles
    ├── contours.mbtiles
    └── …
```

Application Support is preferable to Documents because these are app-managed support files, not user documents that should appear in Files. Mark the offline-map directory `isExcludedFromBackup = true`, because the data can be downloaded again and should not inflate the person’s iCloud backup. Apple specifically recommends excluding large redownloadable assets. See [Apple: Optimizing your app’s data for iCloud backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup) and [Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively).

Never treat `Library/Caches` as the only home of the offline map if the product promises it will remain offline: the system may purge Caches. Use Application Support and explicitly exclude it from backup.

### Atomic installation

1. Create a new version-specific staging directory.
2. Download all seven files into that directory.
3. Confirm every HTTP response is successful.
4. Confirm exact byte length.
5. Calculate and compare each SHA-256 digest.
6. Confirm the files are readable SQLite/MBTiles databases and contain expected metadata.
7. Move or rename the complete staging directory to its final version name.
8. Atomically replace `active.json` so it points to the new version.
9. Rebuild/reload the OpenBareMap style.
10. Delete the previous version only after the new version has opened successfully.

This prevents a failed update from destroying a working map.

### Free-space check

Before starting, use the volume’s “important usage” available capacity and require:

```text
remaining download bytes + installation overhead + safety margin
```

Because this plan downloads already-usable `.mbtiles` files and does not unzip a 1 GB archive, temporary duplication is much lower than a ZIP-based scheme. A conservative initial message should still ask for roughly 2 GB free until measured on real devices.

## Manifest design

The app should contain only one stable bootstrap URL. That URL returns a small JSON manifest. The manifest—not a Notion redirect—provides indirection between app versions and whichever object host is currently used.

Example:

```json
{
  "schemaVersion": 1,
  "packID": "ie.appsbyonzy.baregps.ireland.openbaremap",
  "packVersion": "2026.10.1",
  "minimumAppVersion": "2.0",
  "displayName": "Ireland Offline Map",
  "totalBytes": 1019215872,
  "files": [
    {
      "name": "ireland.mbtiles",
      "url": "https://downloads.appsbyonzy.dev/baregps-ireland/2026.10.1/ireland.mbtiles",
      "bytes": 777000000,
      "sha256": "REPLACE_WITH_64_LOWERCASE_HEX_CHARACTERS"
    }
  ]
}
```

Use actual byte counts, not Finder-rounded values. Include all seven files. Keep older, released objects immutable. Never overwrite `2026.10.1/ireland.mbtiles`; publish a new versioned path instead. Update the manifest last, after all new objects are uploaded and independently verified.

Recommended HTTP headers for versioned files:

```text
Content-Type: application/octet-stream
Cache-Control: public, max-age=31536000, immutable
Content-Disposition: attachment
```

Recommended manifest headers:

```text
Content-Type: application/json
Cache-Control: no-cache
```

The app must allow only HTTPS and should accept asset URLs only from an explicit host allow-list unless a future app release deliberately changes that rule. HTTPS protects transport; SHA-256 verifies that the received bytes are exactly the released bytes.

## Cloudflare R2 choice and cost implications

Cloudflare R2 is a good fit for a roughly 1 GB public pack:

- standard storage is currently listed at **$0.015/GB-month**;
- internet egress is currently listed as free;
- Standard storage currently includes 10 GB-month, 1 million Class A operations, and 10 million Class B operations per month in its free tier;
- a single object can be up to 5 TiB, so the 741 MB Ireland file is acceptable;
- use a custom domain for production; Cloudflare says `r2.dev` is rate-limited and intended for development.

See [Cloudflare R2 pricing](https://developers.cloudflare.com/r2/pricing/), [R2 limits](https://developers.cloudflare.com/r2/platform/limits/), and [Public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/).

One subtlety: on Cloudflare Free, Pro, and Business plans, the documented maximum cacheable file size is 512 MB. The 741 MB `ireland.mbtiles` object can still be served from R2, but it may not receive normal edge-cache treatment. That is not fatal because R2 egress is free. Do not add chunk-reassembly complexity for version 2.0 merely to force edge caching. Measure real Irish download performance first. See [Cloudflare: Enable cache in an R2 bucket](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/).

Use R2 **Standard**, not Infrequent Access, initially. The pack is read-heavy and Standard has no retrieval fee.

## Cloudflare setup — beginner’s step-by-step guide

The labels in Cloudflare’s dashboard may change slightly. The cited Cloudflare pages are the source of truth.

### Part A — confirm the domain is managed in the right account

1. Sign into the Cloudflare dashboard.
2. Open **Websites** and confirm `appsbyonzy.dev` appears and is Active.
3. If the domain is registered elsewhere, confirm its nameservers point to the two nameservers Cloudflare assigned.
4. Do not change existing Notion-related DNS records during this work.
5. Decide on the production hostname. This plan uses `downloads.appsbyonzy.dev`.

### Part B — enable R2 and create the bucket

1. In Cloudflare, open **Storage & databases → R2 → Overview**.
2. Complete the R2 subscription/checkout step. Cloudflare requires this even when usage remains inside the free allowance.
3. Select **Create bucket**.
4. Name it something unambiguous, for example `baregps-production-assets`.
5. Choose **Standard** storage.
6. Leave the bucket private for now.

Cloudflare’s current introduction is [Get started with R2](https://developers.cloudflare.com/r2/get-started/).

### Part C — prepare release files locally

1. Create a release folder outside the Xcode target’s resource membership.
2. Copy the seven final, tested MBTiles files into a version folder such as `2026.10.1`.
3. Record exact byte sizes.
4. Generate SHA-256 hashes.
5. Create `manifest-v1.json` with those exact values.
6. Validate the JSON.
7. Keep this release folder as the reproducible source of what was published.

Example Terminal commands for inspection (do not blindly paste paths; adjust them):

```bash
shasum -a 256 *.mbtiles
stat -f '%N %z' *.mbtiles
python3 -m json.tool manifest-v1.json >/dev/null
```

### Part D — upload safely

For a one-off release, the dashboard can upload objects. For repeatable releases, use Wrangler, `rclone`, or another S3-compatible client. Cloudflare recommends multipart upload for large/resumable uploads; S3-compatible tools commonly select it automatically. See [Cloudflare: Upload objects](https://developers.cloudflare.com/r2/objects/upload-objects/).

Upload into immutable keys:

```text
baregps-ireland/2026.10.1/ireland.mbtiles
baregps-ireland/2026.10.1/contours.mbtiles
…
baregps-ireland/manifest-v1.json
```

Upload the seven MBTiles first. Upload the manifest **last**.

### Part E — connect the production custom domain

1. Open the R2 bucket.
2. Choose **Settings**.
3. Under **Public access → Custom Domains**, choose **Connect Domain**.
4. Enter `downloads.appsbyonzy.dev`.
5. Review and accept the DNS record Cloudflare proposes.
6. Wait until Cloudflare reports the custom domain as Active.
7. Keep the `r2.dev` development URL disabled for production.

These are Cloudflare’s documented steps: [Enable cache for an R2 bucket](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/).

### Part F — cache rules

1. Create a cache rule for versioned asset paths such as `/baregps-ireland/2026.10.1/*`.
2. Treat these files as immutable with a long TTL.
3. Do not give the manifest a long immutable TTL.
4. Remember the 512 MB cacheability limit on non-Enterprise plans.
5. If an object is mistakenly uploaded to an existing URL, purge Cloudflare cache; better still, never overwrite released version URLs.

Cloudflare notes that cached custom-domain access has relaxed consistency and old objects or cached 404s may persist. Versioned immutable paths avoid most of this problem. See [R2 consistency model](https://developers.cloudflare.com/r2/reference/consistency/).

### Part G — verify before putting the URL in the app

For every public object:

1. Open its HTTPS URL from a network not logged into Cloudflare.
2. Confirm status `200`.
3. Confirm `Content-Length` equals the manifest.
4. Confirm the response is the binary file, not an HTML login/error page.
5. Download it and recompute SHA-256.
6. Test an interrupted and resumed download on a real iPhone.
7. Test Wi‑Fi to cellular transitions and airplane mode.

Do not use Cloudflare Access login protection on these asset URLs; a background app download cannot complete an interactive login. The objects contain public map data distributed with the app, so obscure signed URLs add operational complexity without meaningful secrecy. Integrity comes from HTTPS and hashes.

## Where Notion belongs

Continue using Notion for:

- the privacy-policy page;
- the support page;
- possibly a release/help article explaining the offline map and its size.

Do not use a Notion page as the app’s asset endpoint or redirector. It adds an unrelated service, HTML behavior, possible redirect changes, and another point of failure to a 1 GB background transfer.

The stable layer is your domain:

```text
App → downloads.appsbyonzy.dev/… → current object host
```

If R2 is replaced later, you can preserve that hostname using DNS, a Cloudflare Worker/redirect, or a small manifest whose file URLs point to the new host. Because the app fetches a manifest, most server changes require no app update.

Keep privacy/support URLs logically separate, for example:

```text
https://appsbyonzy.dev/baregps/privacy
https://appsbyonzy.dev/baregps/support
https://downloads.appsbyonzy.dev/baregps-ireland/manifest-v1.json
```

Whether the first two resolve to Notion is invisible to the app and App Store listing.

## App implementation plan

### New components

Suggested names, adjusted to the project’s UIKit architecture:

| Component | Responsibility |
|---|---|
| `OfflineMapManifest` | Codable manifest and file models |
| `OfflineMapStore` | Application Support paths, active/staging versions, backup exclusion, delete/activate |
| `OfflineMapDownloadManager` | Background `URLSession`, task restoration, progress, retry/cancel |
| `OfflineMapVerifier` | Byte length, SHA-256, MBTiles sanity checks |
| `OfflineMapAvailability` | Single source of truth for missing/downloading/verifying/ready/failed |
| `OfflineMapDownloadViewController` | First-run and Settings download UI |

Persist state in a small JSON file in Application Support rather than relying only on `UserDefaults`. Tasks may outlive the app process. Map each task identifier to pack version and destination filename.

### `AppDelegate` background-session hand-off

Implement:

```swift
application(_:handleEventsForBackgroundURLSession:completionHandler:)
```

Store the completion handler, recreate the session using its fixed identifier, and call the handler only after `urlSessionDidFinishEvents(forBackgroundURLSession:)` and after relevant file moves/state writes complete. This wiring is essential for reliable completion while the app was suspended or terminated by the system.

### Network behavior

- Use one fixed background-session identifier.
- Use download tasks, never a data task that holds a 741 MB response in memory.
- Set `allowsCellularAccess` from the person’s choice.
- Consider `allowsExpensiveNetworkAccess` and `allowsConstrainedNetworkAccess` explicitly.
- Do not set the transfer as discretionary when the person is actively waiting and expects it to start now.
- Schedule the seven file tasks together so iOS does not repeatedly relaunch the app for a serial chain of jobs.
- Validate HTTP status and expected MIME behavior.
- Use task descriptions or persisted task-ID mappings to recover identity after relaunch.

Apple cautions that repeatedly starting a new task only after the previous background task wakes the app can trigger increasing scheduling delays. Scheduling a small batch together fits this pack. See [Downloading files in the background](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background).

### Changes to `MapStyleURLProvider`

Refactor it to accept two roots:

1. bundled support-resource root for style, fonts, sprites, and GeoJSON;
2. optional installed MBTiles root from `OfflineMapStore`.

`openBareMapStyleURL()` returns `nil` or a clear “not installed” result until all required files are verified. When installed, it rewrites only the MBTiles URLs to Application Support and keeps other resources pointed at the bundle.

Do not partially enable OpenBareMap when only some databases exist.

### Changes to map-layer selection

- Keep online OpenTopo as the safe initial/default layer.
- When OpenBareMap is absent, selecting it presents the download UI.
- When downloading, selecting it presents progress.
- When ready, selecting it loads the resolved local style.
- If a previously installed pack becomes unreadable, fall back to an online style and explain what happened.

### Version/update rules

- Compare pack versions as structured versions, not arbitrary strings.
- The manifest declares the minimum compatible app version.
- Never delete the active pack before the replacement is verified and activated.
- Do not force a map update unless the old pack is genuinely incompatible or unsafe.
- Allow “Later” and keep the old map working.
- If the manifest cannot be reached, use the installed map.

### Security and robustness

- Compile an allow-list of expected HTTPS hostnames.
- Reject redirects to HTTP or unexpected hosts.
- Reject path traversal: manifest file names must be simple allow-listed names.
- Limit file count and maximum declared bytes.
- Verify SHA-256 after download.
- Do not trust ETag as the integrity digest, especially for multipart R2 uploads.
- Do not log full temporary paths or sensitive URL query tokens in production.
- Use file protection appropriate for large read-only map files; test map availability immediately after reboot before first unlock if that matters to the product.

## Recommended implementation sequence

### Phase 0 — evidence and release baseline

- [ ] Build an Archive of the current app.
- [ ] Record App Thinning Size Report values.
- [ ] Confirm the current bundled version opens every OpenBareMap layer/detail combination.
- [ ] Preserve a known-good 2.0 release candidate and checksums.
- [ ] Decide whether iOS 18.2 remains the minimum. This plan assumes yes.

**Exit criterion:** known baseline size and behavior.

### Phase 1 — hosting proof of concept

- [ ] Create R2 Standard bucket.
- [ ] Connect `downloads.appsbyonzy.dev`.
- [ ] Upload one non-production test file.
- [ ] Verify download, headers, byte count, SHA-256, interruption, and resumption.
- [ ] Estimate cost using expected installs × seven GETs plus manifest checks.

**Exit criterion:** a real iPhone can reliably download a large test object.

### Phase 2 — local storage and verification

- [ ] Implement manifest models.
- [ ] Implement Application Support paths and backup exclusion.
- [ ] Implement staging/final/active-version state.
- [ ] Implement SHA-256 and MBTiles sanity validation.
- [ ] Add unit tests for corrupt, missing, wrong-size, wrong-hash, and incompatible manifests.

**Exit criterion:** local fixtures install atomically and failures preserve the old version.

### Phase 3 — background downloader

- [ ] Implement one background `URLSession` and delegates.
- [ ] Restore task state at launch.
- [ ] Wire `AppDelegate` background completion events.
- [ ] Implement progress aggregation across seven files.
- [ ] Implement cancel, retry, cellular policy, and errors.
- [ ] Test force-quitting distinction: iOS generally does not continue background transfers after the person explicitly force-quits; UI/help text must not promise otherwise.

**Exit criterion:** download survives locking the phone, app suspension, ordinary system termination, network loss, and relaunch.

### Phase 4 — MapLibre integration

- [ ] Refactor `MapStyleURLProvider` for separate resource/MBTiles roots.
- [ ] Hide or gate OpenBareMap until the pack is complete.
- [ ] Test all seven MBTiles sources.
- [ ] Test app update while a pack is installed.
- [ ] Test deleting/reinstalling the app.

**Exit criterion:** installed external pack is visually and functionally equivalent to the bundled pack.

### Phase 5 — user interface

- [ ] First-run offer with exact size and Not Now.
- [ ] Persistent entry in layer menu/Settings.
- [ ] Progress, status, retry, cancel, remove, update.
- [ ] VoiceOver labels and Dynamic Type testing.
- [ ] Clear insufficient-storage and mobile-data wording.

**Exit criterion:** a nontechnical tester can install, interrupt, resume, use, update, and remove the map without instructions.

### Phase 6 — publish production assets

- [ ] Freeze pack version and hashes.
- [ ] Upload all versioned files.
- [ ] Independently redownload and verify all seven.
- [ ] Upload/update manifest last.
- [ ] Keep the previous production version online.
- [ ] Record an operations/recovery note with exact bucket and object keys.

**Exit criterion:** production manifest points only to complete verified objects.

### Phase 7 — TestFlight and App Review

- [ ] Internal TestFlight on at least two physical devices and network conditions.
- [ ] External TestFlight with a fresh-install tester.
- [ ] Verify privacy nutrition answers and privacy policy mention Cloudflare/R2 delivery where appropriate.
- [ ] Add App Review notes explaining that the optional offline map is data, its size, and exact steps to download it.
- [ ] Ensure the reviewer can use meaningful online app functionality without waiting for 982 MB.
- [ ] Submit the map-hosting URLs as working production URLs, not staging URLs requiring login.

**Exit criterion:** fresh TestFlight install completes the full workflow using production-equivalent hosting.

## Test matrix

| Scenario | Expected result |
|---|---|
| Fresh install, choose Not Now | Online app remains fully usable; offer remains available |
| Start on Wi‑Fi, lock phone | System continues/schedules background download and reconciles on return |
| Lose network midway | No corrupt activation; tasks wait/retry; clear state shown |
| Switch Wi‑Fi to cellular with cellular disabled | Transfer waits and explains why |
| Insufficient storage before start | No tasks start; required/free space shown |
| Storage fills midway | Staging is cleaned safely; old pack remains |
| Wrong server byte count | File rejected |
| Wrong SHA-256 | File rejected and retry offered |
| One of seven requests returns 404/HTML | Pack is not activated |
| App process killed by system | Session/state reconnect on relaunch |
| Person force-quits app | No promise of continued work; state reconciles next launch |
| New pack released | Optional update; current pack remains usable |
| Manifest server unavailable | Installed pack works; fresh user sees retryable error |
| App updated from 1.x/early 2.0 | No loss of GPX/logged hills/settings; map state migrates |
| Remove Offline Map | Only app-downloaded pack removed; user GPX/data untouched |
| App deleted | iOS removes sandbox and pack |

## App Store preparation beyond the map

The repository already contains draft marketing copy, privacy policy, and support-page content. Before submission:

- set marketing version to `2.0` and increment the build number;
- publish privacy and support pages at stable public HTTPS URLs;
- update the privacy policy to name Cloudflare as the delivery infrastructure if the final privacy review determines it is appropriate, noting that ordinary server logs may receive IP address, request time, URL, and user-agent/network metadata;
- verify App Privacy answers against actual SDK behavior, including MapLibre and online tile providers;
- confirm all map/data licences permit this form of redistribution and retain required attribution;
- provide App Review with a concise explanation and reproducible steps;
- create screenshots and metadata from the release UI, not an earlier build;
- verify signing, capabilities, location usage descriptions, background-location justification, and GPX document handling;
- run a clean Release build, archive, TestFlight, and crash-free fresh-install test.

The current privacy draft already explains that online services receive standard technical information and that offline data is stored locally. It should be revised after implementation so the wording precisely matches Cloudflare-hosted asset downloads.

## Release and rollback runbook

### Normal map release

1. Produce and test all seven MBTiles.
2. Choose a new immutable pack version.
3. Calculate sizes and SHA-256 values.
4. Upload to the new version path.
5. Download every object from the public hostname and verify it.
6. Publish the new manifest last.
7. Test with a production/TestFlight build.
8. Retain at least the previous version until adoption and stability are satisfactory.

### If a bad manifest is published

1. Do not overwrite already-versioned binary files.
2. Immediately restore the last known-good manifest.
3. Purge only the manifest URL from Cloudflare cache if necessary.
4. Verify from an unrelated network.
5. Publish a new pack version for corrected data; never silently replace binaries at the same immutable URL.

### If Cloudflare is unavailable or replaced

1. Upload identical versioned objects to the replacement host.
2. Verify hashes from the replacement’s public URLs.
3. Change URLs in the stable manifest, or move `downloads.appsbyonzy.dev` at DNS/proxy level.
4. Keep old URLs alive during DNS and cache transition.
5. No app update is required if the bootstrap manifest hostname remains reachable and host allow-list policy permits the replacement URLs. If it does not, ship an app update first.

## Decisions for the owner

These are the only significant choices needed before implementation:

1. **Minimum iOS:** keep iOS 18.2 (recommended for this release), or raise to iOS 26+ to consider Managed Background Assets.
2. **Delivery:** Cloudflare R2 in-app download (recommended), or retain the complete bundle for the fastest low-code submission.
3. **Cellular default:** Wi‑Fi only by default (recommended), with explicit opt-in to mobile data.
4. **First launch:** optional prompt/card (recommended), not a mandatory blocking download.
5. **Hostname:** `downloads.appsbyonzy.dev` or another stable subdomain you control.
6. **Map updates:** user-approved updates by default (recommended), not forced updates.

## Recommended decision, in one sentence

Keep iOS 18.2, ship a useful online-capable 2.0 app, host seven immutable MBTiles files in Cloudflare R2, fetch a versioned/hash-checked manifest at `downloads.appsbyonzy.dev`, download inside the app with background `URLSession`, store atomically in Application Support outside iCloud backup, and keep Notion for privacy/support pages only.

## Primary references

- [Apple — Maximum build file sizes](https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes)
- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple — Downloading files in the background](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background)
- [Apple — URLSessionDownloadTask](https://developer.apple.com/documentation/foundation/urlsessiondownloadtask)
- [Apple — Optimizing your app’s data for iCloud backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)
- [Apple — Background Assets](https://developer.apple.com/documentation/backgroundassets/)
- [Apple — Overview of Apple-hosted asset packs](https://developer.apple.com/help/app-store-connect/manage-asset-packs/overview-of-apple-hosted-asset-packs)
- [Cloudflare — R2 pricing](https://developers.cloudflare.com/r2/pricing/)
- [Cloudflare — R2 limits](https://developers.cloudflare.com/r2/platform/limits/)
- [Cloudflare — Public buckets and custom domains](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- [Cloudflare — Enable cache for an R2 bucket](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/)
- [Cloudflare — Upload objects](https://developers.cloudflare.com/r2/objects/upload-objects/)
- [Cloudflare — R2 consistency](https://developers.cloudflare.com/r2/reference/consistency/)

---

**Suggested next action:** make the six owner decisions above, then perform Phase 0 and the R2 proof of concept before changing the shipping app. This keeps the architectural decision reversible until both the real App Store archive size and real-device download behavior are known.
