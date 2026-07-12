#!/bin/bash
# Notarize Pingky.app with Apple, staple the ticket, and (optionally) upload the
# result to the GitHub release. Run ./make-app.sh first so the app is Developer ID
# signed with the hardened runtime.
#
# Prerequisites:
#   1. A "Developer ID Application" certificate in your login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   2. App Store Connect API key credentials for the notary service.
#
# Authenticating to the notary service — pick ONE:
#
#   A) API key passed directly (RECOMMENDED — no keychain dependency).
#      A locked login keychain (Mac asleep/locked, or a headless session) makes a
#      stored --keychain-profile unreadable ("User interaction is not allowed"),
#      which stalls notarytool. Passing the key inline avoids that entirely:
#        NOTARY_KEY="$HOME/Downloads/AuthKey_XXXX.p8" \
#        NOTARY_KEY_ID="XXXXXXXXXX" \
#        NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
#        UPLOAD=1 ./notarize.sh
#
#   B) A stored keychain profile (convenient on an interactive, unlocked machine):
#        xcrun notarytool store-credentials pingky \
#          --key "<AuthKey_XXXX.p8>" --key-id "<KEYID>" --issuer "<ISSUER-UUID>"
#      then:  NOTARY_PROFILE=pingky UPLOAD=1 ./notarize.sh
#
# Other knobs:
#   UPLOAD=1                also upload to the release (default: just print the command)
#   RELEASE_TAG=v1.0        which release to upload to
#   WAIT_TIMEOUT=2h         hard cap on the notary --wait so it can't hang forever
set -euo pipefail

cd "$(dirname "$0")"

APP_DIR="Pingky.app"
ZIP="Pingky-macOS.zip"
PROFILE="${NOTARY_PROFILE:-pingky}"
RELEASE_TAG="${RELEASE_TAG:-v1.0}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-2h}"

# Build the notarytool auth args: prefer an inline API key, else the keychain profile.
if [ -n "${NOTARY_KEY:-}" ]; then
    [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER:-}" ] || {
        echo "error: NOTARY_KEY is set but NOTARY_KEY_ID and/or NOTARY_ISSUER are missing."; exit 1; }
    AUTH=(--key "${NOTARY_KEY}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER}")
    echo "==> Authenticating with API key ${NOTARY_KEY_ID} (inline, keychain-free)."
else
    AUTH=(--keychain-profile "${PROFILE}")
    echo "==> Authenticating with keychain profile '${PROFILE}'."
fi

[ -d "${APP_DIR}" ] || { echo "error: ${APP_DIR} not found — run ./make-app.sh first."; exit 1; }

echo "==> Signature check (expect a 'Developer ID Application' authority + runtime flag):"
SIG_INFO=$(codesign -dv --verbose=4 "${APP_DIR}" 2>&1 || true)
printf '%s\n' "${SIG_INFO}" | grep -Ei "Authority|flags" | sed 's/^/    /' || true
if [[ "${SIG_INFO}" != *"Developer ID Application"* ]]; then
    echo "error: ${APP_DIR} is not Developer ID signed. Re-run ./make-app.sh with the cert installed."
    exit 1
fi

echo "==> Zipping for submission..."
rm -f "${ZIP}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

echo "==> Submitting to Apple notary service (wait timeout: ${WAIT_TIMEOUT})..."
echo "    (Notary turnaround is usually minutes but can back up on Apple's side.)"
xcrun notarytool submit "${ZIP}" "${AUTH[@]}" --wait --timeout "${WAIT_TIMEOUT}"

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
