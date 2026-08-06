#!/usr/bin/env bash
#
# Builds a distributable Posture DMG — signed, notarized, and stapled, so a
# stranger can download it and macOS opens it without complaint.
#
#   ./release.sh
#
# One-time setup before the first run:
#
#   1. Join the Apple Developer Program (developer.apple.com, $99/year).
#   2. Create a "Developer ID Application" certificate:
#      Xcode -> Settings -> Accounts -> Manage Certificates -> "+".
#   3. Store notarization credentials in the keychain (needs an app-specific
#      password from account.apple.com):
#        xcrun notarytool store-credentials "posture" \
#          --apple-id you@example.com --team-id XXXXXXXXXX
#
# Overrides, if the defaults don't fit:
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"  which cert to use
#   NOTARY_PROFILE="posture"                                 keychain profile
#
# In CI there is no keychain profile; set these three instead and they take
# precedence:
#   NOTARY_APPLE_ID, NOTARY_PASSWORD (app-specific), NOTARY_TEAM_ID
#
set -euo pipefail

cd "$(dirname "$0")"

BUNDLE="build/Posture.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-posture}"

# ---------------------------------------------------------------------------
# Prerequisites — fail early with instructions, not halfway through a build.
# ---------------------------------------------------------------------------

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
	SIGN_IDENTITY="$(security find-identity -v -p codesigning \
		| grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)"
fi
if [[ -z "${SIGN_IDENTITY}" ]]; then
	echo "error: no Developer ID Application certificate in your keychain." >&2
	echo "Create one in Xcode -> Settings -> Accounts -> Manage Certificates," >&2
	echo "or set SIGN_IDENTITY explicitly. See the comment at the top of this script." >&2
	exit 1
fi

if [[ -n "${NOTARY_APPLE_ID:-}" ]]; then
	NOTARY_ARGS=(--apple-id "${NOTARY_APPLE_ID}" --password "${NOTARY_PASSWORD}" --team-id "${NOTARY_TEAM_ID}")
else
	NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE}")
	if ! xcrun notarytool history "${NOTARY_ARGS[@]}" >/dev/null 2>&1; then
		echo "error: no notarization credentials under keychain profile '${NOTARY_PROFILE}'." >&2
		echo "Store them once with:" >&2
		echo "  xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" --apple-id you@example.com --team-id XXXXXXXXXX" >&2
		exit 1
	fi
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
DMG="build/Posture-${VERSION}.dmg"

echo "==> Releasing Posture ${VERSION}"
echo "    signing as: ${SIGN_IDENTITY}"

# ---------------------------------------------------------------------------
# Build, then replace build.sh's ad-hoc signature with the real one. The
# hardened runtime (--options runtime) is a notarization requirement.
# ---------------------------------------------------------------------------

./build.sh

echo "==> Signing with Developer ID"
codesign --force --deep --options runtime \
	--sign "${SIGN_IDENTITY}" \
	--entitlements Resources/Posture.entitlements \
	"${BUNDLE}"
codesign --verify --strict --verbose "${BUNDLE}"

# ---------------------------------------------------------------------------
# Package as a drag-to-Applications DMG with the styled window: background,
# fixed icon positions, no toolbar. Layout lives in dmg.json; the background
# is rendered fresh so it never drifts from the site's palette.
# ---------------------------------------------------------------------------

echo "==> Creating ${DMG}"
node scripts/make-dmg-background.mjs
rm -f "${DMG}"
npx appdmg dmg.json "${DMG}"

codesign --force --sign "${SIGN_IDENTITY}" "${DMG}"

# ---------------------------------------------------------------------------
# Notarize: Apple scans the upload, usually within a few minutes. --wait
# blocks until there's a verdict. Stapling attaches the ticket to the DMG so
# Gatekeeper can verify it even offline.
# ---------------------------------------------------------------------------

echo "==> Notarizing (this waits for Apple, typically a few minutes)"
if ! xcrun notarytool submit "${DMG}" "${NOTARY_ARGS[@]}" --wait; then
	echo "error: notarization failed. Inspect the log with:" >&2
	echo "  xcrun notarytool log <submission-id> <same credentials as the submit>" >&2
	exit 1
fi

echo "==> Stapling"
xcrun stapler staple "${DMG}"
xcrun stapler validate "${DMG}"

# A copy under a stable name, so the website can point at
# releases/latest/download/Posture.dmg without a rebuild per release.
cp "${DMG}" "build/Posture.dmg"

echo
echo "Done: ${DMG}"
echo "Upload it anywhere (GitHub Releases, your site) — it installs cleanly."
