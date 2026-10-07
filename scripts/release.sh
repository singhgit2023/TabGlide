#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
APP="$PWD/dist/TabGlide.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")
ARCH=$(uname -m)
# Only the current archive goes into generation; each release has a distinct URL.
STAGING=$(mktemp -d "$PWD/dist/sparkle-release.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ARCHIVE="TabGlide-$VERSION-macOS-$ARCH.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGING/$ARCHIVE"
# Refuse to sign with a different Keychain key than the one embedded in the app.
TOOLS="$PWD/.build/artifacts/sparkle/Sparkle/bin"
PUBLIC_KEY=$("$TOOLS/generate_keys" --account WindowHop -p)
EMBEDDED_KEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist")
if [ "$PUBLIC_KEY" != "$EMBEDDED_KEY" ]; then
  echo 'The update signing key does not match the app public key.' >&2
  exit 1
fi
if [ -f appcast.xml ]; then
  python3 - "$BUILD" <<'PY'
import sys
import xml.etree.ElementTree as ET
ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
versions = [int(n.text) for n in ET.parse('appcast.xml').iter(ns+'version')]
if versions and int(sys.argv[1]) < max(versions):
    raise SystemExit('Refusing to replace the feed with an older build.')
PY
fi
NOTES="docs/release-v$VERSION.md"
if [ -f "$NOTES" ]; then
  cp "$NOTES" "$STAGING/${ARCHIVE%.zip}.md"
fi
"$TOOLS/generate_appcast" --account WindowHop --maximum-deltas 0 \
  --download-url-prefix "https://github.com/singhgit2023/WindowHop/releases/download/v$VERSION/" \
  --embed-release-notes "$STAGING"
cp "$STAGING/$ARCHIVE" "dist/$ARCHIVE"
cp "$STAGING/appcast.xml" appcast.xml
(cd dist && shasum -a 256 "$ARCHIVE" > "TabGlide-$VERSION-SHA256SUMS.txt")
echo "Prepared dist/$ARCHIVE and appcast.xml."
echo 'Publish the ZIP as a GitHub release first, then upload appcast.xml to main.'
