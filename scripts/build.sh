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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
SPARKLE=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE.txt"
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
<key>CFBundleShortVersionString</key><string>1.0.3</string>
<key>CFBundleVersion</key><string>4</string>
<key>SUFeedURL</key><string>https://raw.githubusercontent.com/singhgit2023/WindowHop/main/appcast.xml</string>
<key>SUEnableAutomaticChecks</key><false/>
<key>SUAutomaticallyUpdate</key><false/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAccessibilityUsageDescription</key><string>WindowHop uses Accessibility to list and focus your open windows.</string>
</dict></plist>
PLIST
PUBLIC_KEY="$(cat scripts/sparkle-public-key.txt)"
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_KEY" "$APP/Contents/Info.plist"
# Sign nested executable code from the inside out. Preserve framework symlinks.
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
for component in \
  "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
  "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
  "$FRAMEWORK/Versions/B/Autoupdate" \
  "$FRAMEWORK/Versions/B/Updater.app" \
  "$FRAMEWORK"; do
  codesign --force --sign "$SIGNING_IDENTITY" "$component"
done
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
