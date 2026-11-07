#!/bin/bash
# Reencode WAV, AIF, FLAC, and M4A to 320k MP3 with ID3v2.3 tags and 600x600 artwork for Rekordbox + Traktor

TARGETS=()

# If paths are passed via CLI/Dolphin (%F), process those. Otherwise default to current working directory.
if [ "$#" -gt 0 ]; then
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            while IFS= read -r -d '' f; do
                TARGETS+=("$f")
            done < <(find "$arg" -maxdepth 1 -type f \( -iname "*.aif" -o -iname "*.aiff" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.m4a" \) -print0)
        elif [ -f "$arg" ]; then
            TARGETS+=("$arg")
        fi
    done
else
    shopt -s nullglob nocaseglob
    TARGETS=(*.aif *.aiff *.wav *.flac *.m4a)
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "No supported audio files found."
    exit 0
fi

for FILE in "${TARGETS[@]}"; do
    echo -e "\n=========================================="
    echo "Processing: $FILE"
    echo "=========================================="

    DIR="$(dirname "$FILE")"
    BASENAME="$(basename "$FILE")"
    TRIMMED="${BASENAME%.*}"
    EXT="${BASENAME##*.}"

    # Ensure file has a convertible extension
    case "${EXT,,}" in
        aif|aiff|wav|flac|m4a) ;;
        *) continue ;;
    esac

    TMP_COVER="$DIR/TMP_${TRIMMED}.jpeg"
    TMP_MP3="$DIR/TMP_${TRIMMED}.mp3"
    FINAL_MP3="$DIR/${TRIMMED}.mp3"
    BAK_DIR="$DIR/FILES-BAK"

    # Extract embedded artwork if present
    ffmpeg -y -i "$FILE" -an -vcodec copy "$TMP_COVER" -loglevel error

    if [ -s "$TMP_COVER" ]; then
        # Resize cover to max 600x600 without upscaling smaller art (Pioneer CDJ display limit)
        if command -v magick &>/dev/null; then
            magick "$TMP_COVER" -resize "600x600>" "$TMP_COVER"
        elif command -v convert &>/dev/null; then
            convert "$TMP_COVER" -resize "600x600>" "$TMP_COVER"
        fi

        # Encode MP3 with ID3v2.3, explicit tag inheritance, and attached cover
        ffmpeg -y -i "$FILE" -i "$TMP_COVER" \
            -map 0:a -map 1:v \
            -map_metadata 0 \
            -metadata:s:v title="Album cover" \
            -metadata:s:v comment="Cover (front)" \
            -disposition:v attached_pic \
            -c:v copy \
            -c:a libmp3lame -b:a 320k \
            -id3v2_version 3 "$TMP_MP3"
    else
        # Encode MP3 preserving tags without cover
        ffmpeg -y -i "$FILE" \
            -map 0:a \
            -map_metadata 0 \
            -c:a libmp3lame -b:a 320k \
            -id3v2_version 3 "$TMP_MP3"
    fi

    rm -f "$TMP_COVER"

    # Verify output exists and is non-empty before touching source file
    if [ -s "$TMP_MP3" ]; then
        mkdir -p "$BAK_DIR"
        mv "$FILE" "$BAK_DIR/"
        mv "$TMP_MP3" "$FINAL_MP3"
        echo "[✓] Created: $FINAL_MP3"
        echo "[✓] Backed up original to: $BAK_DIR/$BASENAME"
    else
        echo "[-] Conversion failed for $FILE (output missing or zero bytes)"
        rm -f "$TMP_MP3"
    fi
done