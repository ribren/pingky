#!/bin/bash
# Notarize Pingky.app with Apple, staple the ticket, and (optionally) upload the
# result to the GitHub release. Run ./make-app.sh first so the app is Developer ID
# signed with the hardened runtime.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in your login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   2. A stored notarytool credential profile. Create one with EITHER:
#        xcrun notarytool store-credentials pingky \
#          --apple-id "<you@example.com>" --team-id "S8574FLKF8" --password "<app-specific-pw>"
#      or an App Store Connect API key:
#        xcrun notarytool store-credentials pingky \
#          --key "<AuthKey_XXXX.p8>" --key-id "<KEYID>" --issuer "<ISSUER-UUID>"
#
# Usage:
#   ./notarize.sh                    # notarize + staple, then print the upload command
#   UPLOAD=1 ./notarize.sh           # also upload to the RELEASE_TAG release (default v1.0)
#   NOTARY_PROFILE=pingky ./notarize.sh
set -euo pipefail

cd "$(dirname "$0")"

APP_DIR="Pingky.app"
ZIP="Pingky-macOS.zip"
PROFILE="${NOTARY_PROFILE:-pingky}"
RELEASE_TAG="${RELEASE_TAG:-v1.0}"

[ -d "${APP_DIR}" ] || { echo "error: ${APP_DIR} not found — run ./make-app.sh first."; exit 1; }

echo "==> Signature check (expect a 'Developer ID Application' authority + runtime flag):"
codesign -dv --verbose=4 "${APP_DIR}" 2>&1 | grep -Ei "Authority|flags" | sed 's/^/    /' || true
if ! codesign -dv --verbose=4 "${APP_DIR}" 2>&1 | grep -q "Developer ID Application"; then
    echo "error: ${APP_DIR} is not Developer ID signed. Re-run ./make-app.sh with the cert installed."
    exit 1
fi

echo "==> Zipping for submission..."
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

echo "==> Submitting to Apple notary service (profile: ${PROFILE})..."
xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

echo "==> Stapling the notarization ticket into the app..."
xcrun stapler staple "${APP_DIR}"
xcrun stapler validate "${APP_DIR}"

echo "==> Gatekeeper assessment:"
spctl -a -vvv --type exec "${APP_DIR}" 2>&1 | sed 's/^/    /' || true

echo "==> Re-zipping the stapled app..."
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

if [ "${UPLOAD:-0}" = "1" ]; then
    echo "==> Uploading to GitHub release ${RELEASE_TAG}..."
    gh release upload "${RELEASE_TAG}" "${ZIP}" --clobber
    echo "==> Uploaded."
else
    echo "==> Done. To publish this notarized build:"
    echo "    gh release upload ${RELEASE_TAG} ${ZIP} --clobber"
fi
