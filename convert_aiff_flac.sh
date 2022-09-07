#!/bin/bash

#converts all the aiffs in a director to flac and preserves the artwork too

# linux packages, cli flac metadata edit and image resize
# sudo apt install flac
# sudo apt install imagemagick
# sudo apt install ffmpeg

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
		#next line is for linux
		convert "$TMP_COVER" -resize 600 "$TMP_COVER"

		#write flac from aiff including the reiszed cover
		ffmpeg -y -i "$FILE" -i "$TMP_COVER" -map 0:a -map 1:v -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic -c:v copy "$OUT_FLAC"
	else
		ffmpeg -y -i "$FILE" -write_id3v2 1 -c:v copy "$OUT_FLAC"
	fi

	#export tags to txt file
	metaflac --export-tags-to="$TMP_TXT" "$OUT_FLAC"

	#rename description to comment in the txt file
	sed -i 's/DESCRIPTION=/comment=/g' "$TMP_TXT"
	sed -i 's/TKEY=/INITIALKEY=/g' "$TMP_TXT"

	#remove previous tags (cover art is untouched)
	metaflac --remove-all-tags "$OUT_FLAC"

	#import tags from txt file
	metaflac --import-tags-from="$TMP_TXT" "$OUT_FLAC"

	#create AIFF-BAK folder, move the AIFF file to it
	mkdir AIFF-BAK
	mv "$FILE" AIFF-BAK

	#remove temp cover and metadata files
	rm *_tmp_*
done
