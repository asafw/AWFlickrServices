#!/usr/bin/env zsh
# ios_screenshots.sh — Run iOS screenshot UITests and extract PNGs.
#
# Usage (from repo root):
#   bash scripts/ios_screenshots.sh
#
# Output: screenshots/ios/*.png

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$REPO_ROOT/Examples/FlickrDemoApp-iOS"
OUT_DIR="$REPO_ROOT/screenshots/ios"
BUNDLE="/tmp/flickrdemo_screenshots.xcresult"

mkdir -p "$OUT_DIR"
cd "$IOS_DIR"

echo "▶ Generating Xcode project…"
xcodegen generate --quiet

rm -rf "$BUNDLE"
echo "▶ Running screenshot tests…"
set +e
xcodebuild test \
  -scheme FlickrDemoApp-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FlickrDemoScreenshots \
  -resultBundlePath "$BUNDLE" \
  2>&1 | grep -E '(📸|error:|Test Case.*passed|Test Case.*failed|Executed)'
set -e

echo "▶ Extracting PNGs…"
python3 "$REPO_ROOT/scripts/extract_screenshots.py" "$BUNDLE" "$OUT_DIR"

echo "▶ Done. Screenshots written to $OUT_DIR"
ls "$OUT_DIR"
