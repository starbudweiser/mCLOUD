#!/bin/zsh
# Publie mCLOUD : version locale installée → signature Developer ID, notarisation, agrafage, zip, release GitHub.
# Usage : ./release.sh [--notes "texte"] [--replace]   — la version vient de Resources/Info.plist.
# Prérequis : dépôt propre et poussé sur main, gh connecté, version locale à jour (_tools/build_all.sh mCLOUD).
set -euo pipefail
cd "$(dirname "$0")"
OWNER="starbudweiser"; REPO="mCLOUD"
NOTES=""; REPLACE=0
while [ $# -gt 0 ]; do case "$1" in --notes) NOTES="${2:-}"; shift ;; --replace) REPLACE=1 ;; *) echo "option inconnue : $1" >&2; exit 1 ;; esac; shift; done
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "release : modifications non commitées" >&2; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "release : pas synchronisé avec origin/main" >&2; exit 1; }
/Volumes/SKYRIM/TOOLS/MAC/_TOOLS/build_all.sh mCLOUD >/dev/null
APP="$HOME/Applications/Applications Personnelles/mCLOUD.app"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"; TAG="v$VERSION"
if gh release view "$TAG" -R "$OWNER/$REPO" >/dev/null 2>&1 && [ "$REPLACE" != 1 ]; then echo "release : $TAG existe déjà (--replace)" >&2; exit 1; fi
/Volumes/SKYRIM/TOOLS/MAC/_TOOLS/notarize_app.sh "$APP"
ZIP="/Volumes/SKYRIM/TOOLS/MAC/_TOOLS/notarized/mCLOUD.zip"; STAGE="$(mktemp -d)"; ASSET="mCLOUD-$VERSION-macOS.zip"
cp "$ZIP" "$STAGE/$ASSET"; (cd "$STAGE" && shasum -a 256 "$ASSET" > "$ASSET.sha256")
if gh release view "$TAG" -R "$OWNER/$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" -R "$OWNER/$REPO" --clobber "$STAGE/$ASSET" "$STAGE/$ASSET.sha256"
else
  gh release create "$TAG" -R "$OWNER/$REPO" --target main --title "mCLOUD $VERSION" ${NOTES:+--notes "$NOTES"} ${NOTES:---generate-notes} "$STAGE/$ASSET" "$STAGE/$ASSET.sha256"
fi
echo "✓ https://github.com/$OWNER/$REPO/releases/tag/$TAG"
