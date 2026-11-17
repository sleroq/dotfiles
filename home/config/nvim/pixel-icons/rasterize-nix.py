#!/usr/bin/env python3
"""Draw an 8×8 pixel version of the Nix snowflake."""

from pathlib import Path

from PIL import Image

pixels = [
    "..d..l..",
    "..dd.ll.",
    "d.dddlll",
    "dd...ll.",
    ".ll...dd",
    "lllddd.d",
    ".ll.dd..",
    "..l..d..",
]
colors = {"d": (82, 119, 195, 255), "l": (126, 186, 228, 255)}
image = Image.new("RGBA", (8, 8))
for y, row in enumerate(pixels):
    for x, pixel in enumerate(row):
        if pixel in colors:
            image.putpixel((x, y), colors[pixel])
image.save(Path(__file__).with_name("nix.png"))
