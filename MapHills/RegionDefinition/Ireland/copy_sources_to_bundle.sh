#!/usr/bin/env bash
set -euo pipefail

SRC="$HOME/Desktop/baregps ireland 2.0"
DST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReferenceData"

if [ ! -d "$SRC" ]; then
  echo "[copy_sources_to_bundle] Source folder not found: $SRC"
  echo "[copy_sources_to_bundle] Skipping copy. Create the folder to enable data bundling."
  exit 0
fi

mkdir -p "$DST"

echo "[copy_sources_to_bundle] Copying from: $SRC"
echo "[copy_sources_to_bundle]            to: $DST"

rsync -av --delete --exclude ".DS_Store" "$SRC/" "$DST/"

echo "[copy_sources_to_bundle] Done."
