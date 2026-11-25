#!/bin/bash
#
# Installs VolumeCalculator for Horos for the current user.
#
cd "$(dirname "$0")"
PLUGIN="VolumeCalculator.osirixplugin"
DEST="$HOME/Library/Application Support/Horos/Plugins"
APP="/Applications/Horos.app"

echo "VolumeCalculator for Horos — installer"
echo

if [ ! -d "$PLUGIN" ]; then
  echo "ERROR: $PLUGIN is not next to this installer. Unzip the whole package first."
  read -n 1 -s -r -p "Press any key to close."; exit 1
fi

if [ ! -d "$APP" ]; then
  echo "WARNING: Horos is not in /Applications."
fi

if pgrep -xq "Horos"; then
  echo "Please quit Horos first, then run this installer again."
  read -n 1 -s -r -p "Press any key to close."; exit 1
fi

mkdir -p "$DEST"
rm -rf "$DEST/$PLUGIN"
cp -R "$PLUGIN" "$DEST/"
# The plugin is not notarised: remove the download quarantine so that macOS lets the viewer load it.
xattr -dr com.apple.quarantine "$DEST/$PLUGIN" 2>/dev/null

echo
echo "Installed: $DEST/$PLUGIN"
echo "Open Horos; the plugin is in Plugins > ROI Tools > Volume Calculator"
echo "Plugins > Plugins Manager shows whether it loaded."
echo
read -n 1 -s -r -p "Press any key to close."
