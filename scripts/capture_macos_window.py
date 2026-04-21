#!/usr/bin/env python3
"""
capture_macos_window.py — Capture a named macOS app window using Quartz.

Usage:
    python3 capture_macos_window.py <owner_name> <output.png>

Finds the frontmost window belonging to a process whose name contains
<owner_name>, reads its on-screen bounds from Quartz, then uses
`screencapture -R x,y,w,h` for a region capture.

No accessibility permissions required. Screen Recording permission is NOT
needed for region-based screencapture (unlike window-ID capture).
"""

import sys
import subprocess
import Quartz

def find_window_bounds(owner_name: str) -> tuple[int, int, int, int] | None:
    """Return (x, y, width, height) in logical screen coords, or None."""
    windows = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
        Quartz.kCGNullWindowID,
    )
    for w in windows:
        owner = w.get(Quartz.kCGWindowOwnerName, "")
        layer = w.get(Quartz.kCGWindowLayer, 99)
        if owner_name.lower() in owner.lower() and layer == 0:
            bounds = w.get(Quartz.kCGWindowBounds, {})
            x = int(bounds.get("X", 0))
            y = int(bounds.get("Y", 0))
            width = int(bounds.get("Width", 0))
            height = int(bounds.get("Height", 0))
            if width > 0 and height > 0:
                return x, y, width, height
    return None


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <owner_name> <output.png>", file=sys.stderr)
        sys.exit(1)

    owner_name, output = sys.argv[1], sys.argv[2]
    bounds = find_window_bounds(owner_name)
    if bounds is None:
        print(f"No on-screen window found for '{owner_name}'", file=sys.stderr)
        sys.exit(1)

    x, y, w, h = bounds
    region = f"{x},{y},{w},{h}"
    print(f"Window bounds for '{owner_name}': {region}")
    result = subprocess.run(
        ["screencapture", "-x", "-R", region, output],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"screencapture error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    print(f"Saved: {output}")


if __name__ == "__main__":
    main()

