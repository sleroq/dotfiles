import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable


def merge(vga, icons):
    # Fit the square icon artwork into the VGA font's half-em terminal cell.
    scale_upem(icons, vga["hhea"].advanceWidthMax)
    y_offset = (
        vga["hhea"].ascent + vga["hhea"].descent
        - icons["hhea"].ascent - icons["hhea"].descent
    ) // 2
    glyph_names = icons.getGlyphOrder()[1:]
    vga.setGlyphOrder(vga.getGlyphOrder() + glyph_names)
    for name in glyph_names:
        glyph = icons["glyf"][name]
        glyph.coordinates.translate((0, y_offset))
        vga["glyf"][name] = glyph
        vga["hmtx"][name] = icons["hmtx"][name]

    # The original BMP subtables can't map the supplementary private-use icons.
    full_cmap = CmapSubtable.newSubtable(12)
    full_cmap.platformID, full_cmap.platEncID, full_cmap.language = 3, 10, 0
    full_cmap.cmap = vga.getBestCmap() | icons.getBestCmap()
    vga["cmap"].tables.append(full_cmap)
    vga["COLR"], vga["CPAL"] = icons["COLR"], icons["CPAL"]

    names = vga["name"]
    family = "Teto98 VGA"
    replacements = {1: family, 3: family + " 1.0", 4: family, 6: "Teto98VGA-Regular"}
    for record in names.names:
        if record.nameID in replacements:
            record.string = replacements[record.nameID]
    names.setName(
        "Based on PxPlus IBM VGA 8x16 by VileR; modified to add Pixel Icons by Azganoth and the NixOS glyph from Font Logos.",
        10, 3, 1, 0x0409,
    )


if __name__ == "__main__":
    source, pixel_icons, output = sys.argv[1:]
    with TTFont(source, recalcTimestamp=False) as vga, TTFont(pixel_icons) as icons:
        merge(vga, icons)
        vga.save(output)
