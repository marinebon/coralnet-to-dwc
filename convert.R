#!/usr/bin/env Rscript

# Convert CoralNet photoquadrat files into a Darwin Core Archive for OBIS.
#
# This is one file on purpose. Read it from top to bottom.
# It uses only base R.
# The file looks long because it lists every column and every taxon.
# The conversion itself is six short steps.
# Change the settings and the TAXA table, then run:
#
#     Rscript convert.R
#
# It reads:
#     data/metadata.csv
#     data/annotations.csv
#
# It writes:
#     output/event.csv
#     output/occurrence.csv
#     output/extendedmeasurementorfact.csv
#     output/meta.xml
#     output/README.txt
#     output/p2p-azores-2026.zip

# =============================================================================
# SETTINGS
# Change these values for a new survey.
# =============================================================================

# Run the script from the project folder.
BASE_DIR <- getwd()
INPUT_DIR <- file.path(BASE_DIR, "data")
OUTPUT_DIR <- file.path(BASE_DIR, "output")

# Enter the names of the people who recorded the samples.
# This text goes into event.recordedBy.
RECORDED_BY <- "Tylar Murray, Carolina Peralta"

# Short names used in the identifiers.
PROJECT_CODE <- "MBON-P2P"
COUNTRY <- "Portugal"
COUNTRY_CODE <- "PT"        # ISO 3166-1 alpha-2, used in event.countryCode
COUNTRY_ID_CODE <- "PRT"    # ISO 3166-1 alpha-3, used in the identifiers
ISLAND <- "Terceira"
ISLAND_CODE <- "TER"
STATE_PROVINCE <- "Azores"
LOCALITY <- "Forte do Negrito"
SITE_CODE <- "FDN"
STRATA <- "MIDTIDE"
TRANSECT <- "T1"
WATER_BODY <- "North Atlantic Ocean"
HABITAT <- "Rocky intertidal, midtide level"
LOCATION_ID <- paste(PROJECT_CODE, COUNTRY_ID_CODE, ISLAND_CODE, SITE_CODE,
                     sep = ":")

# The metadata uses the short name "TG-7".
CAMERA <- "OM System Tough TG-7"

# The sampling method and the physical quadrat.
POINTS_PER_IMAGE <- 100
QUADRAT_WIDTH_CM <- 25
QUADRAT_HEIGHT_CM <- 25
CAMERA_HEIGHT_CM <- 42
COORDINATE_UNCERTAINTY_M <- 1   # photo events, from the camera GPS
PARENT_UNCERTAINTY_M <- 100     # summary centre of all photo positions
SAMPLING_PROTOCOL <- paste0(
  "MBON Pole to Pole Rock Shores Intertidal PhotoQuadrat Protocol. ",
  "25 x 25 cm quadrat with camera at 42cm. ",
  "100-square intercept grid annotated in CoralNet. ",
  "https://repository.oceanbestpractices.org/items/",
  "6025a5e9-87b8-46eb-b422-328cb183e658 and ",
  "https://marinebon.org/p2p/"
)
GEOREFERENCE_PROTOCOL <- "GPS built into the OM System Tough TG-7 camera"
GEODETIC_DATUM <- "WGS84"

# =============================================================================
# TAXA
# One entry for each CoralNet label that becomes an occurrence.
# label_id = CoralNet label ID, aphia = WoRMS AphiaID.
# =============================================================================

TAXA <- list(
  CHLOROPHY = list(
    label_id = "4095", name = "Chlorophyta", aphia = "801",
    authorship = "Pascher, 1914", rank = "phylum",
    kingdom = "Plantae", phylum = "Chlorophyta",
    class = "", order = "", family = "", genus = ""
  ),
  CIRRIPE = list(
    label_id = "2812", name = "Chthamalus stellatus",
    aphia = "106231", authorship = "(Poli, 1791)", rank = "species",
    kingdom = "Animalia", phylum = "Arthropoda",
    class = "Thecostraca", order = "Balanomorpha",
    family = "Chthamalidae", genus = "Chthamalus"
  ),
  CORALLINA = list(
    label_id = "4721", name = "Corallinaceae", aphia = "143691",
    authorship = "Lamouroux, 1812", rank = "family",
    kingdom = "Plantae", phylum = "Rhodophyta",
    class = "Florideophyceae", order = "Corallinales",
    family = "Corallinaceae", genus = ""
  ),
  RHODO = list(
    label_id = "4081", name = "Rhodophyta", aphia = "852",
    authorship = "Wettstein, 1901", rank = "phylum",
    kingdom = "Plantae", phylum = "Rhodophyta",
    class = "", order = "", family = "", genus = ""
  ),
  RVL = list(
    label_id = "11406", name = "Rivularia", aphia = "146623",
    authorship = "C.Agardh ex Bornet & Flahault, 1886", rank = "genus",
    kingdom = "Bacteria", phylum = "Cyanobacteria",
    class = "Cyanophyceae", order = "Nostocales",
    family = "Rivulariaceae", genus = "Rivularia"
  ),
  ULVA = list(
    label_id = "584", name = "Ulva", aphia = "144296",
    authorship = "Linnaeus, 1753", rank = "genus",
    kingdom = "Plantae", phylum = "Chlorophyta",
    class = "Ulvophyceae", order = "Ulvales",
    family = "Ulvaceae", genus = "Ulva"
  )
)

# These labels are not taxa, so they are not written as occurrences.
EXCLUDED <- c("SC", "Unc")
DEFERRED <- c("MAF", "MAEN")

# =============================================================================
# COLUMN ORDER
# The same order is used in the CSV files and in meta.xml.
# =============================================================================

EVENT_COLUMNS <- c(
  "eventID", "parentEventID", "eventDate", "year", "month", "day",
  "country", "countryCode", "stateProvince", "island", "locality",
  "locationID", "waterBody", "habitat", "decimalLatitude",
  "decimalLongitude", "geodeticDatum", "coordinateUncertaintyInMeters",
  "coordinatePrecision", "verbatimLatitude", "verbatimLongitude",
  "georeferenceProtocol", "locationRemarks", "samplingProtocol",
  "sampleSizeValue", "sampleSizeUnit", "samplingEffort", "fieldNumber",
  "recordedBy", "eventRemarks"
)

OCCURRENCE_COLUMNS <- c(
  "occurrenceID", "eventID", "scientificName", "scientificNameID",
  "scientificNameAuthorship", "taxonRank", "kingdom", "phylum", "class",
  "order", "family", "genus", "basisOfRecord", "occurrenceStatus",
  "organismQuantity", "organismQuantityType",
  "identifiedBy", "identificationRemarks", "occurrenceRemarks"
)

EMOF_COLUMNS <- c(
  "eventID", "occurrenceID", "measurementID", "measurementType",
  "measurementTypeID", "measurementValue", "measurementUnit",
  "measurementUnitID", "measurementMethod", "measurementRemarks"
)

# =============================================================================
# SMALL HELPERS
# =============================================================================

read_table <- function(path) {
  read.csv(path, colClasses = "character", check.names = FALSE,
           stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

csv_escape <- function(x) {
  x <- as.character(x)
  needs_quotes <- grepl('[",\n]', x)
  x[needs_quotes] <- paste0('"', gsub('"', '""', x[needs_quotes],
                                      fixed = TRUE), '"')
  x
}

write_csv <- function(data, path) {
  lines <- c(
    paste(csv_escape(names(data)), collapse = ","),
    apply(data, 1, function(row) paste(csv_escape(row), collapse = ","))
  )
  writeLines(lines, path, useBytes = TRUE)
}

rows_to_df <- function(rows, columns) {
  data <- do.call(
    rbind,
    lapply(rows, function(row) {
      as.data.frame(row, stringsAsFactors = FALSE)
    })
  )
  data[, columns, drop = FALSE]
}

six <- function(value) {
  sprintf("%.6f", as.numeric(value))
}

survey_id <- function(date) {
  paste(
    PROJECT_CODE, gsub("-", "", date), COUNTRY_ID_CODE, ISLAND_CODE,
    SITE_CODE, STRATA, TRANSECT, sep = ":"
  )
}

frame_from_name <- function(image_name) {
  stem <- sub("\\.[^.]*$", "", image_name)
  frame <- substr(stem, nchar(stem) - 3, nchar(stem))
  if (!grepl("^[0-9]{4}$", frame)) {
    stop("Cannot find a 4-digit frame number in ", image_name)
  }
  frame
}

measurement <- function(event_id, occurrence_id, name, mtype, value, unit,
                        unit_id = "", type_id = "", method = "",
                        remarks = "") {
  prefix <- if (nzchar(occurrence_id)) occurrence_id else event_id
  list(
    eventID = event_id,
    occurrenceID = occurrence_id,
    measurementID = paste0(prefix, ":", name),
    measurementType = mtype,
    measurementTypeID = type_id,
    measurementValue = value,
    measurementUnit = unit,
    measurementUnitID = unit_id,
    measurementMethod = method,
    measurementRemarks = remarks
  )
}

# =============================================================================
# STEP 1: EVENTS
# One parent event for the survey, then one child event per photo.
# =============================================================================

build_events <- function(metadata) {
  dates <- sort(unique(metadata$Date))
  if (length(dates) != 1) {
    stop("This script expects one survey date. Found: ",
         paste(dates, collapse = ", "))
  }
  date <- dates[[1]]
  date_parts <- strsplit(date, "-", fixed = TRUE)[[1]]
  survey <- survey_id(date)

  # These fields are the same for the parent and the child events.
  common <- list(
    eventDate = date,
    year = date_parts[1],
    month = date_parts[2],
    day = date_parts[3],
    country = COUNTRY,
    countryCode = COUNTRY_CODE,
    stateProvince = STATE_PROVINCE,
    island = ISLAND,
    locality = LOCALITY,
    locationID = LOCATION_ID,
    waterBody = WATER_BODY,
    habitat = HABITAT,
    geodeticDatum = GEODETIC_DATUM,
    georeferenceProtocol = GEOREFERENCE_PROTOCOL,
    samplingProtocol = SAMPLING_PROTOCOL,
    recordedBy = RECORDED_BY
  )

  parent <- c(common, list(
    eventID = survey,
    parentEventID = "",
    decimalLatitude = six(mean(as.numeric(metadata$Latitude))),
    decimalLongitude = six(mean(as.numeric(metadata$Longitude))),
    coordinateUncertaintyInMeters = as.character(PARENT_UNCERTAINTY_M),
    coordinatePrecision = "0.000001",
    verbatimLatitude = "",
    verbatimLongitude = "",
    locationRemarks = paste(
      "Coordinates are the centre of the child photoquadrats.",
      "Each child event has its own camera position."
    ),
    sampleSizeValue = as.character(nrow(metadata)),
    sampleSizeUnit = "quadrats",
    samplingEffort = paste(nrow(metadata), "photoquadrats"),
    fieldNumber = "",
    eventRemarks = paste(
      "One survey event with", nrow(metadata), "photoquadrats.",
      "Sampled above water; depth not recorded."
    )
  ))

  rows <- list(parent)
  image_events <- character(0)

  for (i in seq_len(nrow(metadata))) {
    row <- metadata[i, , drop = FALSE]
    image <- row$Name
    event_id <- paste0(survey, ":IMG", frame_from_name(image))
    image_events[[image]] <- event_id
    height <- row[["Height (cm)"]]
    if (!nzchar(height)) height <- as.character(CAMERA_HEIGHT_CM)

    rows[[length(rows) + 1]] <- c(common, list(
      eventID = event_id,
      parentEventID = survey,
      decimalLatitude = six(row$Latitude),
      decimalLongitude = six(row$Longitude),
      coordinateUncertaintyInMeters = as.character(
        COORDINATE_UNCERTAINTY_M
      ),
      coordinatePrecision = "0.000001",
      verbatimLatitude = row$Latitude,
      verbatimLongitude = row$Longitude,
      locationRemarks = "",
      sampleSizeValue = as.character(POINTS_PER_IMAGE),
      sampleSizeUnit = "points",
      samplingEffort = paste(POINTS_PER_IMAGE, "points"),
      fieldNumber = image,
      eventRemarks = paste0(
        "Photoquadrat ", image, "; camera height ", height, " cm; ",
        "camera ", CAMERA, "; field group ", row$Group, "; ",
        "strobes ", row$Strobes, "; comment: ", row$Comments, ". ",
        "Sampled above water; depth not recorded."
      )
    ))
  }

  list(events = rows_to_df(rows, EVENT_COLUMNS), image_events = image_events)
}

# =============================================================================
# STEP 2: OCCURRENCES
# One occurrence for each taxon found in each photo.
# =============================================================================

build_occurrences <- function(annotations, image_events, metadata) {
  total_points <- table(annotations$Name)
  if (any(total_points != POINTS_PER_IMAGE)) {
    stop("At least one image does not have ", POINTS_PER_IMAGE, " points.")
  }

  known <- c(names(TAXA), EXCLUDED, DEFERRED)
  unknown <- sort(setdiff(unique(annotations[["Label code"]]), known))
  if (length(unknown) > 0) {
    stop("These CoralNet labels are not in the script: ",
         paste(unknown, collapse = ", "))
  }

  # Check that each label ID still belongs to the expected code.
  for (i in seq_len(nrow(annotations))) {
    code <- annotations[["Label code"]][i]
    if (code %in% names(TAXA) &&
        annotations[["Label ID"]][i] != TAXA[[code]]$label_id) {
      stop("Label ", code, " has ID ", annotations[["Label ID"]][i],
           ", but the script expects ", TAXA[[code]]$label_id, ".")
    }
  }

  keys <- unique(annotations[, c("Name", "Label code")])
  keys <- keys[keys[["Label code"]] %in% names(TAXA), , drop = FALSE]
  keys <- keys[order(
    match(keys$Name, metadata$Name),
    match(keys[["Label code"]], names(TAXA)),
    keys[["Label code"]],
    method = "radix"
  ), , drop = FALSE]

  rows <- list()
  for (i in seq_len(nrow(keys))) {
    image <- keys$Name[i]
    code <- keys[["Label code"]][i]
    taxon <- TAXA[[code]]
    points <- annotations[
      annotations$Name == image & annotations[["Label code"]] == code, ,
      drop = FALSE
    ]
    count <- nrow(points)
    machine <- sum(points$Annotator == "robot")
    human <- count - machine
    annotators <- ifelse(
      points$Annotator == "robot",
      "CoralNet machine learning annotator",
      points$Annotator
    )
    annotators <- sort(unique(annotators), method = "radix")
    total <- as.integer(total_points[[image]])
    percent <- sprintf("%.2f", count / total * 100)
    event_id <- image_events[[image]]
    occurrence_id <- paste0(event_id, ":aphia-", taxon$aphia)

    rows[[length(rows) + 1]] <- list(
      occurrenceID = occurrence_id,
      eventID = event_id,
      scientificName = taxon$name,
      scientificNameID = paste0(
        "urn:lsid:marinespecies.org:taxname:", taxon$aphia
      ),
      scientificNameAuthorship = taxon$authorship,
      taxonRank = taxon$rank,
      kingdom = taxon$kingdom,
      phylum = taxon$phylum,
      class = taxon$class,
      order = taxon$order,
      family = taxon$family,
      genus = taxon$genus,
      basisOfRecord = if (machine > 0) {
        "MachineObservation"
      } else {
        "HumanObservation"
      },
      occurrenceStatus = "detected",
      organismQuantity = percent,
      organismQuantityType = "percent cover",
      identifiedBy = paste(annotators, collapse = "; "),
      identificationRemarks = paste0(
        "CoralNet label ", code, " (ID ", taxon$label_id, "); ",
        count, " of ", total, " points; ",
        machine, " machine and ", human, " human annotations."
      ),
      occurrenceRemarks = paste0(
        percent, "% cover from ", count, " of ", total, " grid points."
      )
    )
  }

  rows_to_df(rows, OCCURRENCE_COLUMNS)
}

# =============================================================================
# STEP 3: MEASUREMENTS
# Three measurements per photo, then four measurements per occurrence.
# =============================================================================

build_emof <- function(annotations, events, occurrences) {
  counts <- table(annotations$Name, annotations[["Label code"]])
  machine_counts <- table(
    annotations$Name[annotations$Annotator == "robot"],
    annotations[["Label code"]][annotations$Annotator == "robot"]
  )
  count_at <- function(table, image, code) {
    if (code %in% colnames(table) && image %in% rownames(table)) {
      as.integer(table[image, code])
    } else {
      0L
    }
  }

  aphia_to_code <- setNames(
    names(TAXA),
    vapply(TAXA, function(taxon) taxon$aphia, character(1))
  )
  counts_unit <- "http://vocab.nerc.ac.uk/collection/P06/current/UCNT/"
  rows <- list()
  quadrats <- events[events$sampleSizeUnit == "points", , drop = FALSE]

  for (i in seq_len(nrow(quadrats))) {
    event <- quadrats[i, , drop = FALSE]
    image <- event$fieldNumber
    event_id <- event$eventID

    # How many points are not mapped to a taxon?
    excluded_total <- 0
    parts <- character(0)
    for (code in sort(c(EXCLUDED, DEFERRED), method = "radix")) {
      count <- count_at(counts, image, code)
      if (count > 0) {
        excluded_total <- excluded_total + count
        parts <- c(parts, paste0(code, "=", count))
      }
    }

    area <- QUADRAT_WIDTH_CM * QUADRAT_HEIGHT_CM / 10000
    rows[[length(rows) + 1]] <- measurement(
      event_id, "", "quadrat-area", "quadrat area",
      sprintf("%.4f", area), "square metres",
      "http://vocab.nerc.ac.uk/collection/P06/current/UMSQ/",
      method = paste(
        QUADRAT_WIDTH_CM, "x", QUADRAT_HEIGHT_CM,
        "cm quadrat specified by the MBON Pole to Pole protocol"
      )
    )
    rows[[length(rows) + 1]] <- measurement(
      event_id, "", "camera-height", "camera height above substrate",
      as.character(CAMERA_HEIGHT_CM), "centimetres",
      method = "Fixed camera mount specified by the protocol"
    )
    rows[[length(rows) + 1]] <- measurement(
      event_id, "", "excluded-points",
      "number of points classified as non-taxon",
      as.character(excluded_total), "counts", counts_unit,
      method = paste(
        "Count of grid points assigned to labels that are not mapped",
        "to a taxon (substrate, unclear, or deferred macroalgae)"
      ),
      remarks = paste(parts, collapse = "; ")
    )

    event_occurrences <- occurrences[
      occurrences$eventID == event_id, , drop = FALSE
    ]
    for (j in seq_len(nrow(event_occurrences))) {
      occurrence <- event_occurrences[j, , drop = FALSE]
      aphia <- sub(".*:", "", occurrence$scientificNameID)
      code <- aphia_to_code[[aphia]]
      count <- count_at(counts, image, code)
      machine <- count_at(machine_counts, image, code)
      human <- count - machine
      percent <- sprintf("%.2f", count / POINTS_PER_IMAGE * 100)
      occurrence_id <- occurrence$occurrenceID

      rows[[length(rows) + 1]] <- measurement(
        event_id, occurrence_id, "percent-cover", "percent cover",
        percent, "percent",
        "http://vocab.nerc.ac.uk/collection/P06/current/UPCT/",
        "http://vocab.nerc.ac.uk/collection/P01/current/PCOVRCK1/",
        paste(
          "Point intercept on a 100-point grid; percent cover =",
          "points assigned to the taxon / total points x 100"
        )
      )
      rows[[length(rows) + 1]] <- measurement(
        event_id, occurrence_id, "points", "number of points",
        as.character(count), "counts", counts_unit,
        method = "Count of grid points assigned to the label in CoralNet"
      )
      rows[[length(rows) + 1]] <- measurement(
        event_id, occurrence_id, "machine-points",
        "machine-annotated points",
        as.character(machine), "counts", counts_unit,
        method = paste(
          "Count of points whose CoralNet annotator is the",
          "automated classifier"
        )
      )
      rows[[length(rows) + 1]] <- measurement(
        event_id, occurrence_id, "human-points",
        "human-annotated points",
        as.character(human), "counts", counts_unit,
        method = "Count of points annotated by a person in CoralNet"
      )
    }
  }

  rows_to_df(rows, EMOF_COLUMNS)
}

# =============================================================================
# STEP 4: WRITE THE ARCHIVE
# =============================================================================

write_meta_xml <- function() {
  fields <- function(columns) {
    paste(
      sprintf(
        '    <field index="%d" term="http://rs.tdwg.org/dwc/terms/%s" />',
        seq_along(columns) - 1,
        columns
      ),
      collapse = "\n"
    )
  }

  xml <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<archive xmlns="http://rs.tdwg.org/dwc/text/">',
    '  <core encoding="UTF-8" fieldsTerminatedBy="," linesTerminatedBy="&#10;" fieldsEnclosedBy="&quot;" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/Event">',
    '    <files><location>event.csv</location></files>',
    '    <id index="0" />',
    fields(EVENT_COLUMNS),
    '  </core>',
    '  <extension encoding="UTF-8" fieldsTerminatedBy="," linesTerminatedBy="&#10;" fieldsEnclosedBy="&quot;" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/Occurrence">',
    '    <files><location>occurrence.csv</location></files>',
    '    <coreid index="1" />',
    fields(OCCURRENCE_COLUMNS),
    '  </extension>',
    '  <extension encoding="UTF-8" fieldsTerminatedBy="," linesTerminatedBy="&#10;" fieldsEnclosedBy="&quot;" ignoreHeaderLines="1" rowType="http://rs.tdwg.org/dwc/terms/MeasurementOrFact">',
    '    <files><location>extendedmeasurementorfact.csv</location></files>',
    '    <coreid index="0" />',
    fields(EMOF_COLUMNS),
    '  </extension>',
    '</archive>'
  )
  writeLines(xml, file.path(OUTPUT_DIR, "meta.xml"), useBytes = TRUE)
}

write_readme <- function() {
  text <- c(
    "CoralNet to Darwin Core Archive",
    "",
    "Dataset: MBON Pole to Pole photoquadrats, Azores, 2026",
    paste("Recorded by:", RECORDED_BY),
    "",
    "Files:",
    "  event.csv                       one survey event and one event per photo",
    "  occurrence.csv                  one row per taxon in one photo",
    "  extendedmeasurementorfact.csv   cover, point counts, and quadrat details",
    "  meta.xml                        Darwin Core Archive descriptor",
    "",
    "Open meta.xml in the IPT, or unzip this folder and use the files directly."
  )
  writeLines(text, file.path(OUTPUT_DIR, "README.txt"), useBytes = TRUE)
}

make_zip <- function() {
  old_dir <- setwd(OUTPUT_DIR)
  on.exit(setwd(old_dir), add = TRUE)
  unlink("p2p-azores-2026.zip")
  utils::zip(
    "p2p-azores-2026.zip",
    files = c(
      "event.csv", "occurrence.csv", "extendedmeasurementorfact.csv",
      "meta.xml", "README.txt"
    ),
    flags = "-j"
  )
  "p2p-azores-2026.zip"
}

main <- function() {
  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
  metadata <- read_table(file.path(INPUT_DIR, "metadata.csv"))
  annotations <- read_table(file.path(INPUT_DIR, "annotations.csv"))
  cat(sprintf("Read %d images and %d points.\n",
              nrow(metadata), nrow(annotations)))

  events <- build_events(metadata)
  cat(sprintf("Built %d event rows (1 survey + %d photos).\n",
              nrow(events$events), nrow(metadata)))

  occurrences <- build_occurrences(
    annotations, events$image_events, metadata
  )
  cat(sprintf("Built %d occurrence rows.\n", nrow(occurrences)))

  emof <- build_emof(annotations, events$events, occurrences)
  cat(sprintf("Built %d measurement rows.\n", nrow(emof)))

  if (anyDuplicated(events$events$eventID)) stop("Duplicate eventID found.")
  if (anyDuplicated(occurrences$occurrenceID)) {
    stop("Duplicate occurrenceID found.")
  }

  write_csv(events$events, file.path(OUTPUT_DIR, "event.csv"))
  write_csv(occurrences, file.path(OUTPUT_DIR, "occurrence.csv"))
  write_csv(emof, file.path(OUTPUT_DIR, "extendedmeasurementorfact.csv"))
  write_meta_xml()
  write_readme()
  zip_name <- make_zip()

  cat("Wrote:\n")
  for (name in c(
    "output/event.csv",
    "output/occurrence.csv",
    "output/extendedmeasurementorfact.csv",
    "output/meta.xml",
    paste0("output/", zip_name)
  )) {
    cat("  ", name, "\n", sep = "")
  }
  cat("Done.\n")
}

main()
