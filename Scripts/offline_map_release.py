#!/usr/bin/env python3
"""Generate or verify a BareGPS Ireland OpenBareMap release manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path


PACK_ID = "ie.appsbyonzy.baregps.ireland.openbaremap"
PUBLIC_ROOT = "https://downloads.appsbyonzy.dev/baregps-ireland"
BUFFER_SIZE = 8 * 1024 * 1024


@dataclass(frozen=True)
class MapFile:
    source_id: str
    name: str


MAP_FILES = (
    MapFile("basemap", "basemap.mbtiles"),
    MapFile("topography", "topography.mbtiles"),
    MapFile("hillshade", "hillshade.mbtiles"),
    MapFile("irish-grid", "grid.mbtiles"),
    MapFile("coast", "coast.mbtiles"),
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(BUFFER_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


def validate_mbtiles(path: Path) -> None:
    try:
        with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as database:
            result = database.execute("PRAGMA quick_check").fetchone()
            if result != ("ok",):
                raise ValueError(f"SQLite quick_check failed for {path.name}: {result}")
            tables = {
                row[0]
                for row in database.execute(
                    "SELECT name FROM sqlite_master WHERE type = 'table'"
                )
            }
            missing = {"metadata", "tiles"} - tables
            if missing:
                raise ValueError(f"{path.name} lacks table(s): {', '.join(sorted(missing))}")
            if database.execute("SELECT 1 FROM metadata LIMIT 1").fetchone() is None:
                raise ValueError(f"{path.name} has no metadata rows")
            if database.execute("SELECT 1 FROM tiles LIMIT 1").fetchone() is None:
                raise ValueError(f"{path.name} has no tile rows")
    except sqlite3.DatabaseError as error:
        raise ValueError(f"{path.name} is not a valid SQLite database: {error}") from error


def read_release_files(maps_directory: Path, pack_version: str) -> list[dict[str, object]]:
    expected_names = {item.name for item in MAP_FILES}
    actual_names = {path.name for path in maps_directory.iterdir() if path.is_file()}
    missing = expected_names - actual_names
    unexpected = actual_names - expected_names
    if missing or unexpected:
        details = []
        if missing:
            details.append(f"missing: {', '.join(sorted(missing))}")
        if unexpected:
            details.append(f"unexpected: {', '.join(sorted(unexpected))}")
        raise ValueError("Invalid maps directory (" + "; ".join(details) + ")")

    records = []
    for item in MAP_FILES:
        path = maps_directory / item.name
        validate_mbtiles(path)
        records.append(
            {
                "sourceID": item.source_id,
                "relativePath": f"maps/{item.name}",
                "url": f"{PUBLIC_ROOT}/{pack_version}/maps/{item.name}",
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    return records


def generate(args: argparse.Namespace) -> None:
    maps_directory = args.maps_directory.resolve()
    if not maps_directory.is_dir():
        raise ValueError(f"Maps directory does not exist: {maps_directory}")
    files = read_release_files(maps_directory, args.pack_version)
    manifest = {
        "schemaVersion": 1,
        "packID": PACK_ID,
        "packVersion": args.pack_version,
        "mapVersion": args.map_version,
        "minimumAppVersion": args.minimum_app_version,
        "displayName": args.display_name,
        "totalBytes": sum(int(record["bytes"]) for record in files),
        "publishedAt": args.published_at,
        "files": files,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {args.output} ({args.output.stat().st_size} bytes)")
    print(f"Pack bytes: {manifest['totalBytes']}")
    for record in files:
        print(f"{record['sha256']}  {record['relativePath']}  {record['bytes']}")


def load_manifest(path: Path) -> dict[str, object]:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != 1 or manifest.get("packID") != PACK_ID:
        raise ValueError("Manifest schemaVersion or packID is invalid")
    files = manifest.get("files")
    if not isinstance(files, list) or len(files) != len(MAP_FILES):
        raise ValueError("Manifest must contain exactly five files")
    if manifest.get("totalBytes") != sum(int(record["bytes"]) for record in files):
        raise ValueError("Manifest totalBytes does not equal its file sizes")
    return manifest


def verify_local(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    for record in manifest["files"]:
        path = args.maps_directory / Path(str(record["relativePath"])).name
        if not path.is_file():
            raise ValueError(f"Missing local file: {path}")
        validate_mbtiles(path)
        size = path.stat().st_size
        digest = sha256_file(path)
        if size != record["bytes"] or digest != record["sha256"]:
            raise ValueError(f"Size or SHA-256 mismatch: {path.name}")
        print(f"OK local  {path.name}  {size}  {digest}")


def verify_live(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.manifest)
    for record in manifest["files"]:
        request = urllib.request.Request(
            str(record["url"]),
            headers={
                "User-Agent": "BareGPS-OpenBareMap-Release-Verifier/1.0",
                "Accept": "application/octet-stream, application/json",
            },
            method="GET",
        )
        digest = hashlib.sha256()
        received = 0
        with urllib.request.urlopen(request) as response:
            if response.status != 200:
                raise ValueError(f"HTTP {response.status}: {record['url']}")
            while chunk := response.read(BUFFER_SIZE):
                received += len(chunk)
                digest.update(chunk)
        if received != record["bytes"] or digest.hexdigest() != record["sha256"]:
            raise ValueError(f"Live size or SHA-256 mismatch: {record['url']}")
        print(f"OK live   {record['sourceID']}  {received}  {digest.hexdigest()}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)

    generate_parser = commands.add_parser("generate", help="Validate MBTiles and write a manifest")
    generate_parser.add_argument("maps_directory", type=Path)
    generate_parser.add_argument("output", type=Path)
    generate_parser.add_argument("--pack-version", required=True)
    generate_parser.add_argument("--map-version", required=True)
    generate_parser.add_argument("--minimum-app-version", required=True)
    generate_parser.add_argument("--published-at", required=True, help="UTC ISO-8601 value")
    generate_parser.add_argument("--display-name", default="Ireland Offline Map")
    generate_parser.set_defaults(function=generate)

    local_parser = commands.add_parser("verify-local", help="Verify files against a manifest")
    local_parser.add_argument("maps_directory", type=Path)
    local_parser.add_argument("manifest", type=Path)
    local_parser.set_defaults(function=verify_local)

    live_parser = commands.add_parser("verify-live", help="Download and hash every manifest URL")
    live_parser.add_argument("manifest", type=Path)
    live_parser.set_defaults(function=verify_live)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        args.function(args)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
