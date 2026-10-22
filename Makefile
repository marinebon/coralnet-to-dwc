.PHONY: all data python r parity site clean

all: data site

## Run both conversions. R runs second.
data: python r

## Run the Python conversion.
python:
	python3 convert.py

## Run the R conversion. It writes the same files.
r:
	Rscript convert.R

## Check that Python and R write the same tables.
parity:
	python3 convert.py
	tmp=$$(mktemp -d); \
	trap 'rm -rf "$$tmp"' EXIT; \
	cp output/event.csv output/occurrence.csv \
	   output/extendedmeasurementorfact.csv output/meta.xml \
	   output/README.txt "$$tmp"/; \
	Rscript convert.R; \
	for f in event.csv occurrence.csv extendedmeasurementorfact.csv meta.xml README.txt; do \
		cmp "$$tmp/$$f" "output/$$f" || exit 1; \
	done

## Build the website.
site:
	quarto render

## Remove generated files.
clean:
	rm -rf _site .quarto output
