#!/bin/bash
#
# Builds VolumeCalculator (Apple silicon + Intel) for IsiX DICOM Viewer (GitHub build; the App Store
# build loads no plugins) or for Horos, and optionally installs it.
#
#   ./build.sh                        IsiX build  -> build/VolumeCalculator.osirixplugin
#   ./build.sh install                ... and install in ~/Library/Application Support/IsiX/Plugins
#   TARGET=horos ./build.sh [install] Horos build -> build-horos/..., ~/Library/Application Support/Horos/Plugins
#
# Needs the Xcode command line tools (clang, codesign). No interface files: the window is IsiX's own.
#
set -euo pipefail
cd "$(dirname "$0")"

TARGET="${TARGET:-isix}"
if [ "$TARGET" = "horos" ]; then
  APP="${HOROS_APP:-/Applications/Horos.app}"
  if [ -n "${HOROS_HEADERS:-}" ]; then HEADERS="$HOROS_HEADERS"
  elif [ -f third_party/Horos-headers/PluginFilter.h ]; then HEADERS="$(pwd)/third_party/Horos-headers"
  else HEADERS="$APP/Contents/Frameworks/Horos.framework/Headers"; fi
  MIN_OS=11.0
  BUILD=build-horos
  PLUGIN_DIR="$HOME/Library/Application Support/Horos/Plugins"
  HOST="Horos"
else
  APP="${ISIX_APP:-/Applications/IsiX DICOM Viewer.app}"
  if [ -n "${ISIX_HEADERS:-}" ]; then HEADERS="$ISIX_HEADERS"
  elif [ -f third_party/IsiX-headers/PluginFilter.h ]; then HEADERS="$(pwd)/third_party/IsiX-headers"
  else HEADERS="$APP/Contents/Frameworks/Horos.framework/Headers"; fi
  MIN_OS=15.0
  BUILD=build
  PLUGIN_DIR="$HOME/Library/Application Support/IsiX/Plugins"
  HOST="IsiX"
fi
ARCHS="${ARCHS:-arm64 x86_64}"
ARCH_FLAGS=()
for a in $ARCHS; do ARCH_FLAGS+=(-arch "$a"); done
NAME=VolumeCalculator
BUNDLE="$BUILD/$NAME.osirixplugin"
LOG="$BUILD/build.log"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -f "$HEADERS/PluginFilter.h" ] || die "$HOST plugin headers not found at: $HEADERS"
xcrun --find clang >/dev/null 2>&1 || die "Xcode command line tools not found. Run: xcode-select --install"

rm -rf "$BUILD"
mkdir -p "$BUILD/include" "$BUILD/obj" "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
ln -s "$HEADERS" "$BUILD/include/OsiriXAPI"
: > "$LOG"

C_SOURCES=(
  Sources/VCMath.c
)
OBJC_SOURCES=(
  Sources/VolumeCalculatorFilter.m
  Sources/VCWindowController.m
)

COMMON_FLAGS=(
  "${ARCH_FLAGS[@]}" -mmacosx-version-min=$MIN_OS
  -O2 -g
  -fvisibility=default
  -I Sources -isystem "$BUILD/include" -I "$HEADERS"
  -Wall -Wno-unused-parameter
  -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unknown-pragmas
  -Wno-undeclared-selector -Wno-four-char-constants
  -Werror=unguarded-availability-new
)
echo "==> $HOST build, macOS $MIN_OS+: compiling ($ARCHS) against: $HEADERS"
failed=0
OBJECTS=()
for src in ${C_SOURCES[@]+"${C_SOURCES[@]}"}; do
  obj="$BUILD/obj/$(basename "${src%.*}").o"; OBJECTS+=("$obj")
  xcrun clang "${COMMON_FLAGS[@]}" -x c -std=c11 -c "$src" -o "$obj" >>"$LOG" 2>&1 || { echo "   FAILED: $src"; failed=1; }
done
for src in "${OBJC_SOURCES[@]}"; do
  obj="$BUILD/obj/$(basename "${src%.*}").o"; OBJECTS+=("$obj")
  xcrun clang "${COMMON_FLAGS[@]}" -x objective-c -fobjc-arc -fobjc-exceptions \
    -c "$src" -o "$obj" >>"$LOG" 2>&1 || { echo "   FAILED: $src"; failed=1; }
done
if [ $failed -ne 0 ]; then
  echo
  echo "Compilation failed. Errors:"
  grep -E "error:" "$LOG" | head -40
  echo
  echo "Full log: $(pwd)/$LOG"
  exit 1
fi
if grep -q "warning:" "$LOG"; then
  echo "   (warnings: $(grep -c 'warning:' "$LOG"), see $LOG)"
fi

echo "==> Linking"
xcrun clang -bundle "${ARCH_FLAGS[@]}" -mmacosx-version-min=$MIN_OS -fobjc-arc \
  "${OBJECTS[@]}" \
  -framework Cocoa \
  -undefined dynamic_lookup \
  -o "$BUNDLE/Contents/MacOS/$NAME" >>"$LOG" 2>&1 || { tail -30 "$LOG"; die "link failed (log: $LOG)"; }

echo "==> Assembling bundle"
cp Sources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Sources/VolumeCalculator-icon.png "$BUNDLE/Contents/Resources/"

echo "==> Signing (ad hoc)"
codesign --force --sign - --timestamp=none "$BUNDLE" >>"$LOG" 2>&1 || die "codesign failed (log: $LOG)"

echo "==> Built: $(pwd)/$BUNDLE"
lipo -info "$BUNDLE/Contents/MacOS/$NAME" || true

if [ "${1:-}" = "install" ]; then
  mkdir -p "$PLUGIN_DIR"
  rm -rf "$PLUGIN_DIR/$NAME.osirixplugin"
  cp -R "$BUNDLE" "$PLUGIN_DIR/"
  echo "==> Installed to: $PLUGIN_DIR/$NAME.osirixplugin"
  echo "    Restart $HOST, then check Plugins > Plugins Manager."
fi
