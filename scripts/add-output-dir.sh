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

# --- Check for existing installation ---
if ! [ -f "$POSTHOOKS_DIR/minecraft.sh" ]; then
    read -p "Theme not installed. Install now? [Y/n]: " install_now
    if [[ -z "$install_now" ]] || [[ "$install_now" =~ ^[Yy]$ ]]; then
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
        chmod +x "$PROJECT_ROOT/scripts/install.sh"
        "$PROJECT_ROOT/scripts/install.sh"
        exit 0
    fi
fi
# ------------------------

"$POSTHOOKS_DIR/minecraft.sh" -a

echo "You can remove an output directory at any time by modifying ~/.local/bin/posthooks/minecraft/mcdirs.conf!"