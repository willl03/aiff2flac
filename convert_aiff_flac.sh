#!/bin/bash

#converts all the aiffs in a director to flac and preserves the artwork too
AIFF_DIR=$1

echo "working in $AIFF_DIR"

if test -z "$AIFF_DIR" 
then
	echo "no input dir given"
	exit
fi


pushd "$1"
shopt -s nullglob nocaseglob
for FILE in *.aif *.aiff;
do 
	echo "FILE: $FILE \n"

	TRIMMED="${FILE%.*}"
	TMP_COVER="$TRIMMED._tmp_.jpeg"
	TMP_TXT="$TRIMMED._tmp_.txt"
	OUT_FLAC="$TRIMMED.flac"

	#extract the cover
	ffmpeg -y -i "$FILE" -an -vcodec copy "$TMP_COVER"

	#if the aiff has cover art, do some extra work to preserve it
	if test -f "$TMP_COVER"; then

		#scale the cover to 600x600px (flac breaks on anything > 600)
		sips -Z 600 "$TMP_COVER"

		#write flac from aiff including the reiszed cover
		ffmpeg -y -i "$FILE" -i "$TMP_COVER" -map 0:a -map 1:v -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic -c:v copy "$OUT_FLAC"
	else
		ffmpeg -y -i "$FILE" -write_id3v2 1 -c:v copy "$OUT_FLAC"
	fi

	#create AIFF-BAK folder, move the AIFF file to it
	mkdir AIFF-BAK
	mv "$FILE" AIFF-BAK

done


rm *_tmp_*
popd


