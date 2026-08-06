#!/usr/bin/env bash
#
# Builds Posture.app — one command, from a clean checkout to something you can
# double-click. Run from the app/ directory on a Mac with Xcode installed.
#
#   ./build.sh          release build, bundled and ad-hoc signed
#   ./build.sh --run    the same, then launch it
#
set -euo pipefail

cd "$(dirname "$0")"

CONFIGURATION="release"
BUNDLE="build/Posture.app"
BINARY=".build/${CONFIGURATION}/Posture"

echo "==> Testing the core"
swift test

echo "==> Building ${CONFIGURATION}"
swift build -c "${CONFIGURATION}" --product Posture

echo "==> Assembling ${BUNDLE}"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BINARY}" "${BUNDLE}/Contents/MacOS/Posture"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"

# Ad-hoc signature. Enough for the sandbox and the camera prompt on your own
# machine; a real Developer ID signature is only needed to hand it to somebody
# else without Gatekeeper complaining.
echo "==> Signing"
codesign --force --deep --sign - \
	--entitlements Resources/Posture.entitlements \
	"${BUNDLE}"

codesign --verify --verbose "${BUNDLE}"

echo
echo "Built ${BUNDLE}"
echo "Launch it, then look for the square icon in the menu bar."
echo "First run asks for camera and notification permission."

if [[ "${1:-}" == "--run" ]]; then
	echo "==> Launching"
	open "${BUNDLE}"
fi
