# CoralNet to Darwin Core

This project converts CoralNet photoquadrat files into a Darwin Core Archive
for OBIS.

There is one Python script and one R script.
Each script does the whole conversion.
There is no config file.

## Run

Python:

```bash
python3 convert.py
```

R:

```bash
Rscript convert.R
```

Both scripts read the files in `data/` and write the files in `output/`.
You only need to run one script.

## Files

| file | what it is |
|---|---|
| `convert.py` | the complete Python conversion |
| `convert.R` | the complete R conversion |
| `data/metadata.csv` | one row per photo |
| `data/annotations.csv` | one row per point |
| `data/labelset.csv` | the CoralNet label list |
| `output/` | the generated Darwin Core files |
| `index.qmd` | the website home page |
| `python.qmd` | the Python notebook page |
| `r.qmd` | the R notebook page |

## Output

- `event.csv`
- `occurrence.csv`
- `extendedmeasurementorfact.csv`
- `meta.xml`
- `README.txt`
- `p2p-azores-2026.zip`

The zip file is ready for the IPT.

## Edit the scripts

All settings are at the top of each script.
Change these first:

- `RECORDED_BY`, which has one string for each field group and is written to
  `occurrence.recordedBy`
- the project, place, and identifier codes
- the quadrat and camera values
- the `TAXA` table

Multi-value strings use `|` as the separator. This applies to `recordedBy`
when a group has more than one person, and to `identifiedBy` when more than
one annotator worked on an occurrence.

The Python and R scripts should stay in step.
They write the same CSV files.

The example camera is the **OM System Tough TG-7**.
The metadata uses the short name `TG-7`.
The scripts write the full name in the event remarks.
The GPS positions come from the camera's built-in GPS.
Photo events use 1 metre position uncertainty; the parent event uses 500 metres.

## Website

Build the site with:

```bash
quarto render
```

The site uses Python and R.
Run the conversion first so the output files exist.

## Limits

This example covers one survey with four field groups. It is not a general tool.
It expects one survey date, one site, one tidal level, and 100 points per photo.
It does not write EML, image URLs, or absence records.
See `notes.qmd` for the full list.
