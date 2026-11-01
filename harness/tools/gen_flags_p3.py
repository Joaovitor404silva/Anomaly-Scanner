import hashlib, sys

DATA = "D:/modding/cpp/S2CoopPort/data"
DLL = sys.argv[1]
TABLES = ["flags_s2core.tsv", "flags_s2core_tail.tsv", "flags_main.tsv", "flags_main_extra.tsv", "flags_x0.tsv"]
NET = {"net", "netpeer", "netlisten", "netpeerport", "netdx", "netloss", "netrecord", "netfiles", "netloop"}
TEST = {"qevent": "1", "natwpnsid": "1", "natwpnarm": "1", "downsecs": "30", "reviveitem": "1", "downboth": "1", "peerbye": "1"}
DEV = {"devcmd": "1"}
PORTS = {"host": {"netlisten": "7795", "netpeerport": "7794"}, "client": {"netlisten": "7794", "netpeerport": "7795"}}
OUT = {"host": "C:/nola_inst/P3A/flags.txt", "client": "C:/nola_inst/P3B/flags.txt"}

dll = open(DLL, "rb").read()
blocks = []
pos = dll.find(b"k1\tt\tv\n")
while pos >= 0:
    nxt = dll.find(b"k1\tt\tv\n", pos + 1)
    end = dll.find(b"\x00", pos)
    if nxt >= 0 and nxt < end:
        end = nxt
    blocks.append(dll[pos:end])
    pos = nxt


def embedded(raw):
    if raw in dll:
        return raw
    a = set(raw.split(b"\n"))
    best = max(blocks, key=lambda b: len(a & set(b.split(b"\n"))) / len(a | set(b.split(b"\n"))))
    print("  disk table is not the embedded one; using the embedded block. disk-only:", sorted(a - set(best.split(b"\n"))), "dll-only:", sorted(set(best.split(b"\n")) - a))
    return best
for role in ("host", "client"):
    files = TABLES + ["flags_role_%s.tsv" % role]
    texts = {}
    for f in files:
        print(role, f)
        texts[f] = embedded(open(DATA + "/" + f, "rb").read()).decode("utf-8")
    d = {}
    for f in files:
        for i, ln in enumerate(texts[f].split("\n")):
            if i == 0 or not ln:
                continue
            p = ln.split("\t")
            if len(p) == 3 and p[0].startswith("s"):
                v = p[2]
                if p[1] == "b":
                    v = "1" if v == "true" else "0"
                d[p[0][1:]] = v
    kv = {k: v for k, v in d.items() if not k.startswith("fps") and k not in NET and k != "nscap" and v != ""}
    nodef = [k for k in TEST if k not in d]
    changed = {k: (d.get(k, "(no default)"), v) for k, v in {**TEST, **DEV}.items() if d.get(k) != v}
    kv.update(TEST)
    kv.update(DEV)
    kv.update(PORTS[role])
    txt = "\r\n".join("%s=%s" % (k, v) for k, v in kv.items()) + "\r\n"
    open(OUT[role], "wb").write(txt.encode("ascii"))
    print(role, len(kv), "keys", hashlib.md5(txt.encode()).hexdigest()[:8], "changed vs release:", changed, "no default (ignored by DLL):", nodef)
