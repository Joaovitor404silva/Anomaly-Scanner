import ctypes, struct, sys
dll = ctypes.WinDLL(r"D:\modding\tools\repak\oo2core_9_win64.dll")
f = dll.OodleLZ_Decompress
f.restype = ctypes.c_int64
f.argtypes = [ctypes.c_void_p, ctypes.c_int64, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int64, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int]
def dec(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[:4])[0]
    src = d[4:]
    out = ctypes.create_string_buffer(n)
    r = f(src, len(src), out, n, 1, 0, 0, None, 0, None, None, None, 0, 3)
    return r, out.raw[:max(r,0)]
if __name__ == "__main__":
    r, b = dec(sys.argv[1])
    print("decoded", r)
    open(sys.argv[2], "wb").write(b)