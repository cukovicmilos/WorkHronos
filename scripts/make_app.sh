#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=dist/WorkHronos.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WorkHronos "$APP/Contents/MacOS/"

ICON_KEYS=""
if [ -f assets/AppIcon.icns ]; then
    cp assets/AppIcon.icns "$APP/Contents/Resources/"
    ICON_KEYS="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WorkHronos</string>
    <key>CFBundleIdentifier</key>
    <string>com.orff.workhronos</string>
    <key>CFBundleName</key>
    <string>WorkHronos</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
${ICON_KEYS}
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP — run: open $APP"
