#!/usr/bin/env zsh
# macos_screenshots.sh — Launch FlickrDemoApp, drive it via osascript, capture windows.
#
# Usage (from repo root):
#   bash scripts/macos_screenshots.sh
#
# Requires: FLICKR_API_KEY env var OR /tmp/flickr_api_key file.
# Output: screenshots/macos/*.png

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_ROOT/screenshots/macos"
APP_BIN="$REPO_ROOT/.build/debug/FlickrDemoApp"

mkdir -p "$OUT_DIR"

# ── Resolve API key ──────────────────────────────────────────────────────────
if [[ -n "${FLICKR_API_KEY:-}" ]]; then
  KEY="$FLICKR_API_KEY"
elif [[ -f /tmp/flickr_api_key ]]; then
  KEY="$(cat /tmp/flickr_api_key | tr -d '[:space:]')"
else
  echo "Error: set FLICKR_API_KEY or write your key to /tmp/flickr_api_key" >&2
  exit 1
fi

# ── Build (incremental — fast on a warm cache) ───────────────────────────────
echo "▶ Building FlickrDemoApp…"
cd "$REPO_ROOT"
swift build --product FlickrDemoApp 2>&1 | tail -3

# ── Helper: capture the frontmost FlickrDemoApp window ───────────────────────
capture_window() {
  local name="$1"
  # Pass APP_PID so the script can activate the app via NSRunningApplication
  # before measuring bounds — no accessibility permissions required.
  python3 "$REPO_ROOT/scripts/capture_macos_window.py" "FlickrDemoApp" \
    "$OUT_DIR/${name}.png" "$APP_PID" 2>&1 || {
    echo "  ⚠ Quartz capture failed; falling back to full screen"
    screencapture -x "$OUT_DIR/${name}.png"
  }
  echo "📸 ${name}.png"
}

# ── Launch app ───────────────────────────────────────────────────────────────
echo "▶ Launching FlickrDemoApp (empty state)…"
FLICKR_API_KEY="$KEY" "$APP_BIN" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT

# Wait for window to appear.
sleep 5

# ── Screenshot 1: empty / sign-in state ─────────────────────────────────────
capture_window "macos_empty_state"

# Kill and relaunch with MOCK_PHOTOS so photos appear instantly (bypasses the
# corporate proxy that blocks api.flickr.com in this environment).
kill $APP_PID 2>/dev/null || true
trap - EXIT
sleep 1

echo "▶ Launching FlickrDemoApp (mock photos)…"
FLICKR_API_KEY="$KEY" MOCK_PHOTOS=1 MOCK_AUTH=1 "$APP_BIN" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT

# Photos populate immediately on init; wait for SwiftUI to render + CDN load.
sleep 10

# ── Screenshot 2: search results grid ────────────────────────────────────────
capture_window "macos_search_results"

# Kill and relaunch with MOCK_DETAIL so the app immediately presents the
# photo detail sheet — no osascript click interaction needed.
kill $APP_PID 2>/dev/null || true
trap - EXIT
sleep 1

echo "▶ Launching FlickrDemoApp (mock detail)…"
FLICKR_API_KEY="$KEY" MOCK_PHOTOS=1 MOCK_AUTH=1 MOCK_DETAIL=1 "$APP_BIN" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT

sleep 10

# ── Screenshot 3: photo detail ────────────────────────────────────────────────
capture_window "macos_photo_detail"

echo "▶ Done. Screenshots written to $OUT_DIR"
ls "$OUT_DIR"
