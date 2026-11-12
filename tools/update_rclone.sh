#!/bin/zsh
# Télécharge la dernière version officielle de rclone (arm64 + amd64) et fabrique engine/rclone (binaire universel).
# Le binaire (≈185 Mo) n'est pas versionné dans git. Usage : tools/update_rclone.sh
set -euo pipefail
cd "$(dirname "$0")/.."
T="$(mktemp -d)"
for a in arm64 amd64; do
  curl -fsSL -o "$T/$a.zip" "https://downloads.rclone.org/rclone-current-osx-$a.zip"
  mkdir "$T/$a" && unzip -q "$T/$a.zip" -d "$T/$a"
done
mkdir -p engine
lipo -create "$T"/arm64/*/rclone "$T"/amd64/*/rclone -output engine/rclone
chmod +x engine/rclone; rm -rf "$T"
engine/rclone version | head -1
