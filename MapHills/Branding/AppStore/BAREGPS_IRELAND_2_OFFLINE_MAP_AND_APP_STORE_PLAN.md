# BareGPS Ireland 2.0 — Step-by-Step Guide

**Made on:** 29 October 2026  
**Plan only:** Do not change the app or the live map host yet.  
**Main aim:** Ship a small app. Let the user get the full map from the web.

---

## 1. The short plan

The map is far too big to put in each app build.

We will do this:

1. Keep the small map files in the app.
2. Put the five huge map files in Cloudflare R2.
3. When the new app first starts, ask the user if they want the full map.
4. Do not start the large download until the user taps **Download Map**.
5. Use Wi-Fi by default.
6. Let the download run when the app is not on screen.
7. Check each file before the app uses it.
8. Keep the old map safe while a new map is being installed.
9. Add map controls to **Settings**.
10. Let the user check for a new map, update it, fix it, or remove it.

The app must still work if the user taps **Not Now**. It will use an online map until the full map is ready.

---

## 2. What is done now

The right map pack is:

```text
/Users/davidowens/Documents/Codex/2026-10-25/i-x20/outputs/OpenBareMap/ios/package/OpenBareMap.bundle
```

It has been put in the Xcode app.

The app then built with no errors.

The pack has the new map key, also called the legend. Do not lose it.

The R2 test file also works:

```text
https://downloads.appsbyonzy.dev/Placeholder.docx
```

The test gave:

| Test | Result |
|---|---|
| Web status | 200 — good |
| File size | 13,311 bytes |
| File type | Word file |
| Login asked for | No |
| Part download support | Yes |
| Host | Cloudflare |

This proves that the web name points to the R2 bucket.

It does **not** yet prove that a 679 MB file will download well on an iPhone. We must test a large file next.

---

## 3. The map files

The full pack has 43 files.

Its true size is:

```text
1,008,356,910 bytes
```

That is about 962 MiB. In plain terms, it is about 1 GB.

### The five big files

These five files go in R2:

| File | Size in bytes | Rough size |
|---|---:|---:|
| `basemap.mbtiles` | 679,026,688 | 648 MiB |
| `topography.mbtiles` | 191,774,720 | 183 MiB |
| `hillshade.mbtiles` | 105,943,040 | 101 MiB |
| `grid.mbtiles` | 9,764,864 | 9 MiB |
| `coast.mbtiles` | 8,953,856 | 9 MiB |
| **All five** | **995,463,168** | **About 949 MiB** |

### The small files

Keep these in the app:

- `style.json`
- `townlands.geojson`
- all font files
- all sprite files
- all credit and source text
- the small pack data files
- the full `legend` folder

All the small files come to about 12.9 MB.

### The new legend

Keep all three new legend art files:

| File | Size |
|---|---:|
| `openbaremap-legend.png` | 194,002 bytes |
| `openbaremap-legend@2x.png` | 207,887 bytes |
| `openbaremap-legend.svg` | 30,146 bytes |

The app now shows the PNG legend. Test it at full size and when zoomed in.

---

## 4. Hard words used in this guide

A few tech words can not be made clear with one short word. Here is what they mean.

### R2

R2 is the file store in Cloudflare. Think of it as a hard disk on the web.

### Bucket

A bucket is the top box in R2 that holds files.

The live bucket is:

```text
baregps-production-assets
```

### Object key

This is the full file name in the bucket.

For this key:

```text
test/large-test.bin
```

the live web link is:

```text
https://downloads.appsbyonzy.dev/test/large-test.bin
```

### MBTiles

An MBTiles file is a map held in one file. It is also a SQLite data file.

### Manifest

A manifest is a small JSON text file. It tells the app:

- which map is new;
- which files to get;
- where each file is;
- how big each file must be;
- the hash for each file.

### Hash or SHA-256

A hash is a long check code made from all bytes in a file.

If one byte is wrong, the hash will not match.

The app must not use a file if its hash is wrong.

### Staging

Staging is a safe temp place.

New map files go there first. The app checks them there. They do not go live until all five are good.

---

## 5. What the user will see

### First start after the app update

The app starts at once.

It shows an online map.

It then shows this box:

> **Get the Ireland Offline Map?**  
> Use OpenBareMap with no phone signal. The download is about 995 MB and will use about 1 GB on your phone. Wi-Fi is best.  
> **Download Map** — **Not Now**

Rules:

- Do not lock the user on this box.
- Do not start the download on its own.
- Do not use phone data with no clear yes from the user.
- If the user taps **Not Now**, the rest of the app must work.
- Do not show this box on each start.
- Keep a way to get the map in Settings.
- Keep a way to get the map from the map layer list.

### While the map is being fetched

Show:

- the percent done;
- bytes done and bytes left;
- **Waiting for Wi-Fi**, if that is the cause;
- **Downloading**;
- **Checking Files**;
- **Installing**;
- **Ready**;
- **Failed**, with a plain cause;
- a **Cancel** button;
- a **Try Again** button after a fail.

Do not show a firm time left. iOS may slow or pause the task.

### When the map is ready

The user can pick OpenBareMap.

The app shows:

- map version;
- map date;
- space used;
- **Check for Update**;
- **Remove Map**.

### If a new map is ready

Show:

> **A new Ireland map is ready.**  
> Your old map will still work if you tap Later.  
> **Update Map** — **Later**

Do not force a 1 GB map update unless the old map can no longer work with the app.

---

## 6. The map layer list

Keep OpenBareMap in the map list at all times.

Change its row based on state.

| State | What the row says | What a tap does |
|---|---|---|
| No map | OpenBareMap — Download needed | Opens the download screen |
| In progress | OpenBareMap — 42% | Opens progress |
| Ready | OpenBareMap | Loads the map |
| New map found | OpenBareMap — Update ready | Opens update screen |
| Bad file | OpenBareMap — Fix needed | Opens repair screen |

The app now tries to use OpenBareMap by default.

That must change.

If no full map is installed, start with OpenTopo or one safe online map.

Never send a blank map style to MapLibre.

---

## 7. The Settings screen

The app has an OpenBareMap part in Settings now.

Add a new block at the top of that part.

Call it:

```text
Offline Map
```

Show these rows:

1. **Status**
   - Not on this phone
   - Waiting for Wi-Fi
   - Downloading
   - Checking
   - Ready
   - Update ready
   - Fix needed

2. **Map Version**
   - Show the live map version.

3. **Map Date**
   - Show the map data date.

4. **Space Used**
   - Show the true size.

5. **Wi-Fi Only**
   - Switch on by default.

6. **Download Map**
   - Show if no map is on the phone.

7. **Resume**
   - Show if the work can go on.

8. **Try Again**
   - Show after a fail.

9. **Check for Update**
   - Show when a map is in use.

10. **Update Map**
    - Show if a new map is ready.

11. **Fix Map**
    - Get bad or lost files again.

12. **Remove Map**
    - Ask once more before delete.

Keep the old map detail switches below this new block.

A map detail switch only hides part of the map. It must not delete a map file.

---

## 8. Where the app will store the map

Use this app-only path:

```text
Library/Application Support/BareGPS/OfflineMaps/Ireland/
```

Use this shape:

```text
Ireland/
├── state.json
├── active.json
├── staging/
│   └── new-map-work/
└── packs/
    ├── old-map/
    └── new-map/
```

Do not use **Documents**. The user should not edit these files in the Files app.

Do not use **Caches** as the sole home. iOS may clear it.

Mark the map folder as **do not back up**. The user can get these files from R2 again. A 1 GB map should not fill iCloud backup.

Before a download starts:

1. Ask iOS how much free space is safe to use.
2. Add the bytes still to get.
3. Add room for safe work.
4. If there is not enough room, do not start.
5. Tell the user how much more room they need.

At first, ask for at least 1.25 to 1.5 GB of free space. Test this rule on a phone that is near full.

---

## 9. How the safe install works

This is key. Never swap in half a map.

Do these steps in this order:

1. Get the small manifest.
2. Check that the manifest is safe.
3. Make a new staging folder.
4. Start all five file tasks.
5. Put each file in the staging folder.
6. Check that the web call gave status 200.
7. Check that the file size is right.
8. Make the SHA-256 hash.
9. Check that the hash is right.
10. Open the file as SQLite.
11. Check that it has the MBTiles data it should have.
12. Check that all five files are there.
13. Move the full staged map to its final map folder.
14. Change `active.json` in one safe write.
15. Make the local map style.
16. Ask MapLibre to load it.
17. Check that it did load.
18. Only then may the app remove the old map.

If one step fails:

- do not touch the old live map;
- remove the bad staged work;
- tell the user what went wrong;
- give a **Try Again** button.

---

## 10. The file list the app gets from R2

The app will know one fixed web link:

```text
https://downloads.appsbyonzy.dev/baregps-ireland/manifest-v1.json
```

That file will list all five map files.

A short sample:

```json
{
  "schemaVersion": 1,
  "packID": "ie.appsbyonzy.baregps.ireland.openbaremap",
  "packVersion": "2.0.0-storage-r3",
  "mapVersion": "2.0.0",
  "minimumAppVersion": "2.0.0",
  "displayName": "Ireland Offline Map",
  "totalBytes": 995463168,
  "files": [
    {
      "sourceID": "basemap",
      "relativePath": "maps/basemap.mbtiles",
      "url": "https://downloads.appsbyonzy.dev/baregps-ireland/2.0.0-storage-r3/maps/basemap.mbtiles",
      "bytes": 679026688,
      "sha256": "cb2e6ec1ebe474563422e44db2c5d30c2efa7c73ebb55a262b85508710943431"
    }
  ]
}
```

The true file must list all five files.

The app must reject the manifest if:

- the format is too new;
- the pack ID is wrong;
- there are not five files;
- a file name is not one of the five known names;
- two rows use the same name;
- a name has `..` in it;
- a link is not HTTPS;
- a link is from the wrong host;
- a size is false or far too large;
- a hash is not a 64-digit hash;
- the map needs a newer app;
- the sum of file sizes does not match the total.

Make this file from the source data with a tool. Do not type each hash by hand.

---

## 11. How the app will get large files

Use an iOS background URL session.

This means iOS can do the web task when the app is not on screen.

Use file download tasks.

Do not load a 679 MB file into RAM.

The code must:

1. Use one fixed background task ID.
2. Save which task is for which map file.
3. Link back to tasks when the app starts.
4. Ask iOS for all tasks that still exist.
5. Match them with saved state.
6. Add all five tasks as one batch.
7. Track bytes for all five as one total.
8. move each temp file at once when iOS says it is done;
9. check the web status and the true last URL;
10. deal with stop, retry, and bad net;
11. call the iOS done block at the right time.

Add this app life hook:

```swift
application(
    _:handleEventsForBackgroundURLSession:completionHandler:
)
```

When iOS wakes the app:

1. Save the done block.
2. Link back to the URL session.
3. Deal with all file events.
4. Save file and app state.
5. Wait for `urlSessionDidFinishEvents`.
6. Call the done block on the main thread.

Do not tell the user that a forced quit will still work. If the user swipes the app away, iOS may stop the task.

---

## 12. All fail cases to plan for

| What goes wrong | What the app must do |
|---|---|
| No web link | Wait or show Try Again |
| Wi-Fi lost | Wait; do not break the staged map |
| Phone data blocked | Say Waiting for Wi-Fi |
| Low Data Mode | Obey it and say why the task waits |
| Web gives 404 | Keep old map; show server error |
| Web gives 403 | Keep old map; show access error |
| Web gives 500 | Keep old map; show Try Again |
| Web sends an HTML page | Reject it |
| Link moves to HTTP | Reject it |
| Link moves to a wrong host | Reject it |
| Not enough space | Do not start |
| Space runs out halfway | Clear failed staging only |
| File size is wrong | Reject that file |
| Hash is wrong | Delete bad staged file and retry |
| SQLite will not open | Reject the map |
| One of five files is lost | Do not turn the map on |
| App sleeps | Let iOS run the task |
| iOS kills the app | Link to tasks at next launch |
| User force quits | Check state on next launch |
| Manifest host is down | Keep an old map in use |
| Map is bad after install | Go back to online map; show Fix Map |
| App is updated mid-task | Use the same task ID and link back |
| User removes the map | Delete only map pack data |

Keep a small tech log for help.

The log may hold:

- file ID;
- web status;
- expected bytes;
- real bytes;
- check stage;
- short error code.

Do not log secret links, tokens, or more user data than is needed.

---

## 13. Cloudflare: what is there now

Cloudflare account:

- web zone: `appsbyonzy.dev`
- bucket: `baregps-production-assets`
- custom host: `downloads.appsbyonzy.dev`
- test key: `Placeholder.docx`

The root web link will not show a file list. A 404 at the root is normal.

This works:

```text
https://downloads.appsbyonzy.dev/Placeholder.docx
```

---

## 14. Cloudflare: click-by-click large test

Do this in Chrome.

### Part A — open the bucket

1. Open **Chrome**.
2. Click the web address bar.
3. Paste:

   ```text
   https://dash.cloudflare.com/?to=/:account/r2
   ```

4. Press **Return**.
5. If asked, sign in.
6. If asked which account, pick the account that owns `appsbyonzy.dev`.
7. Click the bucket named **baregps-production-assets**.
8. Find the page that lists files.
9. You should see **Placeholder.docx**.

Cloudflare may change the names of tabs and buttons. The key fact is that you are in the bucket and can see the file row.

### Part B — make a safe test folder

1. In the bucket file page, click **Upload**.
2. If there is a **Create folder** button, click it.
3. Name the folder:

   ```text
   test
   ```

4. If there is no folder button, that is fine. Upload a file with a key that starts with `test/`.

R2 does not have true folders. It treats the slash in a file key as a folder mark.

### Part C — make or pick a large test file

Use a file of at least 100 MB. A 300–700 MB test is better.

Do not use private work.

Do not use the real map for the first test unless you are ready to wait for upload.

Give it a clear name:

```text
large-download-test.bin
```

### Part D — upload it

1. Click **Upload**.
2. Click **Choose files**, or drag the file to the upload box.
3. Pick `large-download-test.bin`.
4. If asked for a path, use:

   ```text
   test/large-download-test.bin
   ```

5. Click the last **Upload** or **Start upload** button.
6. Do not close Chrome until it says the upload is done.
7. Go back to the file list.
8. Open the `test` group if one is shown.
9. Check that the file name and size look right.

### Part E — test the public link

The link should be:

```text
https://downloads.appsbyonzy.dev/test/large-download-test.bin
```

1. Open a new Chrome Incognito window.
2. Paste the link.
3. Press **Return**.
4. The download must start with no Cloudflare login.
5. Stop it once, then try it once more.
6. Test it on an iPhone in Safari too.
7. Test on normal home Wi-Fi.
8. If safe for your data plan, test a switch from Wi-Fi to phone data.

A browser test is not the full app test. It only proves that the host can serve a large file.

### Part F — remove the test later

When all tests are done:

1. Go back to the R2 bucket file list.
2. Find `test/large-download-test.bin`.
3. Click its menu.
4. Click **Delete**.
5. Read the name in the warning.
6. Make sure it is the test file.
7. Click the last **Delete** button.

The test file can be removed. Do not remove a live map file.

---

## 15. Cloudflare: live file layout

Use this file shape:

```text
baregps-ireland/
├── manifest-v1.json
└── 2.0.0-storage-r3/
    └── maps/
        ├── basemap.mbtiles
        ├── topography.mbtiles
        ├── hillshade.mbtiles
        ├── grid.mbtiles
        └── coast.mbtiles
```

Do not upload the legend for this release. It stays in the app.

Do not upload style, fonts, sprites, or townlands for this release. They stay in the app.

### Live file web data

For each map file use:

```text
Content-Type: application/octet-stream
Content-Disposition: attachment
Cache-Control: public, max-age=31536000, immutable
```

For the manifest use:

```text
Content-Type: application/json
Cache-Control: no-cache
```

The map files must not change once live.

If a map changes, use a new folder name.

Upload the manifest last.

### One Cloudflare limit that matters

The base map is 679,026,688 bytes.

Cloudflare says files over 512 MB are not cached on Free, Pro, and Business plans.

R2 can still serve the file.

R2 web egress is free at this time.

This is not a block, but the big file must be speed-tested from Ireland.

Do not split the file into chunks yet. That would make the app much more hard to build and test.

---

## 16. Cloudflare: click-by-click live upload

Do not do this until the app can use the files.

### Part A — make the path

1. Open Chrome.
2. Go to:

   ```text
   https://dash.cloudflare.com/?to=/:account/r2
   ```

3. Open **baregps-production-assets**.
4. Go to its file list.
5. Make or open `baregps-ireland`.
6. Make or open `2.0.0-storage-r3`.
7. Make or open `maps`.

If the dash does not give a folder button, upload with the full key. For example:

```text
baregps-ireland/2.0.0-storage-r3/maps/grid.mbtiles
```

### Part B — upload the five map files

Upload in this order:

1. `grid.mbtiles`
2. `coast.mbtiles`
3. `hillshade.mbtiles`
4. `topography.mbtiles`
5. `basemap.mbtiles`

The order is not a code rule. It lets you prove the small files first.

For each file:

1. Click **Upload**.
2. Pick the file from the final map pack.
3. Check the full object key.
4. Start upload.
5. Wait for done.
6. Check the shown byte size.
7. Do not rename it after upload.

For large, repeat uploads, use a safe upload tool in a later ops step. The dash is fine for the first live set if it completes with no fault.

### Part C — check each public link

Test these links:

```text
https://downloads.appsbyonzy.dev/baregps-ireland/2.0.0-storage-r3/maps/grid.mbtiles
https://downloads.appsbyonzy.dev/baregps-ireland/2.0.0-storage-r3/maps/coast.mbtiles
https://downloads.appsbyonzy.dev/baregps-ireland/2.0.0-storage-r3/maps/hillshade.mbtiles
https://downloads.appsbyonzy.dev/baregps-ireland/2.0.0-storage-r3/maps/topography.mbtiles
https://downloads.appsbyonzy.dev/baregps-ireland/2.0.0-storage-r3/maps/basemap.mbtiles
```

For each one, check:

- status is 200;
- size is exact;
- hash is exact;
- no login page;
- no HTML error page.

### Part D — upload the manifest last

Only do this when all five files pass.

1. Go back to `baregps-ireland`.
2. Click **Upload**.
3. Pick `manifest-v1.json`.
4. Make sure its key is:

   ```text
   baregps-ireland/manifest-v1.json
   ```

5. Upload it.
6. Open:

   ```text
   https://downloads.appsbyonzy.dev/baregps-ireland/manifest-v1.json
   ```

7. Check that it shows JSON, not HTML.
8. Test it in the app test build.

---

## 17. Build work: exact order

Do not try to build all parts at once.

### Step 1 — save a known good build

1. Open Xcode.
2. Open the BareGPS Ireland project.
3. Pick the BareGPS scheme.
4. Pick a real iPhone or a generic iOS device.
5. Click **Product**.
6. Click **Archive**.
7. Wait for the archive.
8. Keep this full-map archive as the old known-good test.
9. Export the App Thinning Size Report.
10. Save map screenshots at key zoom levels.
11. Open and test the new legend.

Pass rule:

- the full old form works;
- the new map art is right;
- the new legend is right;
- the archive size is known.

### Step 2 — build the map store

Add code for:

- paths;
- staging;
- pack folders;
- active file;
- backup block;
- safe move;
- old map roll back;
- map remove.

Write tests first for bad and half-done cases.

Pass rule:

- bad work can not harm the old map.

### Step 3 — build the manifest check

Add code that reads the small JSON file.

Reject all bad data listed in this guide.

Pass rule:

- no bad path, wrong host, wrong hash, or odd file can get to the download step.

### Step 4 — build the file checks

Add:

- byte size check;
- SHA-256;
- SQLite open test;
- MBTiles table check;
- expected source check.

Pass rule:

- all five true files pass;
- each false test file fails.

### Step 5 — build the background download

Add the URL session and app life hook.

Test:

- app lock;
- app sleep;
- loss of Wi-Fi;
- iOS kill;
- app start;
- cancel;
- retry.

Pass rule:

- the task can come back after the app goes away.

### Step 6 — link it to MapLibre

Change the map style code so:

- small files come from the app;
- five MBTiles files come from Application Support;
- no map means no OpenBareMap style;
- old map stays live until new map passes;
- online map is used if the full map is not ready.

Pass rule:

- the fetched map looks the same as the old full-pack build.

### Step 7 — add the screens

Add:

- first start offer;
- map layer states;
- Settings rows;
- progress;
- fail text;
- update;
- fix;
- remove.

Pass rule:

- a person who has not read this guide can use all of it.

### Step 8 — make the app small

Remove the five huge MBTiles files from Copy Bundle Resources.

Keep all small files and the full new legend.

Make a clean archive.

Open the archive and check:

- five MBTiles are not in the app;
- style is in the app;
- fonts are in the app;
- sprites are in the app;
- townlands are in the app;
- the new legend is in the app.

---

## 18. Test list

### Code tests

Use Swift Testing.

Test:

- good manifest;
- bad JSON;
- bad pack ID;
- bad version;
- bad host;
- HTTP link;
- `..` in a path;
- lost file;
- same file twice;
- wrong file count;
- wrong total;
- wrong bytes;
- wrong hash;
- bad SQLite;
- bad MBTiles;
- safe stage;
- safe live swap;
- old map stays after fail;
- remove map only;
- do-not-back-up flag;
- app task state restore.

### Screen tests

Use XCUIAutomation.

Test:

- first offer;
- Not Now;
- Download Map;
- Settings path;
- map layer path;
- progress;
- cancel;
- retry;
- update;
- Later;
- remove and warn;
- fix;
- large text;
- VoiceOver;
- new legend.

### Real phone tests

Test at least:

1. New app install.
2. App update from old build.
3. Tap Not Now.
4. Start on Wi-Fi.
5. Lock phone.
6. Lose Wi-Fi.
7. Get Wi-Fi back.
8. Switch to phone data with Wi-Fi Only on.
9. Turn phone data on by choice.
10. Start with low free space.
11. Fill disk in the middle.
12. Feed one 404.
13. Feed one HTML page.
14. Feed one wrong hash.
15. Let iOS kill the app.
16. Start app once more.
17. Update map with old map still live.
18. Turn R2 off in a test.
19. Use the old map with no web.
20. Remove map.
21. Check that GPX files and hill logs stay safe.
22. Check the new legend.

---

## 19. App Store: plain step-by-step

### Part A — app facts

Keep the same bundle ID if this is an update:

```text
com.DavidOwens1513.BareGPSIreland.MapHills
```

Set a clear app version, such as:

```text
2.0.0
```

Raise the build number from 104.

Do not reuse a build number.

Keep iOS 18.2 unless there is a good cause to drop old phones.

### Part B — web pages

Put these pages on the web:

```text
https://appsbyonzy.dev/baregps/privacy
https://appsbyonzy.dev/baregps/support
```

The privacy page must say:

- the app can get a 1 GB map;
- the map is kept on the phone;
- the map is not put in normal iCloud backup;
- the user can remove it;
- Cloudflare R2 sends the files;
- Cloudflare may see the IP, time, URL, browser/app type, and net facts;
- online map hosts may see normal web call data;
- no app account is needed.

The help page must say how to:

- get the map;
- wait for Wi-Fi;
- allow phone data;
- retry;
- fix;
- update;
- remove.

### Part C — make a Release archive

1. Open Xcode.
2. Pick the app scheme.
3. Pick **Any iOS Device** if that is the valid archive choice.
4. Click **Product**.
5. Click **Clean Build Folder** if needed.
6. Click **Product**.
7. Click **Archive**.
8. Wait for Organizer.
9. Click the new archive.
10. Click **Validate App**.
11. Fix all errors.
12. Look at the app size.
13. Check the five big files are not in the app.

### Part D — send to App Store Connect

1. In Xcode Organizer, pick the right archive.
2. Click **Distribute App**.
3. Pick **App Store Connect**.
4. Pick **Upload**.
5. Keep the normal sign and upload choices unless Xcode shows a clear cause not to.
6. Read the summary.
7. Click **Upload**.
8. Wait for done.

### Part E — fill in App Store Connect

1. Open Chrome.
2. Go to:

   ```text
   https://appstoreconnect.apple.com/
   ```

3. Sign in.
4. Click **My Apps**.
5. Click **BareGPS Ireland**.
6. Click the new iOS app version.
7. Add version `2.0.0` if it is not there.
8. Fill in:
   - app text;
   - key words;
   - help URL;
   - privacy URL;
   - age rate;
   - price;
   - land/area where it is sold;
   - app privacy answers;
   - code and web use answers.
9. Pick the build you sent.
10. Fill in the review contact name, phone, and email.
11. Add clear review notes.
12. Save each page.

### Part F — screen shots

Take shots from the true release build.

Show:

- main map;
- hill info;
- GPX work;
- map layer list;
- offline map offer;
- offline map Settings.

Do not make it look as if the 1 GB map is in the app at first install.

App Store Connect asks for at least one valid iPhone shot and can take up to ten for each needed size.

Use the size that App Store Connect asks for on that day.

### Part G — TestFlight

1. In App Store Connect, click **TestFlight**.
2. Wait for the build to finish its web check.
3. Answer the code use question if asked.
4. Add your own test group.
5. Add at least two real iPhones if you can.
6. Test a new install.
7. Test an update from the old app.
8. Check GPX files, hill logs, and Settings stay safe.
9. Get the full live map from R2.
10. Try stop, loss of Wi-Fi, and retry.
11. Ask one new person to test with no help.
12. For an outside test group, send the build to Beta App Review if asked.

Do not change a live map file after this test. If the bytes change, give it a new map version.

### Part H — App Review notes

Use text like this:

> BareGPS Ireland works at once with online map layers. The Ireland Offline Map is an optional map data download. It is not code. To test it, tap the map layer button, tap OpenBareMap, then tap Download Map. It can also be found in Settings, OpenBareMap, Offline Map. The download is about 995 MB, so Wi-Fi is best. No account is needed. The user can view progress, retry, update, fix, or remove the map.

Also tell the review team:

- the app uses back location only for a GPX walk that the user starts;
- no login is needed;
- the app works without the large map download;
- where the map screen is;
- how to test each key task.

### Part I — send for review

1. Check all red or lost fields.
2. Check the right build is picked.
3. Pick **Manual Release** for this large update.
4. Click **Add for Review**.
5. Open the draft review set.
6. Read the list once more.
7. Click **Submit for Review**.
8. Watch for a note from Apple.
9. Reply with clear click steps if they ask.
10. When it is passed, test the live R2 links once more.
11. Then click the manual release button.

A slow phased app release can help, but the map manifest is its own live switch. Do not point all users to a new map until the app that can read it is live and tested.

---

## 20. How to ship a new map later

Do this each time:

1. Make the new map.
2. Give it a new version.
3. Run all map checks.
4. Make exact byte and hash data.
5. Test it with the app on a Mac and iPhone.
6. Upload to a new R2 path.
7. Do not change an old path.
8. Fetch each file from the public host.
9. Check size and hash.
10. Test with TestFlight.
11. Upload the new manifest last.
12. Keep the old map files for a safe time.
13. Watch fail reports.

---

## 21. If a bad map goes live

1. Do not delete the old map.
2. Put the last good manifest back.
3. Clear only the manifest from Cloudflare cache if needed.
4. Test from a net link that is not logged in to Cloudflare.
5. Make a new map version for the fix.
6. Do not put new bytes at the old file link.

---

## 22. If Cloudflare has a fault

The app must keep an installed map in use.

For a new user:

- show a plain web fault;
- keep online map use;
- show **Try Again**.

If R2 is moved one day, keep this host name:

```text
downloads.appsbyonzy.dev
```

Move the host behind the scenes.

If a brand-new host is needed, add it to the app’s safe host list before the manifest starts to use it.

---

## 23. Choices to sign off

Pick and write down these choices before code work:

1. Use `downloads.appsbyonzy.dev` for live map files: **Yes / No**
2. Use Wi-Fi only by default: **Yes / No**
3. Let the user turn phone data on: **Yes / No**
4. Let the user tap Not Now: **Yes / No**
5. Ask before each 1 GB map update: **Yes / No**
6. Use OpenTopo when no full map is on the phone: **Yes / No**
7. Keep the same app bundle ID: **Yes / No**
8. Use the two web links shown for help and privacy: **Yes / No**
9. Use manual App Store release for 2.0: **Yes / No**

The best set is **Yes** to all nine.

---

## 24. The next task

Do this next, and only this:

1. Make a large test file with no private data.
2. Upload it to:

   ```text
   test/large-download-test.bin
   ```

3. Test this link:

   ```text
   https://downloads.appsbyonzy.dev/test/large-download-test.bin
   ```

4. Test it on a real iPhone.
5. Write down:
   - file size;
   - time to get it;
   - if stop and retry worked;
   - if Wi-Fi loss worked;
   - if the hash matched.
6. Keep the app code as it is until this test is passed.

When that passes, build the app work in this order:

1. safe file store;
2. manifest check;
3. file check;
4. background download;
5. MapLibre link;
6. user screens;
7. small release archive;
8. TestFlight;
9. App Review.

---

## 25. Main source links

- [Apple: Download files in the back](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background)
- [Apple: App file size rules](https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes/)
- [Apple: App Store work flow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [Apple: Send an app for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)
- [Apple: Screen shot rules](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple: App Review rules](https://developer.apple.com/app-store/review/guidelines/)
- [Cloudflare: Public R2 buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/)
- [Cloudflare: R2 cache](https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2/)
- [Cloudflare: R2 price](https://developers.cloudflare.com/r2/pricing/)
- [Cloudflare: R2 limits](https://developers.cloudflare.com/r2/platform/limits/)
