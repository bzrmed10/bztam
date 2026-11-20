#!/usr/bin/env python3
"""Copies app screenshots from the ci-screenshots branch into the website as small WebP files.

Usage: python3 scripts/website/screens.py /path/to/ci-screenshots-checkout
Writes website/assets/screens/<lang>-<name>-<light|dark>.webp (660 px wide, enough for a 330 pt phone at 2x).
"""
import pathlib
import sys
from PIL import Image

SRC = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(__file__).resolve().parents[2] / "website/assets/screens"
OUT.mkdir(parents=True, exist_ok=True)

# website name -> (light screenshot, dark screenshot)
SCREENS = {
    "home": ("01-home", "13-home-dark"),
    "add": ("02-add", "15-add-dark"),
    "activity": ("03-activity", "16-activity-dark"),
    "category": ("04-category", "17-category-dark"),
    "settings": ("05-settings", "20-settings-dark"),
    "scan": ("07-scan-review", "21-scan-dark"),
    "insights": ("09-insights", "14-insights-dark"),
    "ask": ("10-ask", "22-ask-dark"),
    "dart": ("11-dart", "23-dart-dark"),
    "export": ("12-export", None),
    "friends": ("24-friends", "26-friends-dark"),
    "split": ("25-split", None),
}

for lang in ("en", "fr", "ar"):
    for name, (light, dark) in SCREENS.items():
        for mode, shot in (("light", light), ("dark", dark or light)):
            src = SRC / f"{lang}-{shot}.png"
            if not src.exists():
                src = SRC / f"{lang}-{light}.png"  # no dark shot yet: fall back to light
            if not src.exists():
                continue
            im = Image.open(src).convert("RGB")
            w, h = im.size
            im = im.resize((660, round(h * 660 / w)), Image.LANCZOS)
            im.save(OUT / f"{lang}-{name}-{mode}.webp", "WEBP", quality=82, method=6)
print("Wrote", len(list(OUT.glob("*.webp"))), "files to", OUT)
