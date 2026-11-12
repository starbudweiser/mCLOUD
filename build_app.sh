#!/bin/zsh
# Compile mCLOUD. Sans option : version locale « mCLOUD.app » (fr.stephan.mcloud), signée et installée dans
# ~/Applications/Applications Personnelles. DEV=1 : version de développement « mCLOUD Dev.app » (fr.stephan.mcloud.dev)
# dans le dossier du projet, avec données séparées et fournisseur « Dossier local (test) ».
set -euo pipefail
cd "$(dirname "$0")"
if [ -n "${DEV:-}" ]; then NAME="mCLOUD Dev"; BID="fr.stephan.mcloud.dev"; else NAME="mCLOUD"; BID="fr.stephan.mcloud"; fi
APP="$NAME.app"
rm -rf "$APP" build; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target $arch-apple-macos14 -o build/mCLOUD-$arch Sources/*.swift
done
lipo -create build/mCLOUD-arm64 build/mCLOUD-x86_64 -output "$APP/Contents/MacOS/mCLOUD"
cp engine/rclone "$APP/Contents/Resources/rclone"
cp assets/mCLOUD.icns "$APP/Contents/Resources/AppIcon.icns"
sed "s/__BUNDLE_ID__/$BID/" Resources/Info.plist > "$APP/Contents/Info.plist"
[ -z "${DEV:-}" ] || /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 'mCLOUD Dev'" "$APP/Contents/Info.plist"
rm -rf build
/Volumes/SKYRIM/TOOLS/MAC/_TOOLS/sign_app.sh "$APP"
if [ -z "${DEV:-}" ]; then
  DEST="$HOME/Applications/Applications Personnelles"; mkdir -p "$DEST"
  rm -rf "$DEST/$APP" && mv "$APP" "$DEST/$APP" && echo "Installé : $DEST/$APP"
else echo "OK : $PWD/$APP"; fi
