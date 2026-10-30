# OpenBareMap R2 Release Runbook

## Fixed production locations

- Bucket: `baregps-production-assets`
- Public host: `https://downloads.appsbyonzy.dev`
- Manifest key: `baregps-ireland/manifest-v1.json`
- Versioned maps: `baregps-ireland/<pack-version>/maps/*.mbtiles`

Never overwrite a versioned object with changed bytes. A changed map requires a new pack version and path.

## 1. Generate and verify a release locally

From the repository root:

```bash
python3 Scripts/offline_map_release.py generate \
  /path/to/<pack-version>/maps \
  /path/to/manifest-v1.json \
  --pack-version <pack-version> \
  --map-version <map-version> \
  --minimum-app-version <minimum-app-version> \
  --published-at <YYYY-MM-DDT00:00:00Z>

python3 Scripts/offline_map_release.py verify-local \
  /path/to/<pack-version>/maps \
  /path/to/manifest-v1.json
```

Keep a copy of the generated manifest outside R2. Review every URL, byte size and SHA-256 value before upload.

## 2. Upload immutable map objects first

```bash
rclone copy \
  /path/to/<pack-version>/maps \
  r2:baregps-production-assets/baregps-ireland/<pack-version>/maps \
  --metadata \
  --metadata-set 'cache-control=public, max-age=31536000, immutable' \
  --metadata-set 'content-disposition=attachment' \
  --metadata-set 'content-type=application/octet-stream' \
  --s3-upload-cutoff 100M \
  --s3-chunk-size 100M \
  --progress
```

Do not publish the new manifest yet.

## 3. Verify the uploaded maps

Check headers and a byte range with `curl`. Then run:

```bash
python3 Scripts/offline_map_release.py verify-live /path/to/manifest-v1.json
```

All five files must pass before the manifest is published.

## 4. Publish the manifest last

```bash
rclone copyto \
  /path/to/manifest-v1.json \
  r2:baregps-production-assets/baregps-ireland/manifest-v1.json \
  --metadata \
  --metadata-set 'cache-control=no-cache' \
  --metadata-set 'content-type=application/json'
```

Fetch the public manifest and confirm it is byte-for-byte the intended file. If a Cloudflare Cache Rule is later added for JSON, purge only the full manifest URL.

## 5. Roll back a bad release

1. Select the saved last-good `manifest-v1.json`.
2. Verify its five versioned URLs still exist and match their hashes.
3. Upload that manifest to the fixed manifest key using the command above.
4. Purge only `https://downloads.appsbyonzy.dev/baregps-ireland/manifest-v1.json` if it was cached.
5. Fetch and inspect the public manifest again.
6. Confirm the app no longer offers the bad pack.
7. Publish corrected map bytes under a new pack version; never repair a released versioned object in place.

## 6. Routine safeguards

- List the bucket with `rclone lsl r2:baregps-production-assets` before and after every release.
- Keep R2 credentials and `rclone.conf` out of the app and repository.
- Keep local/off-R2 copies of the last-good manifest and map files.
- Configure an R2 budget alert in the Cloudflare dashboard.
- Test the final download on a second network.
