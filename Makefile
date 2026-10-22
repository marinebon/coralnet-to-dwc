.PHONY: all python r site clean

all: python site

## Run the Python conversion.
python:
	python3 convert.py

## Run the R conversion. It writes the same files.
r:
	Rscript convert.R

## Build the website.
site:
	quarto render

## Remove generated files.
clean:
	rm -rf _site .quarto output
