#!/bin/bash
# Reencode WAV, AIF, FLAC, and M4A to FLAC with proper tags and 600x600 artwork for Rekordbox + Traktor

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
    TMP_TXT="$DIR/TMP_${TRIMMED}.txt"
    TMP_FLAC="$DIR/TMP_${TRIMMED}.flac"
    FINAL_FLAC="$DIR/${TRIMMED}.flac"
    BAK_DIR="$DIR/FILES-BAK"

    # Extract embedded artwork if present
    ffmpeg -y -i "$FILE" -an -vcodec copy "$TMP_COVER" -loglevel error

    if [ -s "$TMP_COVER" ]; then
        # Resize cover to max 600x600 preserving aspect ratio (FLAC breaks on > 600px in some players)
        if command -v magick &>/dev/null; then
            magick "$TMP_COVER" -resize 600x600 "$TMP_COVER"
        elif command -v convert &>/dev/null; then
            convert "$TMP_COVER" -resize 600x600 "$TMP_COVER"
        fi

        # Write FLAC including resized cover art
        ffmpeg -y -i "$FILE" -i "$TMP_COVER" -map 0:a -map 1:v \
            -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
            -disposition:v attached_pic -c:v copy -c:a flac "$TMP_FLAC"
    else
        ffmpeg -y -i "$FILE" -c:a flac "$TMP_FLAC"
    fi

    rm -f "$TMP_COVER"

    # Remap tags with metaflac if available and the file was encoded
    if [ -f "$TMP_FLAC" ] && command -v metaflac &>/dev/null; then
        metaflac --export-tags-to="$TMP_TXT" "$TMP_FLAC" 2>/dev/null
        if [ -s "$TMP_TXT" ]; then
            # Remap DESCRIPTION -> comment and TKEY -> INITIALKEY
            sed -i 's/DESCRIPTION=/comment=/gI' "$TMP_TXT"
            sed -i 's/TKEY=/INITIALKEY=/gI' "$TMP_TXT"
            metaflac --remove-all-tags "$TMP_FLAC"
            metaflac --import-tags-from="$TMP_TXT" "$TMP_FLAC"
        fi
        rm -f "$TMP_TXT"
    fi

    # Move source file to FILES-BAK only on successful encode
    if [ -f "$TMP_FLAC" ]; then
        mkdir -p "$BAK_DIR"
        mv "$FILE" "$BAK_DIR/"
        mv "$TMP_FLAC" "$FINAL_FLAC"
        echo "[✓] Created: $FINAL_FLAC"
        echo "[✓] Backed up original to: $BAK_DIR/$BASENAME"
    else
        echo "[-] Conversion failed for $FILE"
        rm -f "$TMP_TXT"
    fi
done