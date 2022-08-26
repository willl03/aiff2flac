#!/bin/bash

#converts all the aiffs in a director to flac and preserves the artwork too
#AIFF_DIR=$1

#echo "working in $AIFF_DIR"

#if test -z "$AIFF_DIR" 
#then
#	echo "no input dir given"
#	exit
#fi

# linux packages, cli flac metadata edit and image resize
# sudo apt install flac
# sudo apt install imagemagick
# sudo apt install ffmpeg

#pushd "$1"
shopt -s nullglob nocaseglob
for FILE in *.aif *.aiff;
do 
	echo "FILE: $FILE \n"
	TMP_FILE="$FILE._tmp_.flac"

	COVER="$TMP_FILE.jpeg"
	#extract the cover
	ffmpeg -y -i "$FILE" -an -vcodec copy "$COVER"

	TRIMMED=$(echo "$FILE" | cut -f 1 -d '.')

	#if the aiff has cover art, do some extra work to preserve it
	if test -f "$COVER"; then
		#convert aiff to a temporary flac
		ffmpeg -y -i "$FILE" -write_id3v2 1 -c:v copy "$TMP_FILE"

		#scale the cover to 600x600px (flac breaks on anything > 600)
		#next line is for mac
		#sips -Z 600 "$COVER"
		#next line is for linux
		convert "$COVER" -resize 600 "$COVER"

		#write a new flac including the cover. could i somehow do this without a tmp flac? probably. but bash sucks
		ffmpeg -y -i "$TMP_FILE" -i "$COVER" -map 0:a -map 1 -codec copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic "$TRIMMED.flac"
	else
		ffmpeg -y -i "$FILE" -write_id3v2 1 -c:v copy "$TRIMMED.flac"
	fi

	#export tags to txt file
	metaflac --export-tags-to="$TRIMMED._tmp_.txt" "$TRIMMED.flac"

	#rename description to comment in the txt file
	sed -i 's/DESCRIPTION=/comment=/g' "$TRIMMED._tmp_.txt"

	#remove previous tags (cover art is untouched)
	metaflac --remove-all-tags "$TRIMMED.flac"

	#import tags from txt file
	metaflac --import-tags-from="$TRIMMED._tmp_.txt" "$TRIMMED.flac"

	#create AIFF-BAK folder, move the AIFF file to it
	mkdir AIFF-BAK
	mv "$FILE" AIFF-BAK

done

rm *_tmp_*
#popd
