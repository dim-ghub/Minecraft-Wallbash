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

POSTHOOKS_DIR="$HOME/.local/bin/posthooks"
TEMPLATE_FILE="$HOME/.config/caelestia/templates/minecraft"
HIGHLIGHT_FILE="$HOME/.local/state/caelestia/theme/minecraft"

echo "Uninstalling..."
rm -rf "$POSTHOOKS_DIR/minecraft/"
rm -rf "$POSTHOOKS_DIR/minecraft.sh"
rm -rf "$TEMPLATE_FILE"
rm -rf "$HIGHLIGHT_FILE"
echo "Done! Don't forget to remove the command from your posthook!"