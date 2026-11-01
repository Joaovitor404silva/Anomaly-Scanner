import sys, struct, ctypes, os, tempfile, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from oodec import dec, dll
C = dll.OodleLZ_Compress
C.restype = ctypes.c_int64
C.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int64, ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]


def enc(b, comp=8, level=4):
    out = ctypes.create_string_buffer(len(b) + 65536)
    n = C(comp, b, len(b), out, level, None, None, None, None, 0)
    body = struct.pack("<I", len(b)) + out.raw[:n]
    return body + struct.pack("<I", zlib.crc32(body))


def roundtrip(raw):
    fd, p = tempfile.mkstemp(suffix=".sav")
    os.write(fd, raw)
    os.close(fd)
    r, b = dec(p)
    os.remove(p)
    return b


def headers(b):
    r = []
    i = 0
    while True:
        i = b.find(b"\xbb\x00\x00\x00", i)
        if i < 0:
            return r
        d = b[i + 4:i + 12]
        if len(d) == 8 and d[7] == 0x08 and d[6] in (0xdf, 0xde, 0xe0):
            r.append(i)
        i += 1


def guidstr(g):
    return "".join("%08X" % struct.unpack("<I", g[k:k + 4])[0] for k in range(0, 16, 4))


def entries(b, data, verbose=False):
    hs = headers(b)
    r = []
    for n, h in enumerate(hs):
        end = hs[n + 1] if n + 1 < len(hs) else len(b)
        p = h + 16
        found = False
        while p < min(end, h + 200):
            m = struct.unpack("<I", b[p:p + 4])[0]
            if m < 0x100 and b[p + 4:p + 6] == b"\x00\x00" and struct.unpack("<I", b[p + 6:p + 10])[0] < 0x1000:
                g = guidstr(b[p + 10:p + 26])
                if os.path.exists(os.path.join(data, g + ".sav")):
                    r.append(p)
                    found = True
                    if verbose:
                        print("  hdr", h, "mask@", p, hex(m), g)
                    break
            p += 1
        if not found:
            m = struct.unpack("<I", b[h + 20:h + 24])[0]
            if m < 0x100 and b[h + 24:h + 26] == b"\x00\x00":
                r.append(h + 20)
                if verbose:
                    print("  hdr", h, "mask@", h + 20, hex(m), "campaign record (no data file)")
            elif verbose:
                print("  hdr", h, "NO MASK FOUND")
    return r


def main():
    mode, src = sys.argv[1], sys.argv[2]
    dst = sys.argv[3] if len(sys.argv) > 3 else None
    data = os.path.join(os.path.dirname(src), "Data")
    raw = open(src, "rb").read()
    r, b = dec(src)
    assert r == len(b) == struct.unpack("<I", raw[:4])[0], "decode size"
    offs = entries(b, data, mode != "quiet")
    nfiles = len([f for f in os.listdir(data) if f.endswith(".sav")])
    masks = [struct.unpack("<I", b[o:o + 4])[0] for o in offs]
    print("headers", len(headers(b)), "entries with data file", len(offs), "data files", nfiles, "masks", sorted(set(masks)))
    re0 = enc(b)
    assert roundtrip(re0) == b, "re-encode of the original does not round-trip"
    print("roundtrip original OK: raw", len(raw), "re-encoded", len(re0))
    if mode == "strip":
        nb = bytearray(b)
        for o in offs:
            struct.pack_into("<I", nb, o, 0)
        nb = bytes(nb)
        diff = [i for i in range(len(b)) if b[i] != nb[i]]
        print("bytes changed", len(diff), "all inside mask fields", all(any(o <= i < o + 4 for o in offs) for i in diff))
        out = enc(nb)
        back = roundtrip(out)
        assert back == nb, "patched round-trip failed"
        print("roundtrip patched OK; masks now", sorted(set(struct.unpack("<I", back[o:o + 4])[0] for o in entries(back, data))))
        open(dst, "wb").write(out)
        print("wrote", dst, len(out))


main()
