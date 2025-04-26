#!/bin/bash

INPUT_DIR="$HOME/.config/hyde/wallbash/RP"
HIGHLIGHT_FILE="$HOME/.cache/hyde/wallbash/minecraft.txt"
MC_DIRS_CONF="$HOME/.config/hyde/wallbash/scripts/mcdirs.conf"

# Base color palette
USED_COLORS=(
    "#9399b2" "#7f849c" "#6c7086" "#585b70"
    "#45475a" "#313244" "#1e1e2e" "#181825"
    "#11111b"
)

VERBOSE=0
ADD_DIRS=0

# Handle arguments
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        -a|--add) ADD_DIRS=1 ;;
        *) echo "❗ Unknown option: $arg"; exit 1 ;;
    esac
done

# Logging function
log() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$@"
    fi
}

# Interactive directory adder
if [[ $ADD_DIRS -eq 1 ]]; then
    echo "🛠️  Add output directories (type 'done' when finished):"
    while true; do
        read -rp "➕ Directory path: " newdir
        [[ "$newdir" == "done" ]] && break
        [[ -z "$newdir" ]] && continue

        # Expand ~ and clean trailing slashes
        clean_path="${newdir/#\~/$HOME}"
        clean_path="${clean_path%/}"

        # Avoid duplicate entries
        if grep -Fxq "$clean_path" "$MC_DIRS_CONF"; then
            echo "⚠️  Already in config: $clean_path"
        else
            echo "$clean_path" >> "$MC_DIRS_CONF"
            echo "✅ Added: $clean_path"
        fi
    done

    # Confirm if the user wants to proceed with processing
    read -rp "▶️  Run the recolor script now? [Y/n] " confirm
    confirm="${confirm:-Y}"
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

# Load highlight colors
mapfile -t REPLACEMENT_COLORS < <(
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$HIGHLIGHT_FILE" | \
    grep -E '^#?[0-9a-fA-F]{6}$' | \
    head -n ${#USED_COLORS[@]}
)
[[ ${#REPLACEMENT_COLORS[@]} -eq 0 ]] && echo "❌ No replacement colors!" && exit 1

# Load and prepare output dirs
mapfile -t OUTPUT_DIRS < <(
    sed 's|~|'"$HOME"'|' "$MC_DIRS_CONF" | sed 's|/*$||' | awk '{ print $0 "/wallbash" }'
)
[[ ${#OUTPUT_DIRS[@]} -eq 0 ]] && echo "❌ No output directories configured!" && exit 1

for dir in "${OUTPUT_DIRS[@]}"; do
    log "📤 Output will go to: $dir"
done

log "🚀 Starting processing..."
recolor_count=0

# Process all files
while read -r filepath; do
    rel_path="${filepath#$INPUT_DIR/}"
    filename="$(basename "$filepath")"

    for OUTPUT_DIR in "${OUTPUT_DIRS[@]}"; do
        out_path="$OUTPUT_DIR/$rel_path"
        out_dir="$(dirname "$out_path")"
        mkdir -p "$out_dir" && log "📁 Created: $out_dir"

        if [[ "$filename" == "pack.png" ]]; then
            cp "$filepath" "$out_path"
            log "📦 Copied pack.png to $out_path"

        elif [[ "$filepath" =~ \.(png|jpe?g)$ ]]; then
            log "🎨 Recoloring image: $rel_path"
            python3 <<EOF
from PIL import Image
from math import sqrt

img_path = "$filepath"
out_path = "$out_path"

base_palette = $(printf "[%s]" "$(printf '"%s", ' "${USED_COLORS[@]}" | sed 's/, $//')")
replacement_colors = $(printf "[%s]" "$(printf '"%s", ' "${REPLACEMENT_COLORS[@]}" | sed 's/, $//')")

def hex_to_rgb(hex):
    hex = hex.lstrip("#")
    return tuple(int(hex[i:i+2], 16) for i in (0, 2, 4))

def distance(c1, c2):
    return sqrt(sum((a - b) ** 2 for a, b in zip(c1, c2)))

if len(replacement_colors) < len(base_palette):
    replacement_colors *= (len(base_palette) // len(replacement_colors)) + 1

base_rgb = [hex_to_rgb(h) for h in base_palette]
target_rgb = [hex_to_rgb(h) for h in replacement_colors]

img = Image.open(img_path).convert("RGBA")
pixels = img.load()

for y in range(img.height):
    for x in range(img.width):
        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        idx = min(range(len(base_rgb)), key=lambda i: distance((r, g, b), base_rgb[i]))
        pixels[x, y] = (*target_rgb[idx], a)

img.save(out_path)
EOF
            ((recolor_count++))
        else
            cp "$filepath" "$out_path"
            log "📄 Copied file: $rel_path"
        fi
    done
done < <(find "$INPUT_DIR" -type f)

echo "✅ Done! $recolor_count image(s) recolored and saved."
