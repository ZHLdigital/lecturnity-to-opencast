#!/bin/bash


# This script requires the following packages on arch linux:
# unzip, swftools, xmlstarlet, ffmpeg,


INPUT_FILE=${1:-input.zip}
X264_PRESET=${X264_PRESET:-slow}
DEBUG=${DEBUG:-no}
SEPARATE_AUDIO=${SEPARATE_AUDIO:-no}

if [[ "${DEBUG}" = "yes" ]] ; then
  X264_PRESET="ultrafast"
fi

die () {
  echo "fatal: $1"
  return 1
}

debug () {
  if [[ "${DEBUG}" = "yes" ]] ; then
    echo "debug: $1"
  fi
}

info () {
  echo "info: $1"
}

if [[ ${INPUT_FILE} = "" ]] ; then
  die "need inputfile"
fi

test -e ${INPUT_FILE} || die "inputfile ${INPUT_FILE} not found"


if [[ -d process ]] && [[ "${DEBUG}" != "yes" ]] ; then
  rm -r process
fi

mkdir -p process
mkdir -p output

unzip $INPUT_FILE -d process

flv_pattern="process/content/*.flv"
INPUT_PRESENTER=( ${flv_pattern} )

swf_pattern="process/content/*.swf"
INPUT_SLIDES=( ${swf_pattern} )

test -e process/content/document.lmd || die "missing slide metadata"
test -e ${INPUT_PRESENTER[0]} || die "missing presenter video"
test -e ${INPUT_SLIDES[0]} || die "missing slide video"

info "extracting slide images"
# extract list of png elements in swf and their numbers
SWF_SLIDE_PNG_LIST=$(swfextract ${INPUT_SLIDES[0]} | sed -n -e 's/^.*PNGs: ID(s) //p')
info "extracting slides ${SWF_SLIDE_PNG_LIST}"

# split ', '-delimited string into array SLIDES
IFS=', ' read -r -a SLIDES <<< "$SWF_SLIDE_PNG_LIST"

for index in "${!SLIDES[@]}" ; do
  debug "extract slide ${SLIDES[index]} as ${index}.png"
  swfextract -p ${SLIDES[index]} -o output/${index}.png ${INPUT_SLIDES[0]} 
done

# stitch slides to video with correct slide length. 

info "inspecting slide metadata"
# generate ffconcat file from xml information
echo "ffconcat version 1.0" > output/slides.ffconcat
for index in "${!SLIDES[@]}" ; do
  # extract slide begin and end from xml tree
  SLIDE_BEGIN=$(xmlstarlet sel -t -m "/docinfo/structure/chapter/page[$(( $index + 1 ))]/begin" -v . -n process/content/document.lmd)
  SLIDE_END=$(xmlstarlet sel -t -m "/docinfo/structure/chapter/page[$(( $index + 1 ))]/end" -v . -n process/content/document.lmd)
  SLIDE_DURATION=$(( ($SLIDE_END - $SLIDE_BEGIN) / 1000 ))
  echo "file ${index}.png" >> output/slides.ffconcat
  echo "duration ${SLIDE_DURATION}.0" >> output/slides.ffconcat
  debug "slide ${index} from ${SLIDE_BEGIN} to ${SLIDE_END} with duration ${SLIDE_DURATION}"
done

info "stitching presentation video"
ffmpeg -y -f concat -i "output/slides.ffconcat" -c:v libx264 -pix_fmt yuv420p -tune stillimage -preset ${X264_PRESET} -profile baseline "output/presentation.mp4"

info "converting presenter video"
ffmpeg -y -i ${INPUT_PRESENTER[0]} -c:v libx264 -preset ${X264_PRESET} -tune film -profile baseline -c:a aac "output/presenter.mp4"
info "done."

if [[ "${SEPARATE_AUDIO}" = "yes" ]] ; then
  ffmpeg -y -i ${INPUT_PRESENTER[0]} -c:v none -c:a copy output/presenter.mp3
fi

if [[ "${DEBUG}" != "yes" ]] ; then
  rm -r process
  rm output/*.png
  rm output/slides.ffconcat
fi