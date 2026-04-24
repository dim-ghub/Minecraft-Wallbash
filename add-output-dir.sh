#!/bin/bash

POSTHOOKS_DIR="$HOME/.local/bin/posthooks"

# --- Check for existing installation ---
if [ ! -e "$POSTHOOKS_DIR/minecraft.sh" ]; then
    read -p "Theme not installed. Install now? [Y/n]: " install_now
    if [[ -z "$install_now" ]] || [[ "$install_now" =~ ^[Yy]$ ]]; then
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        chmod +x "$SCRIPT_DIR/install.sh"
        "$SCRIPT_DIR/install.sh"
        exit 0
    fi
fi
# ------------------------

"$POSTHOOKS_DIR/minecraft.sh" -a