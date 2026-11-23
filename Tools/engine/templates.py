"""The game's frame templates as parts recipes, read from its own XML (the console's `exportInterfaceFiles code`).

For each template: its kind, size, mixins, scripts, key values, a status bar's fill, and every part it makes (each
texture, mask, font string and button texture with its parentKey or name, draw layer, atlas or file, size, anchors,
hidden, alpha), its child frames as recipes of their own, with every inherited template merged in (in the inherits
order, then its own, the way the game builds it). Only definitions that load on that client count (Forever is game
type `camelot`, see .claude/skills/test/gamesource.py).

It writes Tools/engine/api/templates-<client>.lua (git-ignored, with the rest of Tools/engine/api: it's Blizzard's
data, kept on this PC). Offline stand-ins use it through Tools/offline/templateparts.lua, so a frame made from a
game template has the template's real parts (frame.Icon, frame.Spark, their atlases and sizes) instead of stubs.
Nothing of it is ever packaged (.pkgmeta leaves Tools out) or copied into the addon.

From the repo root:

    python -I Tools/engine/templates.py                    (every client's export; the templates the addon names,
                                                            the Preview Match plan's, and what they're built on)
    python -I Tools/engine/templates.py <client> Name ...  (only those, for that client)
    python -I Tools/engine/templates.py --show <Name> [client]   (one recipe, readable)
    python -I Tools/engine/templates.py --selftest
"""
import glob
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "test"))
import gamesource  # noqa: E402

OUT_DIR = os.path.join(ROOT, "Tools", "engine", "api")
# The Preview Match plan's templates (Tools/preview-match-plan.md), on top of the ones the addon's code names.
PLAN = ["CastingBarFrameTemplate", "SmallCastingBarFrameTemplate", "PlayerCastingBarFrameTemplate",
        "TargetSpellBarTemplate", "NamePlateCastingBarTemplate", "ActionButtonTemplate", "GameTooltipTemplate",
        "GroupLootFrameBaseTemplate", "NamePlatePreviewTemplate", "NamePlateUnitFrameTemplate",
        "CompactUnitFrameTemplate", "TargetFrameTemplate"]
LAYERS = ("BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT")
BUTTON_TEXTURES = ("NormalTexture", "PushedTexture", "HighlightTexture", "DisabledTexture", "CheckedTexture",
                   "DisabledCheckedTexture", "ThumbTexture")
FRAME_KINDS = {"Frame", "Button", "CheckButton", "StatusBar", "Slider", "EditBox", "ScrollFrame", "Cooldown",
               "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "Model", "PlayerModel",
               "ModelScene", "DressUpModel", "ColorSelect", "MovieFrame", "Browser", "Minimap", "EventFrame",
               "EventButton", "DropdownButton", "ContainedAlertFrame", "ItemButton", "UnitPositionFrame",
               "ArchaeologyDigSiteFrame", "QuestPOIFrame", "ScenarioPOIFrame", "OffScreenFrame", "Checkout",
               "FogOfWarFrame", "CinematicModel", "TabardModel", "POIFrame"}


def strip(tag):
    return tag.rsplit("}", 1)[-1]


def num(v):
    try:
        f = float(v)
        return int(f) if f == int(f) else f
    except (TypeError, ValueError):
        return v


def flag(v):
    return None if v is None else v.lower() == "true"


def size_of(el):
    for s in el:
        if strip(s.tag) == "Size":
            x, y = s.get("x"), s.get("y")
            for a in s:
                if strip(a.tag) == "AbsDimension":
                    x, y = a.get("x", x), a.get("y", y)
            if x is not None or y is not None:
                return [num(x) if x is not None else None, num(y) if y is not None else None]
    return None


def anchors_of(el):
    out = []
    for s in el:
        if strip(s.tag) != "Anchors":
            continue
        for a in s:
            if strip(a.tag) != "Anchor":
                continue
            x, y = a.get("x"), a.get("y")
            for o in a:
                if strip(o.tag) == "Offset":
                    x, y = o.get("x", x), o.get("y", y)
                    for d in o:
                        if strip(d.tag) == "AbsDimension":
                            x, y = d.get("x", x), d.get("y", y)
            point = a.get("point")
            out.append({"point": point, "rel": a.get("relativeKey") or a.get("relativeTo"),
                        "relPoint": a.get("relativePoint") or point, "x": num(x or 0), "y": num(y or 0)})
    return out


def keyvalues_of(el):
    out = {}
    for s in el:
        if strip(s.tag) == "KeyValues":
            for kv in s:
                if strip(kv.tag) == "KeyValue" and kv.get("key"):
                    out[kv.get("key")] = {"value": kv.get("value"), "type": kv.get("type", "string")}
    return out


def region(el, layer=None, sub=None):
    """One texture / mask / font string as a part."""
    kind = strip(el.tag)
    part = {"kind": kind, "key": el.get("parentKey"), "name": el.get("name")}
    if layer:
        part["layer"], part["sub"] = layer, num(sub) if sub is not None else 0
    for attr in ("atlas", "file", "inherits", "text", "justifyH", "justifyV", "alphaMode"):
        if el.get(attr) is not None:
            part[{"inherits": "font"}.get(attr, attr)] = el.get(attr)
    for attr in ("useAtlasSize", "hidden", "setAllPoints"):
        if el.get(attr) is not None:
            part[attr] = flag(el.get(attr))
    for attr in ("alpha", "scale"):
        if el.get(attr) is not None:
            part[attr] = num(el.get(attr))
    s = size_of(el)
    if s:
        part["size"] = s
    a = anchors_of(el)
    if a:
        part["points"] = a
    for c in el:
        t = strip(c.tag)
        if t == "Color":
            part["color"] = [num(c.get(k, 1)) for k in ("r", "g", "b", "a")]
        elif t == "TexCoords":
            part["texCoords"] = [num(c.get(k)) for k in ("left", "right", "top", "bottom")]
        elif t == "MaskedTextures":
            part["masks"] = [m.get("childKey") for m in c if m.get("childKey")]
    return part


def part_id(p, i):
    return p.get("key") or p.get("name") or ("#%d" % i)


class Index:
    """Every named element of one client's export XML, the loading definition first."""

    def __init__(self, client, root):
        self.client, self.root, self.byname, self.bad = client, root, {}, []
        where = gamesource.xml_index(client, root)
        for addon, rel, path, toc in gamesource.walk(root, (".xml",)):
            v = gamesource.verdict(client, rel, toc)
            if v.startswith("no:"):
                continue
            try:
                tree = ET.parse(path)
            except ET.ParseError as err:
                self.bad.append("%s/%s: %s" % (addon, rel, err))
                continue
            for el in tree.iter():
                name = el.get("name")
                if name and "$parent" not in name.lower() and strip(el.tag) in FRAME_KINDS | {"Texture", "FontString",
                                                                                               "Font"}:
                    at = next((d["at"] for d in where.get(name.lower(), []) if not d["verdict"].startswith("no:")), "")
                    self.byname.setdefault(name.lower(), (el, at, v))

    def get(self, name):
        return self.byname.get(name.strip().lower())


def recipe(index, name, seen=None):
    """The template's recipe, its inherits merged in; None when it isn't in the client's XML."""
    seen = seen or []
    found = index.get(name)
    if not found or name.lower() in [s.lower() for s in seen]:
        return None
    el, at, _ = found
    return build(index, el, seen + [name], at)


def build(index, el, seen, at=None):
    kind = strip(el.tag)
    out = {"kind": kind, "name": el.get("name"), "chain": [], "mixins": [], "parts": [], "children": [],
           "scripts": {}, "keyValues": {}}
    if at:
        out["at"] = at
    # The inherited ones first, in order, each overridden by the next and by this one's own.
    for parent in [p.strip() for p in (el.get("inherits") or "").split(",") if p.strip()]:
        base = recipe(index, parent, seen)
        out["chain"].append(parent)
        if not base:
            out.setdefault("unknown", []).append(parent)  # (a C-side template such as SecureUnitButtonTemplate)
            continue
        merge(out, base)
    if el.get("mixin"):
        out["mixins"] += [m.strip() for m in el.get("mixin").split(",") if m.strip()]
    for attr in ("hidden", "enableMouse", "setAllPoints", "virtual"):
        if el.get(attr) is not None:
            out[attr] = flag(el.get(attr))
    for attr in ("frameStrata", "frameLevel", "parentKey", "alpha", "scale"):
        if el.get(attr) is not None:
            out[attr] = num(el.get(attr))
    s = size_of(el)
    if s:
        out["size"] = s
    a = anchors_of(el)
    if a:
        out["points"] = a
    out["keyValues"].update(keyvalues_of(el))
    own_parts, own_children = [], []
    for c in el:
        t = strip(c.tag)
        if t == "Layers":
            for layer in c:
                if strip(layer.tag) != "Layer":
                    continue
                for r in layer:
                    if strip(r.tag) in ("Texture", "FontString", "MaskTexture", "Line"):
                        own_parts.append(region(r, layer.get("level", "ARTWORK"), layer.get("textureSubLevel")))
        elif t in BUTTON_TEXTURES or t in ("BarTexture", "ButtonText"):
            p = region(c)
            p["kind"], p["slot"] = ("FontString" if t == "ButtonText" else "Texture"), t
            p["key"] = p.get("key") or t
            if t == "BarTexture":
                out["bar"] = p
            else:
                own_parts.append(p)
        elif t == "BarColor":
            out["barColor"] = [num(c.get(k, 1)) for k in ("r", "g", "b", "a")]
        elif t == "Scripts":
            for s in c:
                out["scripts"][strip(s.tag)] = s.get("method") or s.get("function") or ("inherit=" + s.get("inherit")
                                                                                       if s.get("inherit") else "code")
        elif t == "Frames":
            for f in c:
                if strip(f.tag) in FRAME_KINDS:
                    own_children.append(build(index, f, seen))
    merge(out, {"parts": own_parts, "children": own_children})
    return out


def merge(out, base):
    """base's pieces into out: parts and children by key (a later one with the same key replaces), the rest
    copied unless out has it already from its own XML (callers merge parents first)."""
    for list_key in ("parts", "children"):
        have = {part_id(p, i): i for i, p in enumerate(out[list_key])}
        for i, p in enumerate(base.get(list_key, [])):
            k = part_id(p, len(out[list_key]) + i)
            if k in have and not k.startswith("#"):
                out[list_key][have[k]] = p
            else:
                have[k] = len(out[list_key])
                out[list_key].append(p)
    for k in ("mixins", "chain"):
        for v in base.get(k, []):
            if v not in out.setdefault(k, []):
                out[k].append(v)
    for k in ("scripts", "keyValues"):
        out.setdefault(k, {}).update(base.get(k, {}))
    for k, v in base.items():
        if k in ("parts", "children", "mixins", "chain", "scripts", "keyValues", "name", "at", "virtual"):
            continue
        out[k] = v


def lua(value, indent=""):
    """A Python value as a Lua literal."""
    if value is None:
        return "nil"
    if value is True or value is False:
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return '"%s"' % value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    inner = indent + "\t"
    if isinstance(value, list):
        if not value:
            return "{}"
        if all(not isinstance(v, (dict, list)) for v in value):
            return "{ " + ", ".join(lua(v) for v in value) + " }"
        return "{\n" + "".join("%s%s,\n" % (inner, lua(v, inner)) for v in value) + indent + "}"
    items = [(k, v) for k, v in sorted(value.items()) if v is not None and v != {} and v != []]
    if not items:
        return "{}"
    def key(k):
        return k if re.match(r"^[A-Za-z_]\w*$", k) else "[%s]" % lua(k)
    return "{\n" + "".join("%s%s = %s,\n" % (inner, key(k), lua(v, inner)) for k, v in items) + indent + "}"


def addon_templates():
    """Template names the addon's own code writes as strings (ending Template, or a known button/frame name)."""
    names = set()
    for path in glob.glob(os.path.join(ROOT, "**", "*.lua"), recursive=True):
        rel = os.path.relpath(path, ROOT)
        if rel.startswith(("Tools", "Libs", ".claude")):
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        names.update(re.findall(r'"([A-Z]\w*Template)"', text))
        for m in re.finditer(r'CreateFrame\(\s*"\w+"\s*,[^,]*,[^,]*,\s*"([\w, ]+)"', text):
            names.update(n.strip() for n in m.group(1).split(","))
    return names


def write(client, recipes, bad):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "templates-%s.lua" % client)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by Tools/engine/templates.py from %s's exportInterfaceFiles code: the game's templates as\n"
                "-- parts recipes, for the offline stand-ins (Tools/offline/templateparts.lua). Blizzard's data:\n"
                "-- git-ignored, never packaged or copied into the addon.\n" % client)
        if bad:
            f.write("-- XML files it couldn't read: %d\n" % len(bad))
        f.write("return " + lua(recipes) + "\n")
    return path


def main(args):
    found = gamesource.exports()
    if not found:
        sys.exit("no export: start the game with -console, then exportInterfaceFiles code at the character screen")
    want_client = args[0] if args and args[0] in gamesource.TYPES else None
    names = [a for a in args if a != want_client] or sorted(addon_templates() | set(PLAN))
    for client, root in found:
        if want_client and client != want_client:
            continue
        index = Index(client, root)
        recipes, missing = {}, []
        for n in names:
            r = recipe(index, n)
            if r:
                recipes[n] = r
            elif n.endswith("Template") or not args:
                # (From the addon's code, only names that read like templates are worth a line: the regex also
                # catches frame names and layers.)
                if n.endswith("Template"):
                    missing.append(n)
            else:
                missing.append(n)
        path = write(client, recipes, index.bad)
        print("%s: %d template(s) -> %s" % (client, len(recipes), os.path.relpath(path, ROOT)))
        if missing:
            print("  not in its XML (made in Lua, C-side, or another client's): %s" % ", ".join(missing))
        if index.bad:
            print("  %d XML file(s) unreadable, e.g. %s" % (len(index.bad), index.bad[0]))


def show(name, client=None):
    for c, root in gamesource.exports():
        if client and c != client:
            continue
        r = recipe(Index(c, root), name)
        if not r:
            print("%s: %s not in its XML" % (c, name))
            continue
        print("== %s %s <%s> %s, chain %s, mixins %s, size %s" % (c, name, r["kind"], r.get("at", "?"),
                                                                 " > ".join(r["chain"]) or "-",
                                                                 ", ".join(r["mixins"]) or "-", r.get("size")))
        if r.get("bar"):
            print("  bar: %s" % (r["bar"].get("atlas") or r["bar"].get("file")))

        def parts(rec, pad):
            for p in rec["parts"]:
                print("%s%s %s %s/%s %s size %s%s%s" % (pad, p["kind"], part_id(p, 0), p.get("layer", "-"),
                                                     p.get("sub", "-"), p.get("atlas") or p.get("file") or
                                                     p.get("font") or "", p.get("size"),
                                                     " hidden" if p.get("hidden") else "",
                                                     " " + " ".join("%s>%s %s %s,%s" % (a["point"], a["rel"] or "",
                                                                                         a["relPoint"], a["x"], a["y"])
                                                                    for a in p.get("points", []))))
            for ch in rec["children"]:
                print("%schild %s <%s> %s size %s" % (pad, ch.get("parentKey") or ch.get("name"), ch["kind"],
                                                     " > ".join(ch["chain"]), ch.get("size")))
                parts(ch, pad + "    ")
        parts(r, "  ")


XML_BASE = '''<Ui xmlns="http://www.blizzard.com/wow/ui/">
  <StatusBar name="BaseBarTemplate" mixin="BarMixin" virtual="true">
    <Size x="200" y="12"/>
    <BarTexture atlas="bar-fill" useAtlasSize="true"/>
    <Layers>
      <Layer level="BACKGROUND" textureSubLevel="2">
        <Texture parentKey="Background" atlas="bar-back">
          <Anchors><Anchor point="TOPLEFT" x="-1" y="1"/><Anchor point="BOTTOMRIGHT" x="1" y="-1"/></Anchors>
        </Texture>
      </Layer>
      <Layer level="ARTWORK">
        <Texture parentKey="Icon"><Size x="16" y="16"/>
          <Anchors><Anchor point="RIGHT" relativeTo="$parent" relativePoint="LEFT" x="-5"/></Anchors>
        </Texture>
        <FontString parentKey="Text" inherits="GameFontHighlightSmall" justifyH="CENTER"/>
      </Layer>
    </Layers>
    <Frames>
      <Frame parentKey="Holder"><Size><AbsDimension x="10" y="4"/></Size>
        <Layers><Layer level="OVERLAY"><Texture parentKey="Spark" file="Interface\\Spark" hidden="true"/></Layer></Layers>
      </Frame>
    </Frames>
    <Scripts><OnLoad method="OnLoad"/></Scripts>
  </StatusBar>
  <StatusBar name="SmallBarTemplate" inherits="BaseBarTemplate, SecureUnitButtonTemplate" mixin="SmallMixin" virtual="true">
    <Size x="150" y="10"/>
    <KeyValues><KeyValue key="kind" value="small"/></KeyValues>
    <Layers><Layer level="ARTWORK" textureSubLevel="4">
      <Texture parentKey="Icon" atlas="small-icon"><Size x="12" y="12"/></Texture>
    </Layer></Layers>
  </StatusBar>
</Ui>
'''


def selftest():
    import shutil
    tmp = tempfile.mkdtemp()
    bad = []
    try:
        addon = os.path.join(tmp, "_forever_", "BlizzardInterfaceCode", "Interface", "AddOns", "Blizzard_Bars")
        os.makedirs(os.path.join(addon, "Mainline"))
        with open(os.path.join(addon, "Blizzard_Bars.toc"), "w") as f:
            f.write("Bars.xml\nMainline\\Rogue.xml [AllowLoadGameType mainline] [ExcludeLoadGameType camelot]\n")
        with open(os.path.join(addon, "Bars.xml"), "w") as f:
            f.write(XML_BASE)
        with open(os.path.join(addon, "Mainline", "Rogue.xml"), "w") as f:
            f.write('<Ui xmlns="http://www.blizzard.com/wow/ui/"><Frame name="RogueTemplate" virtual="true"/></Ui>\n')
        gamesource._XML.clear()
        gamesource._FILES.clear()
        root = os.path.dirname(addon)
        index = Index("forever", root)
        r = recipe(index, "SmallBarTemplate")
        parts = {part_id(p, 0): p for p in (r or {}).get("parts", [])}
        if not r:
            bad.append("no recipe")
        else:
            if r["chain"] != ["BaseBarTemplate", "SecureUnitButtonTemplate"] or r.get("unknown") != ["SecureUnitButtonTemplate"]:
                bad.append("chain %r %r" % (r["chain"], r.get("unknown")))
            if r["mixins"] != ["BarMixin", "SmallMixin"]:
                bad.append("mixins %r" % r["mixins"])
            if r.get("size") != [150, 10]:
                bad.append("own size wins %r" % r.get("size"))
            if parts.get("Icon", {}).get("atlas") != "small-icon" or parts["Icon"].get("size") != [12, 12] \
                    or parts["Icon"].get("layer") != "ARTWORK" or parts["Icon"].get("sub") != 4:
                bad.append("own Icon replaces the base's %r" % parts.get("Icon"))
            if [part_id(p, 0) for p in r["parts"]] != ["Background", "Icon", "Text"]:
                bad.append("parts order %r" % [part_id(p, 0) for p in r["parts"]])
            bg = parts.get("Background", {})
            if bg.get("points") != [{"point": "TOPLEFT", "rel": None, "relPoint": "TOPLEFT", "x": -1, "y": 1},
                                    {"point": "BOTTOMRIGHT", "rel": None, "relPoint": "BOTTOMRIGHT", "x": 1, "y": -1}]:
                bad.append("anchors %r" % bg.get("points"))
            if parts.get("Text", {}).get("font") != "GameFontHighlightSmall" or parts["Text"]["kind"] != "FontString":
                bad.append("font string %r" % parts.get("Text"))
            if (r.get("bar") or {}).get("atlas") != "bar-fill":
                bad.append("bar %r" % r.get("bar"))
            holder = r["children"][0] if r["children"] else {}
            if holder.get("parentKey") != "Holder" or holder.get("size") != [10, 4] \
                    or holder["parts"][0].get("file") != "Interface\\Spark" or holder["parts"][0].get("hidden") is not True:
                bad.append("child %r" % holder)
            if r["scripts"] != {"OnLoad": "OnLoad"} or r["keyValues"] != {"kind": {"value": "small", "type": "string"}}:
                bad.append("scripts / keys %r %r" % (r["scripts"], r["keyValues"]))
            if r.get("at") != "Blizzard_Bars/Bars.xml:25":
                bad.append("at %r" % r.get("at"))
        if recipe(index, "RogueTemplate") is not None:
            bad.append("a no: file's template made a recipe")
        text = lua({"A": r})
        if 'atlas = "small-icon"' not in text or "[\"A\"]" in text:
            bad.append("lua output")
        try:
            import lupa.lua51 as lua51
            back = lua51.LuaRuntime().execute(text and "return " + text)
            if back["A"]["parts"][3]["font"] != "GameFontHighlightSmall":
                bad.append("lua reads back wrong")
        except ImportError:
            pass
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("selftest: %s" % ("PASS" if not bad else "FAIL\n  " + "\n  ".join(bad)))
    return not bad


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    a = sys.argv[1:]
    if a == ["--selftest"]:
        sys.exit(0 if selftest() else 1)
    if a and a[0] == "--show":
        show(a[1], a[2] if len(a) > 2 else None)
    else:
        main(a)
