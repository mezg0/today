#!/bin/zsh
# Build, sign, notarize, and publish a release of Today.
#
#   scripts/release.sh 0.2.0
#
# One-time setup (both interactive, both yours to run):
#   1. In Xcode: Settings › Accounts › Manage Certificates › + › Developer ID Application.
#   2. xcrun notarytool store-credentials Today --apple-id you@example.com --team-id 7M3B48C774
#      (paste an app-specific password from appleid.apple.com when asked)
#
# What it does: archive with automatic signing → export as Developer ID →
# submit to Apple for notarization and wait → staple the ticket → zip →
# create a GitHub Release with the zip attached.
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version, e.g. 0.2.0>}"
TEAM_ID="7M3B48C774"
PROFILE="Today"                     # notarytool keychain profile name
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/Today.xcarchive"
EXPORT="$OUT/export"
ZIP="$OUT/Today-$VERSION.zip"

cd "$ROOT"
rm -rf "$OUT" && mkdir -p "$OUT"

echo "▸ Stamping version $VERSION"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml
xcodegen generate >/dev/null

echo "▸ Archiving"
xcodebuild -project Today.xcodeproj -scheme Today -configuration Release \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" archive | grep -E "error:|ARCHIVE" || true
[[ -d "$ARCHIVE" ]] || { echo "archive failed"; exit 1; }

echo "▸ Exporting with Developer ID"
cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates \
  | grep -E "error:|EXPORT" || true
APP="$EXPORT/Today.app"
[[ -d "$APP" ]] || { echo "export failed"; exit 1; }

echo "▸ Zipping for notarization"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Notarizing (Apple usually takes 2–5 minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "▸ Stapling and re-zipping"
xcrun stapler staple "$APP"
rm -f "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute -v "$APP"

echo "▸ Publishing"
git add project.yml Today.xcodeproj
git commit -qm "Release $VERSION" || true
git tag -f "v$VERSION"
git push -q origin main --tags
gh release create "v$VERSION" "$ZIP" --title "Today $VERSION" --generate-notes

echo "✓ https://github.com/mezg0/today/releases/tag/v$VERSION"
