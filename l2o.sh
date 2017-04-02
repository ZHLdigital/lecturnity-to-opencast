#!/bin/bash


# This script requires the following packages on arch linux:
# unzip, swftools, xmlstarlet, ffmpeg,


# some options
INPUT_FILE=${1:-input.zip}
DESTINATION=${2:-$(pwd)/output}
X264_PRESET=${X264_PRESET:-slow}

WORKDIR=${WORKDIR:-$(mktemp -d)}
DIR_INPUT=${WORKDIR}/extracted/content
DIR_SLIDES=${WORKDIR}/slides


log::die () {
  echo "fatal: $1"
  exit 1
}
log::info () {
  echo "info: $1"
}

l2o::util::requirefile () {
  test -e $1 || log::die "required file $1 not found."
}

l2o::preparedirs () {
  mkdir -p "${WORKDIR}/extracted" "$DIR_SLIDES" "$DESTINATION"
  if [ $? -ne 0 ] ; then log::die "failed creating dirs." ; fi
}

l2o::cleanup () {
  log::info "cleaning up temporary files."
  rm -rf "$WORKDIR"
}

l2o::unzip () {
  # Unzip input file.
  log::info "unzipping input file"
  l2o::util::requirefile "${INPUT_FILE}"
  unzip -q -o "${INPUT_FILE}" -d "${WORKDIR}/extracted"
  if [[ ! -d "${DIR_INPUT}" ]] ; then
    # lecturnity files are in a subfolder. dissolve that folder.
    mv -f ${WORKDIR}/extracted/*/content ${WORKDIR}/extracted/content
  fi
}

l2o::extractslides () {
  log::info "extracting slide images"
  local pattern="${DIR_INPUT}/*.swf"
  local found=( ${pattern} )
  local slidefile="${found[0]}"
  local slides=$(swfextract ${slidefile} | sed -n -e 's/^.*PNGs: ID(s) //p')
  IFS=', ' read -r -a slide_numbers <<< "$slides"
  for i in "${!slide_numbers[@]}" ; do
    swfextract -p ${slide_numbers[i]} -o ${DIR_SLIDES}/${i}.png ${slidefile}
  done
  NUM_SLIDES=$(( ${#slide_numbers[@]} - 1 ))
}

l2o::stitchslides () {
  # generate ffconcat file from xml information
  log::info "inspecting slide metadata"
  l2o::util::requirefile "${DIR_INPUT}/document.lmd"
  echo "ffconcat version 1.0" > ${DIR_SLIDES}/slides.ffconcat
  for (( i=0; i < $NUM_SLIDES; i += 1)) ; do
    # document.lmd is a xml-file, so we can query it comfortably.
    local SLIDE_BEGIN=$(xmlstarlet sel -t -m "/docinfo/structure/chapter/page[$(( $i + 1 ))]/begin" -v . -n ${DIR_INPUT}/document.lmd)
    local SLIDE_END=$(xmlstarlet sel -t -m "/docinfo/structure/chapter/page[$(( $i + 1 ))]/end" -v . -n ${DIR_INPUT}/document.lmd)
    # begin and end times are in milliseconds.
    local SLIDE_DURATION=$(echo "scale=3; x=(${SLIDE_END} - ${SLIDE_BEGIN})/1000; if(x<1) print 0; x" | bc -l)
    echo "file ${i}.png" >> ${DIR_SLIDES}/slides.ffconcat
    echo "duration ${SLIDE_DURATION}" >> ${DIR_SLIDES}/slides.ffconcat
  done

  log::info "stitching presentation video"
  ffmpeg -y -loglevel error -f concat -i "${DIR_SLIDES}/slides.ffconcat" -c:v libx264 -pix_fmt yuv420p -tune stillimage -preset ${X264_PRESET} -profile baseline "${DESTINATION}/presentation.mp4"
}

l2o::convertvideo () {
  log::info "converting presenter video"
  local pattern="${DIR_INPUT}/*.flv"
  local found=( ${pattern} )
  local videofile="${found[0]}"
  ffmpeg -y -loglevel error -i ${videofile} -c:v libx264 -preset ${X264_PRESET} -tune film -profile baseline -c:a aac "${DESTINATION}/presenter.mp4"
}

l2o::extractaudio () {
  log::info "extracting presenter audio"
  local pattern="${DIR_INPUT}/*.flv"
  local found=( ${pattern} )
  local videofile="${found[0]}"
  ffmpeg -y -loglevel error -i ${videofile} -c:v none -c:a copy "${DESTINATION}/presenter.mp3"
}

l2o::main() {
  l2o::preparedirs
  l2o::unzip
  l2o::extractslides
  l2o::stitchslides
  l2o::extractaudio
  l2o::convertvideo
  l2o::cleanup
}

l2o::main