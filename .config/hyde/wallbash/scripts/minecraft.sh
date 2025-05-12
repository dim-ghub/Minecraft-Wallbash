#!/bin/bash

INPUT_DIR="$HOME/.config/hyde/wallbash/RP"
HIGHLIGHT_FILE="$HOME/.cache/hyde/wallbash/minecraft.txt"
MC_DIRS_CONF="$HOME/.config/hyde/wallbash/scripts/mcdirs.conf"
PY_SCRIPT="$HOME/.config/hyde/wallbash/scripts/recolor.py"

USED_COLORS=(
    "#9399b2" "#7f849c" "#6c7086" "#585b70"
    "#45475a" "#313244" "#1e1e2e" "#181825"
    "#11111b"
)

VERBOSE=0
ADD_DIRS=0

for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        -a|--add) ADD_DIRS=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() {
    [[ $VERBOSE -eq 1 ]] && echo "$@"
}

if [[ $ADD_DIRS -eq 1 ]]; then
    echo "Add output directories (type 'done' when finished):"
    while true; do
        read -rp "Directory path: " newdir
        [[ "$newdir" == "done" ]] && break
        [[ -z "$newdir" ]] && continue
        clean_path="${newdir/#\~/$HOME}"
        clean_path="${clean_path%/}"
        if grep -Fxq "$clean_path" "$MC_DIRS_CONF"; then
            echo "Already in config: $clean_path"
        else
            echo "$clean_path" >> "$MC_DIRS_CONF"
            echo "Added: $clean_path"
        fi
    done
    read -rp "Run the recolor script now? [Y/n] " confirm
    confirm="${confirm:-Y}"
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

mapfile -t REPLACEMENT_COLORS < <(
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$HIGHLIGHT_FILE" | \
    grep -E '^#?[0-9a-fA-F]{6}$' | \
    head -n ${#USED_COLORS[@]}
)
[[ ${#REPLACEMENT_COLORS[@]} -eq 0 ]] && echo "No replacement colors!" && exit 1

mapfile -t OUTPUT_DIRS < <(
    sed 's|~|'"$HOME"'|' "$MC_DIRS_CONF" | sed 's|/*$||' | awk '{ print $0 "/wallbash" }'
)
[[ ${#OUTPUT_DIRS[@]} -eq 0 ]] && echo "No output directories configured!" && exit 1

log "Syncing non-image files..."
for out in "${OUTPUT_DIRS[@]}"; do
    mkdir -p "$out"
    rsync -a --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' "$INPUT_DIR/" "$out/"
done

log "Queueing image jobs..."
jobfile=$(mktemp)
echo "[" > "$jobfile"
sep=""

recolor_count=0

while IFS= read -r -d '' file; do
    rel_path="${file#$INPUT_DIR/}"

    for out in "${OUTPUT_DIRS[@]}"; do
        out_path="$out/$rel_path"
        mkdir -p "$(dirname "$out_path")"

        echo "${sep}{" >> "$jobfile"
        echo "  \"img_path\": \"$file\"," >> "$jobfile"
        echo "  \"out_path\": \"$out_path\"," >> "$jobfile"
        echo "  \"base_palette\": [$(printf '"%s",' "${USED_COLORS[@]}" | sed 's/,$//')]," >> "$jobfile"
        echo "  \"target_palette\": [$(printf '"%s",' "${REPLACEMENT_COLORS[@]}" | sed 's/,$//')]" >> "$jobfile"
        echo "}" >> "$jobfile"
        sep=","
        ((recolor_count++))
    done
done < <(find "$INPUT_DIR" -type f -iregex '.*\.\(png\|jpe?g\)' -print0)

echo "]" >> "$jobfile"

if [[ $recolor_count -eq 0 ]]; then
    echo "No images found to recolor."
    rm -f "$jobfile"
    exit 0
fi

log "Recoloring $recolor_count image(s)..."
python3 "$PY_SCRIPT" < "$jobfile"

echo "Done. $recolor_count image(s) recolored."
rm -f "$jobfile"
