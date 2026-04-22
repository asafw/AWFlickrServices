#!/usr/bin/env zsh
# macos_screenshots.sh
# 1. Launch app → screenshot empty state
# 2. Relaunch with AUTO_SEARCH=cat → wait for images → screenshot search results
# 3. Click first photo → wait → screenshot photo detail

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/screenshots/macos"
APP="$REPO/.build/debug/FlickrDemoApp"

mkdir -p "$OUT"

KEY="${FLICKR_API_KEY:-}"
[[ -z "$KEY" && -f /tmp/flickr_api_key ]] && KEY="$(cat /tmp/flickr_api_key | tr -d '[:space:]')"
[[ -z "$KEY" ]] && { echo "Error: set FLICKR_API_KEY"; exit 1; }

echo "▶ Building…"
cd "$REPO"
swift build --product FlickrDemoApp 2>&1 | tail -2

get_bounds() {
  python3 "$REPO/scripts/get_window_bounds.py" FlickrDemoApp
}

screenshot() {
  local name="$1"
  local bounds
  bounds=$(get_bounds) || { echo "  window not found for $name"; exit 1; }
  read -r WX WY WW WH <<< "$bounds"
  screencapture -x -R "$WX,$WY,$WW,$WH" "$OUT/${name}.png"
  echo "📸 ${name}.png  (${WW}x${WH})"
}

# 1. Empty state
echo "▶ Launching (empty state)…"
FLICKR_API_KEY="$KEY" "$APP" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT
sleep 5
screenshot "macos_empty_state"
kill $APP_PID 2>/dev/null; trap - EXIT; sleep 1

# 2. Search results — AUTO_SEARCH avoids focusing any text field
echo "▶ Launching (AUTO_SEARCH=cat)…"
FLICKR_API_KEY="$KEY" AUTO_SEARCH=cat "$APP" &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null; true' EXIT
sleep 15
screenshot "macos_search_results"

# 3. Click first photo (approx center of first thumbnail cell)
bounds=$(get_bounds)
read -r WX WY WW WH <<< "$bounds"
CLICK_X=$((WX + 80))
CLICK_Y=$((WY + 220))
echo "▶ Clicking first photo at ($CLICK_X, $CLICK_Y)…"
cliclick c:${CLICK_X},${CLICK_Y}
sleep 10
screenshot "macos_photo_detail"

echo "▶ Done."
ls "$OUT"
