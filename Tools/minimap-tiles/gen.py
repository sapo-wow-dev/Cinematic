# Appends one world's minimap tile file IDs to MinimapTiles.lua, read from the
# local WoW Forever install (read only). Usage: python -I gen.py <WDT file ID> <World> <MinimapTiles.lua>
# Kalimdor = 782779, Azeroth = 775971. casc.py is the storage reader it uses.
import sys, struct
FID, WNAME, DEST = int(sys.argv[1]), sys.argv[2], sys.argv[3]
sys.argv = ["x", "C:/Program Files (x86)/World of Warcraft", "wowf", "none"]
import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "casc.py")).read().replace("\nmain()\n", "\n"))
key, version = build_key(); cfg = config(key); load_indices(); load_encoding(cfg["encoding"][1])
raw = read_ekey(ENCODING[bytes.fromhex(cfg["root"][0])].hex())
pos = struct.unpack_from("<I", raw, 4)[0]; ck = None
while pos < len(raw) and not ck:
    n, locale, f1, f2 = struct.unpack_from("<IIII", raw, pos); f3 = raw[pos+16]; pos += 17
    ids = struct.unpack_from("<%di" % n, raw, pos); pos += 4*n; fid = -1
    for i in range(n):
        fid += ids[i] + 1
        if fid == FID: ck = raw[pos+16*i:pos+16*i+16]; break
    pos += 16*n
    if not ((f1|f2|(f3<<17)) & 0x10000000): pos += 8*n
data = read_ekey(ENCODING[ck].hex()); p = 0
while data[p:p+4] != b"DIAM": p += 8 + struct.unpack_from("<I", data, p+4)[0]
size = struct.unpack_from("<I", data, p+4)[0]; maid = data[p+8:p+8+size]; per = size // 16384
cols = {}
for y in range(64):
    for x in range(64):
        v = struct.unpack_from("<I", maid, ((y*64+x)*per + per-1)*4)[0]
        if v: cols.setdefault(x, []).append((y, v))
with open(DEST, "a", encoding="utf-8", newline="\n") as f:
    f.write("-- %s (WDT file %d, wowf %s): %d tiles\n" % (WNAME, FID, version, sum(len(r) for r in cols.values())))
    f.write("ns.minimapTiles.%s = {\n" % WNAME)
    for x in sorted(cols):
        f.write("\t[%d] = { %s },\n" % (x, ", ".join("[%d] = %d" % e for e in cols[x])))
    f.write("}\n")
print("done", WNAME)
