#!/bin/bash

# Reencode WAV, AIF and FLAC to MP3 with proper tags and artwork for Rekordbox + Traktor

# to add the mp3ify command system wide:
# sudo ln -s /your_path_to/mp3ify.sh /usr/local/bin/mp3ify

# Requires the following packages:
# sudo apt install imagemagick
# sudo apt install ffmpeg

shopt -s nullglob nocaseglob
for FILE in *.aif *.aiff *.wav *.flac;
do 
	echo "FILE: $FILE \n"

	TRIMMED="${FILE%.*}"
	TMP_COVER="TMP_$TRIMMED.jpeg"
	TMP_MP3="TMP_$TRIMMED.mp3"
	FINAL_MP3="$TRIMMED.mp3"

	# extract the cover
	ffmpeg -y -i "$FILE" -an -vcodec copy "$TMP_COVER"

	# if the file has cover art, do some extra work to preserve it
	if test -f "$TMP_COVER"; then

		# scale the cover to 600x600px
		# next line is for linux
		convert "$TMP_COVER" -resize 600 "$TMP_COVER"

		# write mp3 including the reiszed cover
		ffmpeg -y -i "$FILE" -i "$TMP_COVER" -map 0:a -map 1:v -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic -c:v copy -b:a 320k "$TMP_MP3"
	else
		ffmpeg -y -i "$FILE" -c:v copy -b:a 320k "$TMP_MP3"
	fi

	# create FILES-BAK folder, move the original files to it
	mkdir FILES-BAK
	mv "$FILE" FILES-BAK

	# final rename
	mv "$TMP_MP3" "$FINAL_MP3"

	# remove temp cover and metadata files
	rm TMP_*
done
