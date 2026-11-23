"""Round icon rendering shared by the icon trim scan: crops an icon's art as
Style/ActionBarStyle.lua does (CDM_TRIM) and cuts it with our own round mask
(Textures/ActionRoundMask.tga). Reads the game's art in place from the
console's `exportInterfaceFiles art` (never copied into the repo)."""
import os
import numpy as np
from PIL import Image

WOW = r"C:\Program Files (x86)\World of Warcraft"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def icons_dir(client="_forever_"):
    return os.path.join(WOW, client, "BlizzardInterfaceArt", "Interface", "ICONS")


def load(path, size=64):
    im = Image.open(path).convert("RGB")
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


_mask = {}


def mask(size):
    if size not in _mask:
        m = Image.open(os.path.join(REPO, "Textures", "ActionRoundMask.tga")).convert("RGBA")
        a = np.asarray(m)[:, :, 3]
        _mask[size] = np.asarray(Image.fromarray(a).resize((size, size), Image.LANCZOS)).astype(np.float32) / 255.0
    return _mask[size]


def render(art, trim, size=96, back=(0.08, 0.08, 0.1)):
    """The icon as the round CDM shows it: art cropped by trim each side, scaled, masked."""
    n = art.shape[0]
    lo, hi = trim * n, (1 - trim) * n
    im = Image.fromarray((art * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS, box=(lo, lo, hi, hi))
    rgb = np.asarray(im).astype(np.float32) / 255.0
    a = mask(size)[:, :, None]
    return rgb * a + np.array(back, np.float32) * (1 - a)
