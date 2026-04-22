#!/bin/bash

INPUT_DIR="$HOME/.local/bin/posthooks/minecraft/RP"
HIGHLIGHT_FILE="$HOME/.local/state/caelestia/theme/minecraft"
MC_DIRS_CONF="$HOME/.local/bin/posthooks/minecraft/mcdirs.conf"
PY_SCRIPT="$HOME/.local/bin/posthooks/minecraft/recolor.py"

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
    grep -v '^[[:space:]]*$' "$MC_DIRS_CONF" | sed 's|~|'"$HOME"'|' | sed 's|/*$||' | awk '{ print $0 "/caelestia" }'
)
[[ ${#OUTPUT_DIRS[@]} -eq 0 ]] && echo "No output directories configured!" && exit 1

log "Syncing non-image files..."
for out in "${OUTPUT_DIRS[@]}"; do
    mkdir -p "$out"
    rsync -a --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' "$INPUT_DIR/" "$out/"
done

log "Queueing image jobs..."
BASE_PALETTE_JSON="[$(printf '"%s",' "${USED_COLORS[@]}" | sed 's/,$//')]"
TARGET_PALETTE_JSON="[$(printf '"%s",' "${REPLACEMENT_COLORS[@]}" | sed 's/,$//')]"

jobfile=$(mktemp)
echo "[" > "$jobfile"
sep=""

recolor_count=0

while IFS= read -r -d '' file; do
    rel_path="${file#$INPUT_DIR/}"

    for out in "${OUTPUT_DIRS[@]}"; do
        out_path="$out/$rel_path"

        echo "${sep}{\"img_path\": \"$file\", \"out_path\": \"$out_path\", \"base_palette\": $BASE_PALETTE_JSON, \"target_palette\": $TARGET_PALETTE_JSON}" >> "$jobfile"
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

notify-send "Caelestia" "Resource pack generated!"
