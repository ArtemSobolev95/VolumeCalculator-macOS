#!/bin/bash
#
# Installs VolumeCalculator for IsiX for the current user.
#
cd "$(dirname "$0")"
PLUGIN="VolumeCalculator.osirixplugin"
DEST="$HOME/Library/Application Support/IsiX/Plugins"
APP="/Applications/IsiX DICOM Viewer.app"

echo "VolumeCalculator for IsiX — installer"
echo

if [ ! -d "$PLUGIN" ]; then
  echo "ERROR: $PLUGIN is not next to this installer. Unzip the whole package first."
  read -n 1 -s -r -p "Press any key to close."; exit 1
fi

if [ ! -d "$APP" ]; then
  echo "WARNING: IsiX DICOM Viewer is not in /Applications."
  echo "         Install the GitHub build: https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases"
elif [ -d "$APP/Contents/_MASReceipt" ]; then
  echo "WARNING: this is the App Store version of IsiX, which loads no plugins."
  echo "         Replace it with the GitHub build: https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases"
fi

if pgrep -xq "IsiX DICOM Viewer"; then
  echo "Please quit IsiX DICOM Viewer first, then run this installer again."
  read -n 1 -s -r -p "Press any key to close."; exit 1
fi

mkdir -p "$DEST"
rm -rf "$DEST/$PLUGIN"
cp -R "$PLUGIN" "$DEST/"
# The plugin is not notarised: remove the download quarantine so that macOS lets the viewer load it.
xattr -dr com.apple.quarantine "$DEST/$PLUGIN" 2>/dev/null

echo
echo "Installed: $DEST/$PLUGIN"
echo "Open IsiX; the plugin is in Plugins > ROI Tools > Volume Calculator"
echo "Plugins > Plugins Manager shows whether it loaded."
echo
read -n 1 -s -r -p "Press any key to close."
