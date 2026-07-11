#!/bin/bash
# Build Pingky and assemble a double-clickable Pingky.app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Pingky"
APP_DIR="${APP_NAME}.app"
BUILD_BIN=".build/release/${APP_NAME}"

echo "==> Building release binary..."
swift build -c release

echo "==> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BUILD_BIN}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
else
    echo "    (AppIcon.icns not found — run: swift generate_icon.swift && iconutil -c icns Pingky.iconset -o AppIcon.icns)"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.ribren.pingky</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Prefer a Developer ID Application identity (required for notarized distribution).
# Override by exporting SIGN_IDENTITY="Developer ID Application: Name (TEAMID)".
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "${SIGN_IDENTITY}" ]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')
fi

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "==> Signing with Developer ID (hardened runtime + timestamp):"
    echo "    ${SIGN_IDENTITY}"
    codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
    echo "==> No 'Developer ID Application' identity found — falling back to ad-hoc."
    echo "    (Ad-hoc builds run locally but CANNOT be notarized. See notarize.sh.)"
    codesign --force --sign - "${APP_DIR}"
fi

echo "==> Done: $(pwd)/${APP_DIR}"
echo "    Run it with:  open ${APP_DIR}"
echo "    Or move it to /Applications and add to Login Items."
