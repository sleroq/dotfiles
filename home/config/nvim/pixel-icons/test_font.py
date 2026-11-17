from pathlib import Path
import unittest

from fontTools.ttLib import TTFont


class PixelFontTest(unittest.TestCase):
    def test_color_layers_keep_their_positions(self):
        font = TTFont(Path(__file__).with_name("PixelIcons.ttf"))
        for layers in font["COLR"].ColorLayers.values():
            for layer in layers:
                glyph = font["glyf"][layer.name]
                self.assertEqual(font["hmtx"][layer.name][1], glyph.xMin, layer.name)


if __name__ == "__main__":
    unittest.main()
