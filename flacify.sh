#!/bin/bash

# Reencode WAV, AIF and FLAC to FLAC with proper tags and artwork for Rekordbox + Traktor

# to add the flacify command system wide:
# sudo ln -s /your_path_to/flacify.sh /usr/local/bin/flacify

# linux packages, cli flac metadata edit and image resize
# sudo apt install flac
# sudo apt install imagemagick
# sudo apt install ffmpeg

shopt -s nullglob nocaseglob
for FILE in *.aif *.aiff *.wav *.flac;
do 
	echo "FILE: $FILE \n"

	TRIMMED="${FILE%.*}"
	TMP_COVER="TMP_$TRIMMED.jpeg"
	TMP_TXT="TMP_$TRIMMED.txt"
	TMP_FLAC="TMP_$TRIMMED.flac"
	FINAL_FLAC="$TRIMMED.flac"

	#extract the cover
	ffmpeg -y -i "$FILE" -an -vcodec copy "$TMP_COVER"

	#if the file has cover art, do some extra work to preserve it
	if test -f "$TMP_COVER"; then

		#scale the cover to 600x600px (flac breaks on anything > 600)
		#next line is for linux
		convert "$TMP_COVER" -resize 600 "$TMP_COVER"

		#write flac including the reiszed cover
		ffmpeg -y -i "$FILE" -i "$TMP_COVER" -map 0:a -map 1:v -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic -c:v copy "$TMP_FLAC"
	else
		ffmpeg -y -i "$FILE" -write_id3v2 1 -c:v copy "$TMP_FLAC"
	fi

	#export tags to txt file
	metaflac --export-tags-to="$TMP_TXT" "$TMP_FLAC"

	#rename description to comment and fix key in the txt file
	sed -i 's/DESCRIPTION=/comment=/g' "$TMP_TXT"
	sed -i 's/TKEY=/INITIALKEY=/g' "$TMP_TXT"

	#remove previous tags (cover art is untouched)
	metaflac --remove-all-tags "$TMP_FLAC"

	#import tags from txt file
	metaflac --import-tags-from="$TMP_TXT" "$TMP_FLAC"

	#create FILES-BAK folder, move the original files to it
	mkdir FILES-BAK
	mv "$FILE" FILES-BAK

	#final rename
	mv "$TMP_FLAC" "$FINAL_FLAC"

	#remove temp cover and metadata files
	rm TMP_*
done
