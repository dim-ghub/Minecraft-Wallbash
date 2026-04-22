# Caelestia Minecraft Resource Pack Generator

This script generates a customized Minecraft resource pack by recoloring textures using Caelestia.

It works with multiple Minecraft instances and outputs the processed files to a `caelestia` folder inside each configured resource pack directory.

---

## Directory Layout

- **Input textures**:
  `~/.local/bin/posthooks/minecraft/RP/`

- **Caelestia colors**:
  `~/.local/state/caelestia/theme/minecraft`

- **Output directories**:
  `~/.local/bin/posthooks/minecraft/mcdirs.conf`

Each line in `mcdirs.conf` should be a Minecraft resourcepacks folder (e.g., from ATLauncher or MultiMC). The script will automatically append `/caelestia` to each.

---

## Setup

Download the latest Catppuccin Mocha Blue Minecraft resource pack and extract it to `~/.local/bin/posthooks/minecraft/RP/`.

Get it here: https://github.com/catppuccin/minecraft

**Note:** On the first run, the script builds a color lookup table (~15-30s). Subsequent runs are nearly instant since it caches the table.

Open the wallpaper picker (SUPER, >wallpapers) and reselect your wallpaper, it can be the same one.

Run `~/.local/bin/posthooks/minecraft.sh -a`

Paste in the path to your resourcepacks folder.

If you want the script to be ran every time you change wallpapers:

Edit `~/.config/caelestia/cli.json` and change the postHook to execute `~/.local/bin/posthooks/minecraft.sh`

If the cli.json does not exist, please copy and paste in the example configuration from here:

https://github.com/caelestia-dots/cli
---

## Dependencies

- rsync
- python3
- numpy
- Pillow
- ydotool
- jq
- hyprctl

---

## How It Works

1. **Setup**
   - Uses the catppuccin Minecraft resource pack as a base
   - Reads colors from `minecraft`, trims whitespace, validates hex format, and limits to the size of the base palette

2. **Output Directory Handling**
   - Reads output base paths from `mcdirs.conf`
   - Expands `~` and adds `/caelestia` (unless it’s already included)

3. **File Processing**
   - Recursively scans the input directory
   - If the file is `pack.png`, it’s copied directly
   - If the file is a `.png` or `.jpg`, it is processed with Python:
     - Opens the image with Pillow
     - Converts to RGBA
     - For each non-transparent pixel:
       - Finds the closest base palette color
       - Replaces it with the corresponding Caelestia color (alpha preserved)
     - Saves the modified image in the corresponding output path
   - Non-image files are copied unchanged

4. **Verbose Mode**
   - If run with `-v`, logs every action to the terminal

5. **Add Mode**
   - If run with `-a`, will prompt you to enter new resource pack directories
   - Accepts multiple entries until the you enter `done`
   - Prompts you to immediately run the script (defaults to "yes")

---

## Usage

### Basic:

```bash
~/.local/bin/posthooks/minecraft.sh
```

### Verbose Logging:

```bash
~/.local/bin/posthooks/minecraft.sh -v
```

### Add Paths:

```bash
~/.local/bin/posthooks/minecraft.sh -a
```
