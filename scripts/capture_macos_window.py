#!/usr/bin/env python3
"""
capture_macos_window.py — Capture a named macOS app window using Quartz.

Usage:
    python3 capture_macos_window.py <owner_name> <output.png> [pid]

Finds the window belonging to a process whose name contains <owner_name>,
reads its on-screen bounds from Quartz, optionally activates the app by
PID (no accessibility permissions needed), then uses screencapture -R.
"""

import sys
import subprocess
import time
import Quartz

def activate_app(pid: int) -> None:
    """Bring the app to the foreground using NSRunningApplication (no permissions needed)."""
    try:
        import AppKit
        app = AppKit.NSRunningApplication.runningApplicationWithProcessIdentifier_(pid)
        if app:
            # NSApplicationActivateIgnoringOtherApps = 1 << 1
            app.activateWithOptions_(1 << 1)
            time.sleep(1.5)  # Let the window reach the front and Quartz settle
    except Exception as e:
        print(f"  (activate warning: {e})", file=sys.stderr)


def find_window(owner_name: str) -> tuple[int, int, int, int, int] | None:
    """Return (window_id, x, y, width, height) for the first matching window."""
    windows = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionAll | Quartz.kCGWindowListExcludeDesktopElements,
        Quartz.kCGNullWindowID,
    )
    for w in windows:
        owner = w.get(Quartz.kCGWindowOwnerName, "")
        name = w.get(Quartz.kCGWindowName, "") or ""
        layer = w.get(Quartz.kCGWindowLayer, 99)
        if owner_name.lower() in owner.lower() and layer == 0 and len(name) > 0:
            bounds = w.get(Quartz.kCGWindowBounds, {})
            x = int(bounds.get("X", 0))
            y = int(bounds.get("Y", 0))
            width = int(bounds.get("Width", 0))
            height = int(bounds.get("Height", 0))
            window_id = w.get(Quartz.kCGWindowNumber, None)
            if width > 200 and height > 200 and window_id is not None:
                return window_id, x, y, width, height
    return None


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <owner_name> <output.png> [pid]", file=sys.stderr)
        sys.exit(1)

    owner_name, output = sys.argv[1], sys.argv[2]
    pid = int(sys.argv[3]) if len(sys.argv) >= 4 else None

    # Bring the app to front so window server marks it as on-screen.
    if pid is not None:
        activate_app(pid)

    result = find_window(owner_name)
    if result is None:
        print(f"No on-screen window found for '{owner_name}'", file=sys.stderr)
        sys.exit(1)

    window_id, x, y, w, h = result
    region = f"{x},{y},{w},{h}"
    print(f"Window bounds for '{owner_name}': {region} (id={window_id})")
    # -l captures the specific window by ID — works even when occluded by other apps.
    capture = subprocess.run(
        ["screencapture", "-x", "-l", str(window_id), output],
        capture_output=True,
        text=True,
    )
    if capture.returncode != 0:
        print(f"screencapture error: {capture.stderr}", file=sys.stderr)
        sys.exit(1)
    print(f"Saved: {output}")
if __name__ == "__main__":
    main()


