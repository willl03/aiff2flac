#!/bin/bash

#converts all the aiffs in a director to flac and preserves the artwork too
AIFF_DIR=$1

echo "working in $AIFF_DIR"

if test -z "$AIFF_DIR" 
then
	echo "no input dir given"
	exit
fi


pushd $1
rm *.flac; rm *.jpeg
#for FILE in *.aiff; 
for FILE in *.aiff;
do 
	echo "FILE: $FILE \n"
	TMP_FILE="$FILE._tmp_.flac"

	COVER="$TMP_FILE.jpeg"
	#extract the cover
	ffmpeg -i "$FILE" -an -vcodec copy "$COVER"


	TRIMMED=$(echo "$FILE" | cut -f 1 -d '.')

	#if the aiff has cover art, do some extra work to preserve it
	if test -f "$COVER"; then
		#convert aiff to a temporary flac
		ffmpeg -i "$FILE" -write_id3v2 1 -c:v copy "$TMP_FILE"

		#scale the cover to 600x600px (flac breaks on anything > 600)
		sips -Z 600 "$COVER"


		#write a new flac including the cover. could i somehow do this without a tmp flac? probably. but bash sucks
		ffmpeg -i "$TMP_FILE"  -i "$COVER" -map 0:a -map 1 -codec copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic "$TRIMMED.flac"
	else
		
		ffmpeg -i "$FILE" -write_id3v2 1 -c:v copy "$TRIMMED.flac"
	fi

done


rm *_tmp_*
popd


