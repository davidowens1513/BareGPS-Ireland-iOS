#!/usr/bin/env python3
import argparse
import csv
import json
import math
import re
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
IRELAND_ROOT = REPO_ROOT / "MapHills" / "RegionDefinition" / "Ireland"
REFERENCE_DATA = IRELAND_ROOT / "ReferenceData"
APP_RESOURCES = IRELAND_ROOT / "Resources"
DESKTOP_DATA = Path.home() / "Desktop" / "BareGPSIrelandDataFiles"

CURATED_OUTSCAPE_MINIMUM_LENGTH_KILOMETERS = 2.0
CURATED_OUTSCAPE_NAME_PATTERN = re.compile(r"\b(walk|trail|loop|way|greenway|towpath)\b", re.IGNORECASE)
DATA_FILE_NAMES = [
    "RegionPeakDataset.json",
    "MountainViewsStartPoints.json",
    "SportIrelandStartPoints.json",
    "CoillteStartPoints.json",
    "OutscapeTrailStartPoints.json",
    "CoillteTrailSummaries.json",
    "SportIrelandTrailSummaries.json",
    "OutscapeTrailSummaries.json",
    "SportIrelandTrailIDByStartPlaceID.json",
]


def normalized_header(value):
    return "".join(character for character in value.strip().lstrip("\ufeff").lower() if character.isalnum())


def read_csv_rows(path):
    with path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        rows = []
        for row in reader:
            rows.append({normalized_header(key): (value or "").strip() for key, value in row.items()})
        return rows


def first_value(row, *names):
    for name in names:
        value = row.get(name)
        if value is not None:
            return value.strip()
    return ""


def optional_float(value):
    value = str(value or "").strip()
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def required_float(value):
    result = optional_float(value)
    if result is None:
        raise ValueError(f"Expected numeric value, got {value!r}")
    return result


def strip_none_values(value):
    if isinstance(value, dict):
        return {
            key: strip_none_values(nested_value)
            for key, nested_value in value.items()
            if nested_value is not None
        }
    if isinstance(value, list):
        return [strip_none_values(item) for item in value]
    return value


def json_dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as json_file:
        json.dump(strip_none_values(value), json_file, ensure_ascii=False, indent=2)
        json_file.write("\n")


def load_json(path):
    with path.open("r", encoding="utf-8") as json_file:
        return json.load(json_file)


def validate_data_file(path):
    text = path.read_text(encoding="utf-8")
    data = json.loads(text)
    if ": null" in text:
        raise ValueError(f"{path.name} contains null fields")
    if '"trailID"' in text:
        raise ValueError(f"{path.name} contains embedded trailID fields")
    if not isinstance(data, (list, dict)):
        raise ValueError(f"{path.name} must contain a JSON array or object")
    return len(data)


def validate_data_directory(directory):
    missing_files = [file_name for file_name in DATA_FILE_NAMES if not (directory / file_name).exists()]
    if missing_files:
        raise FileNotFoundError(f"Missing data files in {directory}: {', '.join(missing_files)}")

    return {
        file_name: validate_data_file(directory / file_name)
        for file_name in DATA_FILE_NAMES
    }


def sync_desktop_source_to_bundle():
    counts = validate_data_directory(DESKTOP_DATA)
    APP_RESOURCES.mkdir(parents=True, exist_ok=True)
    for file_name in DATA_FILE_NAMES:
        shutil.copy2(DESKTOP_DATA / file_name, APP_RESOURCES / file_name)
    print(f"Copied canonical Desktop JSON data from {DESKTOP_DATA} to {APP_RESOURCES}")
    for file_name, count in counts.items():
        print(f"{file_name}: {count}")


def coordinate(latitude, longitude):
    return {
        "latitude": latitude,
        "longitude": longitude,
    }


def coordinate_from_geojson_position(position):
    if not isinstance(position, list) or len(position) < 2:
        return None
    longitude = optional_float(position[0])
    latitude = optional_float(position[1])
    if latitude is None or longitude is None:
        return None
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        return None
    return coordinate(latitude, longitude)


def trail_coordinate_segments(geometry):
    geometry_type = geometry.get("type")
    coordinates = geometry.get("coordinates")
    if geometry_type == "LineString":
        segment = [point for point in (coordinate_from_geojson_position(position) for position in coordinates or []) if point]
        return [segment] if len(segment) > 1 else None
    if geometry_type == "MultiLineString":
        segments = []
        for coordinate_group in coordinates or []:
            segment = [point for point in (coordinate_from_geojson_position(position) for position in coordinate_group) if point]
            if len(segment) > 1:
                segments.append(segment)
        return segments or None
    return None


def point_coordinate(geometry):
    if geometry.get("type") != "Point":
        return None
    return coordinate_from_geojson_position(geometry.get("coordinates"))


def string_value(value):
    if value is None:
        return None
    return str(value)


def double_value(value):
    return optional_float(value)


def outscape_feature_passes_curated_subset(properties):
    length_kilometers = double_value(properties.get("Length"))
    if length_kilometers is None or length_kilometers < CURATED_OUTSCAPE_MINIMUM_LENGTH_KILOMETERS:
        return False
    name = (string_value(properties.get("Name")) or "").strip()
    return CURATED_OUTSCAPE_NAME_PATTERN.search(name) is not None


def irish_grid_reference(easting, northing):
    if easting < 0 or northing < 0:
        return None
    e100k = math.floor(easting / 100000)
    n100k = math.floor(northing / 100000)
    if not (0 <= e100k <= 4 and 0 <= n100k <= 4):
        return None
    square_index = (4 - n100k) * 5 + e100k
    letters = "ABCDEFGHJKLMNOPQRSTUVWXYZ"
    if square_index < 0 or square_index >= len(letters):
        return None
    e_remainder = round(easting) % 100000
    n_remainder = round(northing) % 100000
    return f"{letters[square_index]} {e_remainder:05d} {n_remainder:05d}"


def transverse_mercator_projection(
    latitude_radians,
    longitude_radians,
    semi_major_axis,
    semi_minor_axis,
    scale_factor,
    origin_latitude_degrees,
    origin_longitude_degrees,
    false_northing,
    false_easting,
):
    e2 = 1 - (semi_minor_axis * semi_minor_axis) / (semi_major_axis * semi_major_axis)
    lat0 = math.radians(origin_latitude_degrees)
    lon0 = math.radians(origin_longitude_degrees)
    n = (semi_major_axis - semi_minor_axis) / (semi_major_axis + semi_minor_axis)
    sin_lat = math.sin(latitude_radians)
    cos_lat = math.cos(latitude_radians)
    tan_lat = math.tan(latitude_radians)
    nu = semi_major_axis * scale_factor / math.sqrt(1 - e2 * sin_lat * sin_lat)
    rho = semi_major_axis * scale_factor * (1 - e2) / math.pow(1 - e2 * sin_lat * sin_lat, 1.5)
    eta2 = nu / rho - 1
    meridional_arc = semi_minor_axis * scale_factor * (
        (1 + n + 1.25 * n * n + 1.25 * n * n * n) * (latitude_radians - lat0)
        - (3 * n + 3 * n * n + 2.625 * n * n * n) * math.sin(latitude_radians - lat0) * math.cos(latitude_radians + lat0)
        + (1.875 * n * n + 1.875 * n * n * n) * math.sin(2 * (latitude_radians - lat0)) * math.cos(2 * (latitude_radians + lat0))
        - (35.0 / 24.0) * n * n * n * math.sin(3 * (latitude_radians - lat0)) * math.cos(3 * (latitude_radians + lat0))
    )
    d_lon = longitude_radians - lon0
    i = meridional_arc + false_northing
    ii = nu / 2 * sin_lat * cos_lat
    iii = nu / 24 * sin_lat * math.pow(cos_lat, 3) * (5 - tan_lat * tan_lat + 9 * eta2)
    iiia = nu / 720 * sin_lat * math.pow(cos_lat, 5) * (61 - 58 * tan_lat * tan_lat + math.pow(tan_lat, 4))
    iv = nu * cos_lat
    v = nu / 6 * math.pow(cos_lat, 3) * (nu / rho - tan_lat * tan_lat)
    vi = nu / 120 * math.pow(cos_lat, 5) * (5 - 18 * tan_lat * tan_lat + math.pow(tan_lat, 4) + 14 * eta2 - 58 * tan_lat * tan_lat * eta2)
    northing = i + ii * math.pow(d_lon, 2) + iii * math.pow(d_lon, 4) + iiia * math.pow(d_lon, 6)
    easting = false_easting + iv * d_lon + v * math.pow(d_lon, 3) + vi * math.pow(d_lon, 5)
    return easting, northing


def tm65_irish_grid_easting_northing(latitude, longitude):
    a = 6378137.0
    b = 6356752.3141
    e2 = 1 - (b * b) / (a * a)
    lat = math.radians(latitude)
    lon = math.radians(longitude)
    nu = a / math.sqrt(1 - e2 * math.pow(math.sin(lat), 2))
    x1 = nu * math.cos(lat) * math.cos(lon)
    y1 = nu * math.cos(lat) * math.sin(lon)
    z1 = (nu * (1 - e2)) * math.sin(lat)

    tx = -482.5
    ty = 130.6
    tz = -564.6
    scale = -8.15e-6
    rx = math.radians(1.042 / 3600)
    ry = math.radians(0.214 / 3600)
    rz = math.radians(0.631 / 3600)

    x2 = tx + (1 + scale) * x1 + (-rz) * y1 + ry * z1
    y2 = ty + rz * x1 + (1 + scale) * y1 + (-rx) * z1
    z2 = tz + (-ry) * x1 + rx * y1 + (1 + scale) * z1

    airy_a = 6377340.189
    airy_b = 6356034.447
    airy_e2 = 1 - (airy_b * airy_b) / (airy_a * airy_a)
    p = math.sqrt(x2 * x2 + y2 * y2)
    lat2 = math.atan2(z2, p * (1 - airy_e2))
    previous_lat = 0.0

    while abs(lat2 - previous_lat) > 1e-10:
        previous_lat = lat2
        nu2 = airy_a / math.sqrt(1 - airy_e2 * math.pow(math.sin(lat2), 2))
        lat2 = math.atan2(z2 + airy_e2 * nu2 * math.sin(lat2), p)

    lon2 = math.atan2(y2, x2)
    return transverse_mercator_projection(
        lat2,
        lon2,
        airy_a,
        airy_b,
        1.000035,
        53.5,
        -8.0,
        250000,
        200000,
    )


def generated_grid_reference(latitude, longitude):
    projected = tm65_irish_grid_easting_northing(latitude, longitude)
    return irish_grid_reference(projected[0], projected[1]) or ""


def build_peaks():
    peaks = []
    for row in read_csv_rows(APP_RESOURCES / "RegionPeakDataset.csv"):
        try:
            peaks.append({
                "name": first_value(row, "hillname", "placenameen"),
                "mvIndex": first_value(row, "mvindex"),
                "latitude": required_float(first_value(row, "latitude")),
                "longitude": required_float(first_value(row, "longitude")),
                "heightM": required_float(first_value(row, "metres", "height")),
                "prominenceM": required_float(first_value(row, "prominence", "drop")),
                "classification": first_value(row, "classification", "province").strip('"'),
                "administrativeAreaName": first_value(row, "countyies", "countiesin"),
                "rangeName": first_value(row, "range", "region", "subrange"),
                "regionalSubdivisionName": first_value(row, "province"),
                "alternateHillName": first_value(row, "althillname", "placenamega"),
                "highpointAreaNames": first_value(row, "chpof"),
                "projectedEastingMeters": optional_float(first_value(row, "easting")),
                "projectedNorthingMeters": optional_float(first_value(row, "northing")),
            })
        except ValueError:
            continue
    return peaks


def build_start_places(csv_name, provider):
    start_places = []
    for row in read_csv_rows(REFERENCE_DATA / f"{csv_name}.csv"):
        latitude = optional_float(first_value(row, "latitude"))
        longitude = optional_float(first_value(row, "longitude"))
        if latitude is None or longitude is None:
            continue
        start_places.append({
            "startNumber": first_value(row, "startnumber"),
            "nameOnMap": first_value(row, "nameonmap"),
            "longName": first_value(row, "longname"),
            "gridReference": first_value(row, "gridref"),
            "latitude": latitude,
            "longitude": longitude,
            "heightM": optional_float(first_value(row, "heightm")),
            "provider": provider,
            "status": first_value(row, "status"),
            "parking": first_value(row, "parking"),
            "nearbyHills": first_value(row, "nearbyhills"),
        })
    return start_places


def build_coillte_trail_summaries():
    with (REFERENCE_DATA / "CoillteTrails.geojson").open("r", encoding="utf-8") as geojson_file:
        feature_collection = json.load(geojson_file)
    summaries = []
    for feature in feature_collection.get("features", []):
        properties = feature.get("properties") or {}
        segments = trail_coordinate_segments(feature.get("geometry") or {})
        if not segments:
            continue
        start_coordinate = segments[0][0]
        finish_coordinate = segments[-1][-1]
        name = (string_value(properties.get("NAME")) or "").strip()
        summaries.append({
            "name": name or "Coillte Walk",
            "lengthMeters": double_value(properties.get("LENGTH")) or double_value(properties.get("Shape_STLe")),
            "ascentMeters": None,
            "coordinateSegments": segments,
            "startCoordinate": start_coordinate,
            "finishCoordinate": finish_coordinate,
        })
    return summaries


def build_sport_ireland_trail_summaries():
    with (REFERENCE_DATA / "SportIrelandTrails.geojson").open("r", encoding="utf-8") as geojson_file:
        feature_collection = json.load(geojson_file)
    summaries = {}
    for feature in feature_collection.get("features", []):
        properties = feature.get("properties") or {}
        segments = trail_coordinate_segments(feature.get("geometry") or {})
        trail_id = (string_value(properties.get("TrailID")) or "").strip()
        if not segments or not trail_id:
            continue
        name = (string_value(properties.get("Name")) or "").strip()
        length_kilometers = double_value(properties.get("LengthKm"))
        summaries[trail_id] = {
            "name": name or "Sport Ireland Trail",
            "lengthMeters": length_kilometers * 1000 if length_kilometers is not None else None,
            "ascentMeters": double_value(properties.get("AscentMetres")),
            "coordinateSegments": segments,
        }
    return summaries


def build_outscape_start_places():
    with (REFERENCE_DATA / "OutscapeDerivedTrailStartPoints.geojson").open("r", encoding="utf-8") as geojson_file:
        feature_collection = json.load(geojson_file)
    start_places = []
    for feature in feature_collection.get("features", []):
        properties = feature.get("properties") or {}
        if not outscape_feature_passes_curated_subset(properties):
            continue
        point = point_coordinate(feature.get("geometry") or {})
        fid = (string_value(properties.get("FID")) or "").strip()
        if not point or not fid:
            continue
        name = (string_value(properties.get("Name")) or "").strip()
        detail = " • ".join(
            value
            for value in [
                (string_value(properties.get("Type")) or "").strip(),
                (string_value(properties.get("Trail_Useage")) or "").strip(),
            ]
            if value
        )
        start_places.append({
            "startNumber": f"outscape-{fid}",
            "nameOnMap": name or "Outscape Trail",
            "longName": name or "Outscape Trail",
            "gridReference": generated_grid_reference(point["latitude"], point["longitude"]),
            "latitude": point["latitude"],
            "longitude": point["longitude"],
            "heightM": None,
            "provider": "outscape",
            "status": "Derived trail start candidate",
            "parking": "",
            "nearbyHills": detail,
        })
    return start_places


def build_outscape_trail_summaries():
    with (REFERENCE_DATA / "OutscapeOffRoadTrails.geojson").open("r", encoding="utf-8") as geojson_file:
        feature_collection = json.load(geojson_file)
    summaries = {}
    for feature in feature_collection.get("features", []):
        properties = feature.get("properties") or {}
        if not outscape_feature_passes_curated_subset(properties):
            continue
        segments = trail_coordinate_segments(feature.get("geometry") or {})
        fid = (string_value(properties.get("FID")) or "").strip()
        if not segments or not fid:
            continue
        name = (string_value(properties.get("Name")) or "").strip()
        length_kilometers = double_value(properties.get("Length"))
        trail_id = f"outscape-{fid}"
        summaries[trail_id] = {
            "name": name or "Outscape Trail",
            "lengthMeters": length_kilometers * 1000 if length_kilometers is not None else None,
            "ascentMeters": None,
            "coordinateSegments": segments,
        }
    return summaries


def build_sport_ireland_trail_id_by_start_place_id():
    mapping = {}
    for row in read_csv_rows(REFERENCE_DATA / "SportIrelandTrailheads.csv"):
        source_object_id = first_value(row, "sourceobjectid")
        trail_id = first_value(row, "trailid")
        if source_object_id and trail_id:
            mapping[f"sportireland-{source_object_id}"] = trail_id
    return mapping


def generate_all(destination):
    json_dump(destination / "RegionPeakDataset.json", build_peaks())
    json_dump(destination / "MountainViewsStartPoints.json", build_start_places("MountainViewsStartPoints", "mountainViews"))
    json_dump(destination / "SportIrelandStartPoints.json", build_start_places("SportIrelandStartPoints", "sportIreland"))
    json_dump(destination / "CoillteStartPoints.json", build_start_places("CoillteStartPoints", "coillte"))
    json_dump(destination / "OutscapeTrailStartPoints.json", build_outscape_start_places())
    json_dump(destination / "CoillteTrailSummaries.json", build_coillte_trail_summaries())
    json_dump(destination / "SportIrelandTrailSummaries.json", build_sport_ireland_trail_summaries())
    json_dump(destination / "OutscapeTrailSummaries.json", build_outscape_trail_summaries())
    json_dump(destination / "SportIrelandTrailIDByStartPlaceID.json", build_sport_ireland_trail_id_by_start_place_id())


def rebuild_from_legacy_imports():
    DESKTOP_DATA.mkdir(parents=True, exist_ok=True)
    generate_all(DESKTOP_DATA)
    print(f"Rebuilt canonical Desktop JSON data at {DESKTOP_DATA}")
    sync_desktop_source_to_bundle()


def main():
    parser = argparse.ArgumentParser(
        description="Sync BareGPS Ireland app JSON resources from the canonical Desktop data directory."
    )
    parser.add_argument(
        "--rebuild-from-legacy-imports",
        action="store_true",
        help="Regenerate the Desktop source-of-truth JSON files from the old CSV/GeoJSON imports, then sync them to the app bundle.",
    )
    args = parser.parse_args()

    if args.rebuild_from_legacy_imports:
        rebuild_from_legacy_imports()
    else:
        sync_desktop_source_to_bundle()


if __name__ == "__main__":
    main()
