#!/usr/bin/env python3
"""Draws the Bztam app icon (the "Wallet" concept) in its three iOS appearances.

Run: python3 scripts/icon/make_icon.py
Writes AppIcon.png, AppIcon-dark.png and AppIcon-tinted.png into the app icon set.
Shapes are drawn on a 120-unit grid (same as the concept sketch) at 4x and scaled down for smooth edges.
iOS rounds the corners itself, so the image is a full square.
"""
import pathlib
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parents[2] / "Bztam/Assets.xcassets/AppIcon.appiconset"
SIZE, SS = 1024, 4
K = SIZE * SS / 120

FOREST, LIME, TINT, CARD = "#14290B", "#A6E36F", "#E3F5D2", "#2F6B12"


def draw(bg, card, wallet, flap, dot, transparent=False):
    img = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0) if transparent else bg)
    d = ImageDraw.Draw(img)

    def rr(x, y, w, h, r, fill):
        d.rounded_rectangle([x * K, y * K, (x + w) * K, (y + h) * K], radius=r * K, fill=fill)

    rr(26, 30, 50, 16, 6, card)        # card peeking out
    rr(18, 40, 76, 52, 13, wallet)     # wallet body
    rr(60, 55, 42, 22, 11, flap)       # clasp
    cx, cy, r = 72, 66, 4.5
    d.ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=dot)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


draw(LIME, CARD, FOREST, TINT, FOREST).convert("RGB").save(OUT / "AppIcon.png")
# Dark home screen: forest background, lime wallet. Apple asks for an opaque dark background here too.
draw(FOREST, CARD, LIME, FOREST, LIME).convert("RGB").save(OUT / "AppIcon-dark.png")
# Tinted home screen: grayscale, iOS adds the tint. Light parts take the tint, black stays dark.
draw("#000000", "#5A5A5A", "#FFFFFF", "#000000", "#FFFFFF").convert("L").save(OUT / "AppIcon-tinted.png")
print("Wrote", OUT)
