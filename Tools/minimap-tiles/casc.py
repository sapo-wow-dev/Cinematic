"""Read a world's WDT from the local WoW CASC storage (read only) and print
its tiles' minimap texture file IDs. Standard library only.
Usage: python wdt_tiles.py <wow dir> <product> <wdt path> [out.lua] [world]
"""
import os, sys, struct, zlib, glob

WOW, PRODUCT, WDT = sys.argv[1], sys.argv[2], sys.argv[3]
OUT = sys.argv[4] if len(sys.argv) > 4 else None
WORLD = sys.argv[5] if len(sys.argv) > 5 else "World"
DATA = os.path.join(WOW, "Data")


def build_key():
    lines = open(os.path.join(WOW, ".build.info"), encoding="utf-8").read().splitlines()
    head = [h.split("!")[0] for h in lines[0].split("|")]
    for line in lines[1:]:
        row = dict(zip(head, line.split("|")))
        if row.get("Product") == PRODUCT:
            return row["Build Key"], row.get("Version")
    raise SystemExit("product not found")


def config(key):
    path = os.path.join(DATA, "config", key[0:2], key[2:4], key)
    out = {}
    for line in open(path, encoding="utf-8"):
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.split()
    return out


# Local indices: first 9 bytes of an encoded key -> (archive, offset, size)
INDEX = {}


def load_indices():
    newest = {}
    for path in glob.glob(os.path.join(DATA, "data", "*.idx")):
        name = os.path.basename(path)[:-4]
        bucket, version = int(name[:2], 16), int(name[2:], 16)
        if bucket not in newest or version > newest[bucket][0]:
            newest[bucket] = (version, path)
    for _, path in newest.values():
        raw = open(path, "rb").read()
        head_size = struct.unpack_from("<I", raw, 0)[0]
        pos = 8 + head_size
        pos = (pos + 15) & ~15
        size = struct.unpack_from("<I", raw, pos)[0]
        pos += 8
        for at in range(pos, pos + size, 18):
            key = raw[at:at + 9]
            loc = int.from_bytes(raw[at + 9:at + 14], "big")
            length = struct.unpack_from("<I", raw, at + 14)[0]
            INDEX.setdefault(key, (loc >> 30, loc & 0x3FFFFFFF, length))


def blte(data):
    assert data[:4] == b"BLTE", data[:4]
    header = struct.unpack_from(">I", data, 4)[0]
    chunks = []
    if header == 0:
        chunks.append(data[8:])
    else:
        count = int.from_bytes(data[9:12], "big")
        pos, at = 12, header
        for _ in range(count):
            comp = struct.unpack_from(">I", data, pos)[0]
            chunks.append(data[at:at + comp])
            at += comp
            pos += 24
    out = bytearray()
    for chunk in chunks:
        mode = chunk[:1]
        if mode == b"N":
            out += chunk[1:]
        elif mode == b"Z":
            out += zlib.decompress(chunk[1:])
        else:
            raise ValueError("chunk mode %r" % mode)
    return bytes(out)


def read_ekey(ekey_hex):
    loc = INDEX.get(bytes.fromhex(ekey_hex)[:9])
    if not loc:
        return None
    archive, offset, size = loc
    with open(os.path.join(DATA, "data", "data.%03d" % archive), "rb") as f:
        f.seek(offset)
        raw = f.read(size)
    return blte(raw[30:])


ENCODING = {}


def load_encoding(ekey):
    raw = read_ekey(ekey)
    assert raw[:2] == b"EN"
    ck, ek = raw[3], raw[4]
    ce_page_kb = struct.unpack_from(">H", raw, 5)[0]
    ce_pages = struct.unpack_from(">I", raw, 9)[0]
    espec_size = struct.unpack_from(">I", raw, 18)[0]
    pos = 22 + espec_size + ce_pages * 32
    page = ce_page_kb * 1024
    for p in range(ce_pages):
        at, end = pos + p * page, pos + (p + 1) * page
        while at < end:
            count = raw[at]
            if count == 0:
                break
            ckey = raw[at + 6:at + 6 + ck]
            ENCODING[ckey] = raw[at + 6 + ck:at + 6 + ck + ek]
            at += 6 + ck + ek * count


def hashlittle2(data, pc=0, pb=0):
    mask = 0xFFFFFFFF
    def rot(x, k): return ((x << k) | (x >> (32 - k))) & mask
    length = len(data)
    a = b = c = (0xDEADBEEF + length + pc) & mask
    c = (c + pb) & mask
    i = 0
    while length > 12:
        a = (a + struct.unpack_from("<I", data, i)[0]) & mask
        b = (b + struct.unpack_from("<I", data, i + 4)[0]) & mask
        c = (c + struct.unpack_from("<I", data, i + 8)[0]) & mask
        a = (a - c) & mask; a ^= rot(c, 4); c = (c + b) & mask
        b = (b - a) & mask; b ^= rot(a, 6); a = (a + c) & mask
        c = (c - b) & mask; c ^= rot(b, 8); b = (b + a) & mask
        a = (a - c) & mask; a ^= rot(c, 16); c = (c + b) & mask
        b = (b - a) & mask; b ^= rot(a, 19); a = (a + c) & mask
        c = (c - b) & mask; c ^= rot(b, 4); b = (b + a) & mask
        length -= 12; i += 12
    if length == 0:
        return c, b
    tail = data[i:] + b"\0" * 12
    a = (a + struct.unpack_from("<I", tail, 0)[0]) & mask
    b = (b + struct.unpack_from("<I", tail, 4)[0]) & mask
    c = (c + struct.unpack_from("<I", tail, 8)[0]) & mask
    c ^= b; c = (c - rot(b, 14)) & mask
    a ^= c; a = (a - rot(c, 11)) & mask
    b ^= a; b = (b - rot(a, 25)) & mask
    c ^= b; c = (c - rot(b, 16)) & mask
    a ^= c; a = (a - rot(c, 4)) & mask
    b ^= a; b = (b - rot(a, 14)) & mask
    c ^= b; c = (c - rot(b, 24)) & mask
    return c, b


def root_lookup(raw, want_hashes):
    """Returns {name hash: ckey} for wanted hashes (english/all locales)."""
    found = {}
    pos = 0
    named_only = True
    if raw[:4] == b"TSFM":
        a, b = struct.unpack_from("<II", raw, 4)
        if a < 100:  # header size, version, total, named
            head, version = a, b
            total, named = struct.unpack_from("<II", raw, 12)
            pos = head
        else:
            version, total, named = 1, a, b
            pos = 12
        named_only = named == total
    else:
        version = 0
    while pos < len(raw):
        if version >= 2:
            n, locale, f1, f2 = struct.unpack_from("<IIII", raw, pos)
            f3 = raw[pos + 16]
            content = f1 | f2 | (f3 << 17)
            pos += 17
        else:
            n, content, locale = struct.unpack_from("<III", raw, pos)
            pos += 12
        ids = struct.unpack_from("<%di" % n, raw, pos)
        pos += 4 * n
        if version == 0:
            # interleaved ckey + hash
            ckeys = [raw[pos + i * 24:pos + i * 24 + 16] for i in range(n)]
            hashes = [raw[pos + i * 24 + 16:pos + i * 24 + 24] for i in range(n)]
            pos += 24 * n
        else:
            ckeys = [raw[pos + i * 16:pos + i * 16 + 16] for i in range(n)]
            pos += 16 * n
            has_names = not (content & 0x10000000) or named_only
            hashes = None
            if has_names:
                hashes = [raw[pos + i * 8:pos + i * 8 + 8] for i in range(n)]
                pos += 8 * n
        fid = -1
        for i in range(n):
            fid += ids[i] + 1
            if hashes:
                h = struct.unpack("<Q", hashes[i])[0]
                if h in want_hashes and (locale & 0x2 or locale == 0xFFFFFFFF or locale & 0x1F7 == 0x1F6 or True):
                    found.setdefault(h, (fid, ckeys[i]))
    return found


def main():
    key, version = build_key()
    print("build", version, key)
    cfg = config(key)
    load_indices()
    print("index entries", len(INDEX))
    load_encoding(cfg["encoding"][1])
    print("encoding entries", len(ENCODING))
    root = read_ekey(ENCODING[bytes.fromhex(cfg["root"][0])].hex())
    print("root bytes", len(root), root[:4])
    name = WDT.upper().replace("/", "\\").encode()
    c, b = hashlittle2(name)
    wants = {(c << 32) | b: "cb", (b << 32) | c: "bc"}
    found = root_lookup(root, wants)
    if not found:
        raise SystemExit("WDT name not in root: " + WDT)
    h, (fid, ckey) = next(iter(found.items()))
    print("wdt", WDT, "file ID", fid, "hash order", wants[h])
    ekey = ENCODING.get(ckey)
    wdt = read_ekey(ekey.hex()) if ekey else None
    if not wdt:
        raise SystemExit("WDT not in local storage")
    pos, maid = 0, None
    while pos + 8 <= len(wdt):
        magic, size = wdt[pos:pos + 4], struct.unpack_from("<I", wdt, pos + 4)[0]
        if magic == b"DIAM":
            maid = wdt[pos + 8:pos + 8 + size]
        pos += 8 + size
    if not maid:
        raise SystemExit("no MAID chunk")
    per = len(maid) // (64 * 64) // 4
    print("MAID ids per tile", per)
    tiles = {}
    for y in range(64):
        for x in range(64):
            vals = struct.unpack_from("<%dI" % per, maid, (y * 64 + x) * per * 4)
            if vals[per - 1]:
                tiles[(x, y)] = vals[per - 1]
    print("tiles with a minimap", len(tiles))
    for probe in [(34, 32), (32, 34)]:
        print("probe", probe, tiles.get(probe))
    if OUT:
        with open(OUT, "w", encoding="utf-8", newline="\n") as f:
            f.write("-- %s minimap tiles, by column then row: file IDs (from %s, %s %s)\n" % (WORLD, WDT, PRODUCT, version))
            f.write("local _, ns = ...\nns.minimapTiles = ns.minimapTiles or {}\n")
            f.write("ns.minimapTiles.%s = {\n" % WORLD)
            for x in sorted({k[0] for k in tiles}):
                row = ", ".join("[%d] = %d" % (y, tiles[(x, y)]) for y in sorted(y for (xx, y) in tiles if xx == x))
                f.write("\t[%d] = { %s },\n" % (x, row))
            f.write("}\n")
        print("wrote", OUT)


main()
