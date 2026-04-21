#!/usr/bin/env python3
"""Print "X Y W H" for the first on-screen window whose owner contains the given name."""
import sys
import Quartz

name = sys.argv[1].lower() if len(sys.argv) > 1 else ""
windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID,
)
for w in windows:
    if name in w.get(Quartz.kCGWindowOwnerName, "").lower() and w.get(Quartz.kCGWindowLayer, 99) == 0:
        b = w.get(Quartz.kCGWindowBounds, {})
        x, y, width, height = int(b.get("X", 0)), int(b.get("Y", 0)), int(b.get("Width", 0)), int(b.get("Height", 0))
        if width > 0 and height > 0:
            print(x, y, width, height)
            sys.exit(0)
print("window not found", file=sys.stderr)
sys.exit(1)
