# Lecturnity to Opencast converter

This converter takes a zipped version of a [Lecturnity](https://www.im-c.com/de/lecturnity/) recording, and transforms it into files that [Opencast](http://www.opencast.org) can process. 

This converter is really rough and not tested well. If you encounter any problems, please create an issue on [Github](https://github.com/learnweb/lecturnity-to-opencast/issues).

The slides are extracted from the swf-file and converted to a regular Videofile with appropriate slide duration (gathered from the lecturnity document metadata). Presenter Video and Audio are converted from flv to regular MPEG-4 AVC and MP3 files.

## Usage

`./l2o.sh [inputfile [output directory]]`

Inputfile will default to `input.zip`. Output directory will default to `output/`. Additionally the following environment variables can be used to modify the behaviour:

* `SEPARATE_AUDIO`: Extract audio stream only to a separate audiofile or include in presenter videofile. Values are `yes` or `no`. Defaults to `yes`.
* `X264_PRESET`: Preset for the video encoding using libx264. Defaults to `slow`. 
* `WORKDIR`: Extraction of input file, slides and metadata will take place here. Defaults to a fresh temporary directory created by `mktemp`. **ATTENTION:** This directory will be deleted entirely after the conversion is finished.

## Todo

* Needs automated tests.
* Check if Lecturnity saves slides as JPEG as well. The provided testfiles only included PNGs.
* Extract more metadata for possible Opencast ingest.
* Properly parse commandline options with parameters.
* Optionally ingest to Opencast.
* "Daemon": Watch inputfolder for new .zips, convert & ingest them.

## Requirements

These programs are required to use this converter: `bash, unzip, swfextract, xmlstarlet, ffmpeg`. `swfextract` is usually included in a `swftools` package.