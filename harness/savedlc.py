import sys, struct, ctypes, os, zlib

OODLE = r"D:\modding\tools\repak\oo2core_9_win64.dll"
NAMES = {1: "PreOrder", 2: "Deluxe", 4: "Ultimate", 8: "DLC1 (Cost of Hope)"}


def dec(path):
    dll = ctypes.WinDLL(OODLE)
    f = dll.OodleLZ_Decompress
    f.restype = ctypes.c_int64
    f.argtypes = [ctypes.c_void_p, ctypes.c_int64, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int64, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int]
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[:4])[0]
    out = ctypes.create_string_buffer(n)
    r = f(d[4:], len(d) - 4, out, n, 1, 0, 0, None, 0, None, None, None, 0, 3)
    if r != n:
        raise SystemExit("savedlc: cannot decode %s (got %d of %d bytes)" % (path, r, n))
    return out.raw[:n]


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


def masks(b, data):
    hs = headers(b)
    out = []
    for n, h in enumerate(hs):
        end = hs[n + 1] if n + 1 < len(hs) else len(b)
        hit = None
        p = h + 16
        while p < min(end, h + 200):
            m = struct.unpack("<I", b[p:p + 4])[0]
            if m < 0x100 and b[p + 4:p + 6] == b"\x00\x00" and struct.unpack("<I", b[p + 6:p + 10])[0] < 0x1000 and os.path.exists(os.path.join(data, guidstr(b[p + 10:p + 26]) + ".sav")):
                hit = p
                break
            p += 1
        if hit is None:
            m = struct.unpack("<I", b[h + 20:h + 24])[0]
            if m < 0x100 and b[h + 24:h + 26] == b"\x00\x00":
                hit = h + 20
        if hit is not None:
            out.append(struct.unpack("<I", b[hit:hit + 4])[0])
    return len(hs), out


def crc_ok(path):
    d = open(path, "rb").read()
    return len(d) > 8 and struct.unpack("<I", d[-4:])[0] == zlib.crc32(d[:-4])


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: savedlc.py <save dir with CampaignsSave.sav>")
    sd = sys.argv[1]
    idx = os.path.join(sd, "CampaignsSave.sav")
    td = os.path.join(sd, "TempCampaigns")
    temps = sorted(os.path.join(td, f) for f in os.listdir(td) if f.endswith(".sav")) if os.path.isdir(td) else []
    bad = [os.path.relpath(p, sd) for p in [idx] + temps if not crc_ok(p)]
    b = dec(idx)
    nh, ms = masks(b, os.path.join(sd, "Data"))
    allm = 0
    for m in ms:
        allm |= m
    tm = 0
    for p in temps:
        if crc_ok(p):
            for m in masks(dec(p), os.path.join(sd, "Data"))[1]:
                tm |= m
    need = ", ".join(v for k, v in NAMES.items() if (allm | tm) & k) or "none"
    print("savedlc: %d save headers, %d DLC masks read, union 0x%x, %d TempCampaigns union 0x%x (%s), bad CRC %d" % (nh, len(ms), allm, len(temps), tm, need, len(bad)))
    if len(ms) != nh:
        print("savedlc: WARN %d header(s) without a readable DLC mask" % (nh - len(ms)))
    if bad:
        print("savedlc: BAD CRC (the game rejects these files and starts a new campaign): %s" % ", ".join(bad[:5]))
        sys.exit(4)
    sys.exit(3 if allm | tm else 0)


main()
