#!/bin/bash
# Builds VolumeCalculator (Apple silicon + Intel), installs it in IsiX, and makes the zip to share.
cd "$(dirname "$0")"
if pgrep -xq "IsiX DICOM Viewer"; then
  echo "Please quit IsiX DICOM Viewer first, then double-click this file again."
  read -n 1 -s -r -p "Press any key to close."; exit 1
fi
TARGET=isix ./build.sh install && TARGET=isix ./package.sh
status=$?
echo
if [ $status -eq 0 ]; then
  echo "Done. The zip to share is in: $(pwd)/dist"
  open dist
else
  echo "Build failed (see above). Copy the error lines to Claude."
fi
read -n 1 -s -r -p "Press any key to close."
