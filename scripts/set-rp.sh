#!/bin/bash

# Prevent running with sudo
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script with sudo. Run it normally." >&2
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "usage: $(basename "$(realpath "$0")") <file>" >&2
    exit 1
fi

POSTHOOKS_DIR="$HOME/.local/bin/posthooks"
rp_path="$1"

if ! [ -f "$rp_path" ]; then
    echo 'Given file does not exist. Please provide a valid file path.' >&2
    exit 1
fi

if [ "$(file -Lsb --mime-type -- "$rp_path")" != application/zip ]; then
    echo "This isn't a .zip file!" >&2
    exit 1
fi
rm -rf "$POSTHOOKS_DIR/minecraft/RP/"
mkdir -p "$POSTHOOKS_DIR/minecraft/RP/"

if ! command -v unzip >/dev/null; then
    echo "unzip is not installed. Please install it and try again." >&2
    exit 1
fi
unzip -q $rp_path -d "$POSTHOOKS_DIR/minecraft/RP/$(basename $rp_path)"