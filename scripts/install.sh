#!/bin/bash

# Prevent running with sudo
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script with sudo. Run it normally." >&2
    exit 1
fi

if [ $# -ne 0 ]; then
    echo "usage: $(basename "$(realpath "$0")")" >&2
    exit 1
fi

# Dynamically find the project root regardless of where this script is called from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

POSTHOOKS_DIR="$HOME/.local/bin/posthooks"
TEMPLATES_DIR="$HOME/.config/caelestia/templates"

# --- Check for existing installation ---
if [[ -e "$TEMPLATES_DIR/minecraft" ]]; then
    echo ""
    echo "============================================================"
    echo "                    CLEAN UP / UPDATE"
    echo "============================================================"
    echo "Previous installation exists, cleaning and updating..."
    chmod +x "$PROJECT_ROOT/scripts/uninstall.sh"
    "$PROJECT_ROOT/scripts/uninstall.sh"
fi
# ------------------------

# --- installation ---
echo ""
echo "============================================================"
echo "                       INSTALLING"
echo "============================================================"

DEPENDENCIES=(
    "rsync"
    "python3"
    "python-numpy"
    "python-pillow"
    "ydotool"
    "jq"
    "hyprland"
)

echo "Checking dependencies..."
MISSING_PKGS=()

for pkg in "${DEPENDENCIES[@]}"; do
    if ! pacman -Qs "$pkg" > /dev/null; then
        MISSING_PKGS+=("$pkg")
        echo "Missing package: $pkg"
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "Please install the dependencies and try again!"
    exit 1
else
    echo "✓ All dependencies met."
fi

mkdir -p "$POSTHOOKS_DIR/minecraft/RP"
mkdir -p "$TEMPLATES_DIR"
cp -r "$PROJECT_ROOT/posthook"/* "$POSTHOOKS_DIR/"
cp -r "$PROJECT_ROOT/template"/* "$TEMPLATES_DIR"

# ------------------------

# ------------------------

echo ""
echo "============================================================"
echo "                         SETUP"
echo "============================================================"

echo "Reloading wallpaper..."
WALLPAPER_FILE=$(caelestia wallpaper)
caelestia wallpaper -f $WALLPAPER_FILE
read -p "Path to your Minecraft Catppucin resource pack: " rp_path
"$PROJECT_ROOT/scripts/set-rp.sh" $rp_path
if [ $? -ne 0 ]; then
    exit 1
fi
"$HOME/.local/bin/posthooks/minecraft.sh" -a
echo "Done! Don't forget to add ~/.local/bin/posthooks/minecraft.sh to your posthook if you want to automate the process."