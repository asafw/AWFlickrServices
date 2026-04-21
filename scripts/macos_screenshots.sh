#!/usr/bin/env zsh
# macos_screenshots.sh — Launch FlickrDemoApp, search for cats, capture windows.
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
  python3 "$REPO_ROOT/scripts/capture_macos_window.py" "FlickrDemoApp" \
    "$OUT_DIR/${name}.png" "$APP_PID" 2>&1 || {
    echo "  ⚠ Quartz capture failed; falling back to full screen"
    screencapture -x "$OUT_DIR/${name}.png"
  }
  echo "📸 ${name}.png"
}

# ── Screenshot 1: empty state ────────────────────────────────────────────────
echo "▶ Launching FlickrDemoApp (empty state)…"
FLICKR_API_KEY="$KEY" "$APP_BIN" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT
sleep 4
capture_window "macos_empty_state"
kill $APP_PID 2>/dev/null || true
trap - EXIT
sleep 1

# ── Screenshot 2: search results (real API + real images) ───────────────────
echo "▶ Launching FlickrDemoApp (search: cat)…"
FLICKR_API_KEY="$KEY" AUTO_SEARCH=cat "$APP_BIN" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT
# Wait for API response + thumbnail images to load from CDN.
sleep 15
capture_window "macos_search_results"
kill $APP_PID 2>/dev/null || true
trap - EXIT
sleep 1

# ── Screenshot 3: photo detail ───────────────────────────────────────────────
# Use MOCK_PHOTOS so the first photo is available instantly when MOCK_DETAIL opens
# the sheet. The detail view still downloads the real CDN image from Flickr.
echo "▶ Launching FlickrDemoApp (photo detail)…"
FLICKR_API_KEY="$KEY" MOCK_PHOTOS=1 MOCK_DETAIL=1 "$APP_BIN" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT
# Wait for search results, then detail sheet opens automatically via MOCK_DETAIL.
sleep 15
capture_window "macos_photo_detail"

echo "▶ Done. Screenshots written to $OUT_DIR"
ls "$OUT_DIR"
