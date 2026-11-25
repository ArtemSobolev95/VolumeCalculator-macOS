#!/bin/bash
#
# Builds the universal plugin (Apple silicon + Intel) and packs it for colleagues:
#   dist/VolumeCalculator-IsiX-<version>.zip   (TARGET=horos: dist/VolumeCalculator-Horos-<version>.zip)
#
set -euo pipefail
cd "$(dirname "$0")"

TARGET="${TARGET:-isix}"
if [ "$TARGET" = "horos" ]; then BUILD=build-horos; HOSTNAME=Horos; DIST_FILES=Distribution/Horos
else BUILD=build; HOSTNAME=IsiX; DIST_FILES=Distribution; fi
TARGET="$TARGET" ./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $BUILD/VolumeCalculator.osirixplugin/Contents/Info.plist)
NAME="VolumeCalculator-$HOSTNAME-$VERSION"
STAGE="dist/$NAME"

rm -rf "$STAGE" "dist/$NAME.zip"
mkdir -p "$STAGE"
cp -R $BUILD/VolumeCalculator.osirixplugin "$STAGE/"
cp "$DIST_FILES/Install VolumeCalculator.command" "$STAGE/"
chmod +x "$STAGE/Install VolumeCalculator.command"
sed "s/@VERSION@/$VERSION/g" Distribution/README.txt > "$STAGE/README.txt"
cp LICENSE "$STAGE/LICENSE.txt"

codesign --verify --deep "$STAGE/VolumeCalculator.osirixplugin"
echo "==> Architectures: $(lipo -archs "$STAGE/VolumeCalculator.osirixplugin/Contents/MacOS/VolumeCalculator")"
(cd dist && ditto -c -k --sequesterRsrc --keepParent "$NAME" "$NAME.zip")
echo "==> Package: $(pwd)/dist/$NAME.zip"
