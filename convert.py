#!/usr/bin/env python3
"""
Convert CoralNet photoquadrat files into a Darwin Core Archive for OBIS.

This is one file on purpose. Read it from top to bottom.
It uses only the Python standard library.
The file looks long because it lists every column and every taxon.
The conversion itself is six short steps.
Change the settings and the TAXA table, then run:

    python3 convert.py

It reads:
    data/metadata.csv
    data/annotations.csv

It writes:
    output/event.csv
    output/occurrence.csv
    output/extendedmeasurementorfact.csv
    output/meta.xml
    output/README.txt
    output/p2p-azores-2026.zip
"""

import csv
import zipfile
from pathlib import Path

# =============================================================================
# SETTINGS
# Change these values for a new survey.
# =============================================================================

BASE_DIR = Path(__file__).resolve().parent
INPUT_DIR = BASE_DIR / "data"
OUTPUT_DIR = BASE_DIR / "output"

# Enter the names of the people who recorded the samples.
# This text goes into event.recordedBy.
RECORDED_BY = "Tylar Murray, Carolina Peralta"

# Short names used in the identifiers.
PROJECT_CODE = "MBON-P2P"
COUNTRY = "Portugal"
COUNTRY_CODE = "PT"          # ISO 3166-1 alpha-2, used in event.countryCode
COUNTRY_ID_CODE = "PRT"      # ISO 3166-1 alpha-3, used in the identifiers
ISLAND = "Terceira"
ISLAND_CODE = "TER"
STATE_PROVINCE = "Azores"
LOCALITY = "Forte do Negrito"
SITE_CODE = "FDN"
STRATA = "MIDTIDE"
TRANSECT = "T1"
WATER_BODY = "North Atlantic Ocean"
HABITAT = "Rocky intertidal, midtide level"
LOCATION_ID = f"{PROJECT_CODE}:{COUNTRY_ID_CODE}:{ISLAND_CODE}:{SITE_CODE}"

# The sampling method and the physical quadrat.
POINTS_PER_IMAGE = 100
QUADRAT_WIDTH_CM = 25
QUADRAT_HEIGHT_CM = 25
CAMERA_HEIGHT_CM = 42
COORDINATE_UNCERTAINTY_M = 10
PARENT_UNCERTAINTY_M = 100
SAMPLING_PROTOCOL = (
    "MBON Pole to Pole rocky intertidal photoquadrat protocol v3 (2025): "
    "25 x 25 cm quadrat, camera at 42 cm, 100-point intercept grid "
    "annotated in CoralNet (https://marinebon.org/p2p/)."
)
GEOREFERENCE_PROTOCOL = "Consumer GPS recorded by the camera (Insta360 X4)"
GEODETIC_DATUM = "WGS84"

# =============================================================================
# TAXA
# One entry for each CoralNet label that becomes an occurrence.
# label_id = CoralNet label ID, aphia = WoRMS AphiaID.
# =============================================================================

TAXA = {
    "CHLOROPHY": {
        "label_id": "4095", "name": "Chlorophyta", "aphia": "801",
        "authorship": "Pascher, 1914", "rank": "phylum",
        "kingdom": "Plantae", "phylum": "Chlorophyta",
        "class": "", "order": "", "family": "", "genus": "",
        "remark": "Green algae; identified to phylum",
    },
    "CIRRIPE": {
        "label_id": "2812", "name": "Chthamalus stellatus",
        "aphia": "106231", "authorship": "(Poli, 1791)", "rank": "species",
        "kingdom": "Animalia", "phylum": "Arthropoda",
        "class": "Thecostraca", "order": "Balanomorpha",
        "family": "Chthamalidae", "genus": "Chthamalus",
        "remark": "Barnacle; CoralNet label CIRRIPE mapped to Chthamalus stellatus",
    },
    "CORALLINA": {
        "label_id": "4721", "name": "Corallinaceae", "aphia": "143691",
        "authorship": "Lamouroux, 1812", "rank": "family",
        "kingdom": "Plantae", "phylum": "Rhodophyta",
        "class": "Florideophyceae", "order": "Corallinales",
        "family": "Corallinaceae", "genus": "",
        "remark": "Coralline red algae; identified to family",
    },
    "RHODO": {
        "label_id": "4081", "name": "Rhodophyta", "aphia": "852",
        "authorship": "Wettstein, 1901", "rank": "phylum",
        "kingdom": "Plantae", "phylum": "Rhodophyta",
        "class": "", "order": "", "family": "", "genus": "",
        "remark": "Red algae; identified to phylum",
    },
    "RVL": {
        "label_id": "11406", "name": "Rivularia", "aphia": "146623",
        "authorship": "C.Agardh ex Bornet & Flahault, 1886", "rank": "genus",
        "kingdom": "Bacteria", "phylum": "Cyanobacteria",
        "class": "Cyanophyceae", "order": "Nostocales",
        "family": "Rivulariaceae", "genus": "Rivularia",
        "remark": "Cyanobacterium; one point in one image, review before publishing",
    },
    "ULVA": {
        "label_id": "584", "name": "Ulva", "aphia": "144296",
        "authorship": "Linnaeus, 1753", "rank": "genus",
        "kingdom": "Plantae", "phylum": "Chlorophyta",
        "class": "Ulvophyceae", "order": "Ulvales",
        "family": "Ulvaceae", "genus": "Ulva",
        "remark": "Green algae; identified to genus",
    },
}

# These labels are not taxa, so they are not written as occurrences.
EXCLUDED = {"SC": "substrate", "Unc": "unclear"}

# These are taxa, but the group decided to add them later.
DEFERRED = {"MAF": "filamentous macroalgae", "MAEN": "encrusting macroalgae"}

# =============================================================================
# COLUMN ORDER
# The same order is used in the CSV files and in meta.xml.
# =============================================================================

EVENT_COLUMNS = (
    "eventID parentEventID eventDate year month day country countryCode "
    "stateProvince island locality locationID waterBody habitat "
    "decimalLatitude decimalLongitude geodeticDatum "
    "coordinateUncertaintyInMeters coordinatePrecision verbatimLatitude "
    "verbatimLongitude georeferenceProtocol locationRemarks samplingProtocol "
    "sampleSizeValue sampleSizeUnit samplingEffort fieldNumber recordedBy "
    "eventRemarks"
).split()

OCCURRENCE_COLUMNS = (
    "occurrenceID eventID scientificName scientificNameID "
    "scientificNameAuthorship taxonRank kingdom phylum class order family "
    "genus basisOfRecord occurrenceStatus organismQuantity "
    "organismQuantityType identificationVerificationStatus identifiedBy "
    "taxonRemarks identificationRemarks occurrenceRemarks"
).split()

EMOF_COLUMNS = (
    "eventID occurrenceID measurementID measurementType measurementTypeID "
    "measurementValue measurementUnit measurementUnitID measurementMethod "
    "measurementRemarks"
).split()

# =============================================================================
# SMALL HELPERS
# =============================================================================


def read_rows(path):
    """Read a CSV file into a list of dictionaries."""
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_rows(rows, columns, path):
    """Write a list of dictionaries as a CSV file."""
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})


def six(value):
    """Format a latitude or longitude with 6 decimal places."""
    return f"{float(value):.6f}"


def survey_id(date):
    """The identifier shared by the survey event and all its quadrats."""
    return ":".join(
        [
            PROJECT_CODE,
            date.replace("-", ""),
            COUNTRY_ID_CODE,
            ISLAND_CODE,
            SITE_CODE,
            STRATA,
            TRANSECT,
        ]
    )


def frame_from_name(image_name):
    """Turn '20261020__Transect_1_C0020128.jpg' into '0128'."""
    stem = Path(image_name).stem
    frame = stem.split("_")[-1][-4:]
    if not frame.isdigit():
        raise SystemExit(f"Cannot find a 4-digit frame number in {image_name!r}")
    return frame


def measurement(event_id, occurrence_id, name, mtype, value, unit,
                unit_id="", type_id="", method="", remarks=""):
    """Build one eMoF row. Empty fields stay empty."""
    return {
        "eventID": event_id,
        "occurrenceID": occurrence_id,
        "measurementID": f"{occurrence_id or event_id}:{name}",
        "measurementType": mtype,
        "measurementTypeID": type_id,
        "measurementValue": value,
        "measurementUnit": unit,
        "measurementUnitID": unit_id,
        "measurementMethod": method,
        "measurementRemarks": remarks,
    }


# =============================================================================
# STEP 1: EVENTS
# One parent event for the survey, then one child event per photo.
# =============================================================================


def build_events(metadata):
    dates = sorted({row["Date"] for row in metadata})
    if len(dates) != 1:
        raise SystemExit(
            "This simple script expects one survey date. "
            f"Found these dates: {', '.join(dates)}"
        )
    date = dates[0]
    year, month, day = date.split("-")
    survey = survey_id(date)

    latitudes = [float(row["Latitude"]) for row in metadata]
    longitudes = [float(row["Longitude"]) for row in metadata]

    # These fields are the same for the parent and the child events.
    common = {
        "eventDate": date, "year": year, "month": month, "day": day,
        "country": COUNTRY, "countryCode": COUNTRY_CODE,
        "stateProvince": STATE_PROVINCE, "island": ISLAND,
        "locality": LOCALITY, "locationID": LOCATION_ID,
        "waterBody": WATER_BODY, "habitat": HABITAT,
        "geodeticDatum": GEODETIC_DATUM,
        "georeferenceProtocol": GEOREFERENCE_PROTOCOL,
        "samplingProtocol": SAMPLING_PROTOCOL,
        "recordedBy": RECORDED_BY,
    }

    # The parent event is a summary of the whole survey.
    events = [{
        **common,
        "eventID": survey,
        "parentEventID": "",
        "decimalLatitude": six(sum(latitudes) / len(latitudes)),
        "decimalLongitude": six(sum(longitudes) / len(longitudes)),
        "coordinateUncertaintyInMeters": str(PARENT_UNCERTAINTY_M),
        "coordinatePrecision": "0.000001",
        "verbatimLatitude": "",
        "verbatimLongitude": "",
        "locationRemarks": (
            "Coordinates are the centre of the child photoquadrats. "
            "Each child event has its own camera position."
        ),
        "sampleSizeValue": str(len(metadata)),
        "sampleSizeUnit": "quadrats",
        "samplingEffort": f"{len(metadata)} photoquadrats",
        "fieldNumber": "",
        "eventRemarks": (
            f"One survey event with {len(metadata)} photoquadrats. "
            "Sampled above water; depth not recorded."
        ),
    }]

    image_events = {}
    for row in metadata:
        image = row["Name"]
        event_id = f"{survey}:IMG{frame_from_name(image)}"
        image_events[image] = event_id
        height = row.get("Height (cm)") or str(CAMERA_HEIGHT_CM)
        events.append({
            **common,
            "eventID": event_id,
            "parentEventID": survey,
            "decimalLatitude": six(row["Latitude"]),
            "decimalLongitude": six(row["Longitude"]),
            "coordinateUncertaintyInMeters": str(COORDINATE_UNCERTAINTY_M),
            "coordinatePrecision": "0.000001",
            "verbatimLatitude": row["Latitude"],
            "verbatimLongitude": row["Longitude"],
            "locationRemarks": "",
            "sampleSizeValue": str(POINTS_PER_IMAGE),
            "sampleSizeUnit": "points",
            "samplingEffort": f"{POINTS_PER_IMAGE} points",
            "fieldNumber": image,
            "eventRemarks": (
                f"Photoquadrat {image}; camera height {height} cm; "
                f"camera {row.get('Camera', '')}; "
                f"field group {row.get('Group', '')}; "
                f"strobes {row.get('Strobes', '')}; "
                f"comment: {row.get('Comments', '')}. "
                "Sampled above water; depth not recorded."
            ),
        })

    return events, image_events


# =============================================================================
# STEP 2: OCCURRENCES
# One occurrence for each taxon found in each photo.
# =============================================================================


def build_occurrences(annotations, image_events, metadata):
    total_points = {}
    for row in annotations:
        total_points[row["Name"]] = total_points.get(row["Name"], 0) + 1
    for image, total in total_points.items():
        if total != POINTS_PER_IMAGE:
            raise SystemExit(
                f"{image} has {total} points, but the script expects "
                f"{POINTS_PER_IMAGE}."
            )

    known = set(TAXA) | set(EXCLUDED) | set(DEFERRED)
    unknown = sorted({row["Label code"] for row in annotations} - known)
    if unknown:
        raise SystemExit(
            "These CoralNet labels are not in the script: " + ", ".join(unknown)
        )

    # Check that each label ID still belongs to the expected code.
    for row in annotations:
        code = row["Label code"]
        if code in TAXA and row["Label ID"] != TAXA[code]["label_id"]:
            raise SystemExit(
                f"Label {code} has ID {row['Label ID']}, "
                f"but the script expects {TAXA[code]['label_id']}."
            )

    # Group the points by image and label.
    groups = {}
    for row in annotations:
        key = (row["Name"], row["Label code"])
        groups.setdefault(key, []).append(row)

    image_order = {row["Name"]: index for index, row in enumerate(metadata)}
    taxon_order = {code: index for index, code in enumerate(TAXA)}
    ordered_keys = sorted(
        groups,
        key=lambda key: (image_order[key[0]], taxon_order.get(key[1], 99), key[1]),
    )

    occurrences = []
    for image, code in ordered_keys:
        if code not in TAXA:
            continue

        taxon = TAXA[code]
        rows = groups[(image, code)]
        points = len(rows)
        machine = sum(1 for row in rows if row["Annotator"] == "robot")
        human = points - machine
        annotators = sorted({row["Annotator"] for row in rows})
        total = total_points[image]
        percent = f"{points / total * 100:.2f}"
        event_id = image_events[image]
        occurrence_id = f"{event_id}:aphia-{taxon['aphia']}"

        occurrences.append({
            "occurrenceID": occurrence_id,
            "eventID": event_id,
            "scientificName": taxon["name"],
            "scientificNameID": (
                "urn:lsid:marinespecies.org:taxname:" + taxon["aphia"]
            ),
            "scientificNameAuthorship": taxon["authorship"],
            "taxonRank": taxon["rank"],
            "kingdom": taxon["kingdom"],
            "phylum": taxon["phylum"],
            "class": taxon["class"],
            "order": taxon["order"],
            "family": taxon["family"],
            "genus": taxon["genus"],
            "basisOfRecord": (
                "MachineObservation" if machine > 0 else "HumanObservation"
            ),
            "occurrenceStatus": "detected",
            "organismQuantity": percent,
            "organismQuantityType": "percent cover",
            "identificationVerificationStatus": (
                "unconfirmed" if machine > 0 else "confirmed"
            ),
            "identifiedBy": "; ".join(annotators),
            "taxonRemarks": taxon["remark"],
            "identificationRemarks": (
                f"CoralNet label {code} (ID {taxon['label_id']}); "
                f"{points} of {total} points; "
                f"{machine} machine and {human} human annotations."
            ),
            "occurrenceRemarks": (
                f"{percent}% cover from {points} of {total} grid points."
            ),
        })

    return occurrences


# =============================================================================
# STEP 3: MEASUREMENTS
# Three measurements per photo, then four measurements per occurrence.
# =============================================================================


def build_emof(annotations, events, occurrences):
    counts = {}
    machine_counts = {}
    for row in annotations:
        key = (row["Name"], row["Label code"])
        counts[key] = counts.get(key, 0) + 1
        if row["Annotator"] == "robot":
            machine_counts[key] = machine_counts.get(key, 0) + 1

    aphia_to_code = {taxon["aphia"]: code for code, taxon in TAXA.items()}
    excluded_codes = set(EXCLUDED) | set(DEFERRED)
    rows = []
    counts_unit = "http://vocab.nerc.ac.uk/collection/P06/current/UCNT/"

    for event in events:
        if event["sampleSizeUnit"] != "points":
            continue

        image = event["fieldNumber"]
        event_id = event["eventID"]

        # How many points are not mapped to a taxon?
        excluded_total = 0
        parts = []
        for code in sorted(excluded_codes):
            count = counts.get((image, code), 0)
            if count > 0:
                excluded_total += count
                parts.append(f"{code}={count}")

        area = QUADRAT_WIDTH_CM * QUADRAT_HEIGHT_CM / 10000
        rows.append(measurement(
            event_id, "", "quadrat-area", "quadrat area",
            f"{area:.4f}", "square metres",
            "http://vocab.nerc.ac.uk/collection/P06/current/UMSQ/",
            method=(
                f"{QUADRAT_WIDTH_CM} x {QUADRAT_HEIGHT_CM} cm quadrat "
                "specified by the MBON Pole to Pole protocol"
            ),
        ))
        rows.append(measurement(
            event_id, "", "camera-height", "camera height above substrate",
            str(CAMERA_HEIGHT_CM), "centimetres",
            method="Fixed camera mount specified by the protocol",
        ))
        rows.append(measurement(
            event_id, "", "excluded-points",
            "number of points classified as non-taxon",
            str(excluded_total), "counts", counts_unit,
            method=(
                "Count of grid points assigned to labels that are not mapped "
                "to a taxon (substrate, unclear, or deferred macroalgae)"
            ),
            remarks="; ".join(parts),
        ))

        for occurrence in occurrences:
            if occurrence["eventID"] != event_id:
                continue

            aphia = occurrence["scientificNameID"].rsplit(":", 1)[-1]
            code = aphia_to_code[aphia]
            points = counts.get((image, code), 0)
            machine = machine_counts.get((image, code), 0)
            human = points - machine
            percent = f"{points / POINTS_PER_IMAGE * 100:.2f}"
            occurrence_id = occurrence["occurrenceID"]

            rows.append(measurement(
                event_id, occurrence_id, "percent-cover", "percent cover",
                percent, "percent",
                "http://vocab.nerc.ac.uk/collection/P06/current/UPCT/",
                "http://vocab.nerc.ac.uk/collection/P01/current/PCOVRCK1/",
                "Point intercept on a 100-point grid; percent cover = "
                "points assigned to the taxon / total points x 100",
            ))
            rows.append(measurement(
                event_id, occurrence_id, "points", "number of points",
                str(points), "counts", counts_unit,
                method="Count of grid points assigned to the label in CoralNet",
            ))
            rows.append(measurement(
                event_id, occurrence_id, "machine-points",
                "machine-annotated points",
                str(machine), "counts", counts_unit,
                method=(
                    "Count of points whose CoralNet annotator is the "
                    "automated classifier"
                ),
            ))
            rows.append(measurement(
                event_id, occurrence_id, "human-points",
                "human-annotated points",
                str(human), "counts", counts_unit,
                method="Count of points annotated by a person in CoralNet",
            ))

    return rows


# =============================================================================
# STEP 4: WRITE THE ARCHIVE
# =============================================================================


def write_meta_xml():
    """Write the Darwin Core Archive descriptor."""
    def fields(columns):
        return "\n".join(
            f'    <field index="{index}" '
            f'term="http://rs.tdwg.org/dwc/terms/{name}" />'
            for index, name in enumerate(columns)
        )

    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<archive xmlns="http://rs.tdwg.org/dwc/text/">
  <core encoding="UTF-8" fieldsTerminatedBy="," linesTerminatedBy="&#10;" fieldsEnclosedBy="&quot;" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/Event">
    <files><location>event.csv</location></files>
    <id index="0" />
{fields(EVENT_COLUMNS)}
  </core>
  <extension encoding="UTF-8" fieldsTerminatedBy="," linesTerminatedBy="&#10;" fieldsEnclosedBy="&quot;" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/Occurrence">
    <files><location>occurrence.csv</location></files>
    <coreid index="1" />
{fields(OCCURRENCE_COLUMNS)}
  </extension>
  <extension encoding="UTF-8" fieldsTerminatedBy="," linesTerminatedBy="&#10;" fieldsEnclosedBy="&quot;" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact">
    <files><location>extendedmeasurementorfact.csv</location></files>
    <coreid index="0" />
{fields(EMOF_COLUMNS)}
  </extension>
</archive>
"""
    (OUTPUT_DIR / "meta.xml").write_text(xml, encoding="utf-8")


def write_readme():
    """Write a short README that travels inside the zip file."""
    text = f"""CoralNet to Darwin Core Archive

Dataset: MBON Pole to Pole photoquadrats, Azores, 2026
Recorded by: {RECORDED_BY}

Files:
  event.csv                       one survey event and one event per photo
  occurrence.csv                  one row per taxon in one photo
  extendedmeasurementorfact.csv   cover, point counts, and quadrat details
  meta.xml                        Darwin Core Archive descriptor

Open meta.xml in the IPT, or unzip this folder and use the files directly.
"""
    (OUTPUT_DIR / "README.txt").write_text(text, encoding="utf-8")


def make_zip():
    """Put the five archive files into one zip file."""
    name = "p2p-azores-2026.zip"
    with zipfile.ZipFile(
        OUTPUT_DIR / name, "w", compression=zipfile.ZIP_DEFLATED
    ) as archive:
        for filename in [
            "event.csv",
            "occurrence.csv",
            "extendedmeasurementorfact.csv",
            "meta.xml",
            "README.txt",
        ]:
            archive.write(OUTPUT_DIR / filename, arcname=filename)
    return name


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)
    metadata = read_rows(INPUT_DIR / "metadata.csv")
    annotations = read_rows(INPUT_DIR / "annotations.csv")
    print(f"Read {len(metadata)} images and {len(annotations)} points.")

    events, image_events = build_events(metadata)
    print(f"Built {len(events)} event rows (1 survey + {len(metadata)} photos).")

    occurrences = build_occurrences(annotations, image_events, metadata)
    print(f"Built {len(occurrences)} occurrence rows.")

    emof = build_emof(annotations, events, occurrences)
    print(f"Built {len(emof)} measurement rows.")

    if len({row["eventID"] for row in events}) != len(events):
        raise SystemExit("Duplicate eventID found.")
    if len({row["occurrenceID"] for row in occurrences}) != len(occurrences):
        raise SystemExit("Duplicate occurrenceID found.")

    write_rows(events, EVENT_COLUMNS, OUTPUT_DIR / "event.csv")
    write_rows(occurrences, OCCURRENCE_COLUMNS, OUTPUT_DIR / "occurrence.csv")
    write_rows(emof, EMOF_COLUMNS, OUTPUT_DIR / "extendedmeasurementorfact.csv")
    write_meta_xml()
    write_readme()
    zip_name = make_zip()

    print("Wrote:")
    for name in [
        "output/event.csv",
        "output/occurrence.csv",
        "output/extendedmeasurementorfact.csv",
        "output/meta.xml",
        f"output/{zip_name}",
    ]:
        print("  " + name)
    print("Done.")


if __name__ == "__main__":
    main()
