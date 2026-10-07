#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Pin this project's certificate; never silently fall back to ad-hoc signing.
SIGNING_IDENTITY="${WINDOWHOP_SIGNING_IDENTITY:-}"
if [ -z "$SIGNING_IDENTITY" ]; then
  if [ -f scripts/signing-identity.txt ]; then
    SIGNING_IDENTITY="$(cat scripts/signing-identity.txt)"
  else
    echo 'Set WINDOWHOP_SIGNING_IDENTITY to your certificate, or - for an explicitly ad-hoc development build.' >&2
    exit 1
  fi
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --disable-sandbox --build-system native -debug-info-format none
APP="$PWD/dist/WindowHop.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/WindowHop "$APP/Contents/MacOS/WindowHop"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WindowHop</string>
<key>CFBundleIdentifier</key><string>local.windowhop.app</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>WindowHop</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAccessibilityUsageDescription</key><string>WindowHop uses Accessibility to list and focus your open windows.</string>
</dict></plist>
PLIST
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
