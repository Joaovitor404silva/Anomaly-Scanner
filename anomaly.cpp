#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <string>
#include <vector>
#include <mutex>
#include <unordered_map>
#include <algorithm>
#include "anomaly.h"
#include "opts.h"
#include "quest.h"
#include "s2n_peframe.h"

#define SIG_SM "48 31 E0 48 89 84 24 80 00 00 00 48 8B 1D ?? ?? ?? ?? BE FF FF FF FF 48 85 DB 74 78 48 89 CF 48 8B 05"
#define SIG_SM_RIP 14
#define SIG_NAMEPOOL "41 8B 55 00 48 8D 35 ?? ?? ?? ?? 48 89 F1 E8 ?? ?? ?? ?? 31 DB 41 89 5D 00 8B 17 48 89 F1 E8"
#define SIG_NAMEPOOL_RIP 7

static const UEApi* api;
static bool g_s2, g_nbot;
const UEApi* AnApi() { return api; }

struct Out {
  std::string s;
  void line(const std::string& l) { s += l; s += '\n'; }
  void f(const char* fmt, ...) { char b[4096]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof b, fmt, ap); va_end(ap); line(b); }
};
static std::string Fmt(const char* fmt, ...) { char b[4096]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof b, fmt, ap); va_end(ap); return b; }
static std::string Lower(std::string s) { for (auto& c : s) c = (char)tolower((unsigned char)c); return s; }
static bool Rd(uintptr_t a, void* o, size_t n) { return a && api->read(a, o, n) == 1; }
template <class T> static T RdT(uintptr_t a) { T v{}; Rd(a, &v, sizeof v); return v; }
static uintptr_t RdP(uintptr_t a) { return RdT<uintptr_t>(a); }
static std::string Cmd(const std::string& l) { std::vector<char> b(1 << 20); b[0] = 0; api->cmd(l.c_str(), b.data(), (int)b.size()); return b.data(); }
static std::string ClassOf(uintptr_t a) { char b[1024]; std::string d = api->describe(a, b, sizeof b); return d.substr(0, d.find(' ')); }
static std::vector<std::string> Split(const std::string& s) {
  std::vector<std::string> t; std::string cur; bool q = false, any = false;
  for (char c : s) {
    if (c == '"') { q = !q; any = true; continue; }
    if (!q && (c == ' ' || c == '\t')) { if (any) t.push_back(cur); cur.clear(); any = false; continue; }
    cur += c; any = true;
  }
  if (any) t.push_back(cur);
  return t;
}
static bool IsObjActor(uintptr_t a) {
  std::string r = Cmd(Fmt("obj 0x%llx", (unsigned long long)a)); size_t p = r.find("class chain:"); if (p == std::string::npos) return false;
  std::string l = r.substr(p + 12, r.find('\n', p) - p - 12), w;
  for (char c : l + " ") { if (isalnum((unsigned char)c) || c == '_') w += c; else { if (w == "Obj") return true; w.clear(); } }
  return false;
}
static bool ActorLoc(uintptr_t a, double v[3]) {
  char b[512]; if (api->call(a, "K2_GetActorLocation", "", b, sizeof b) != 1) return false;
  const char* x = strstr(b, "X="); return x && sscanf(x, "X=%lf Y=%lf Z=%lf", &v[0], &v[1], &v[2]) == 3;
}

typedef void (*UidGetFn)(uintptr_t, int*);
static int SafeUidGet(uintptr_t fn, uintptr_t itf) { int v = -1; __try { ((UidGetFn)fn)(itf, &v); } __except (EXCEPTION_EXECUTE_HANDLER) { v = -1; } return v; }
static int UidOf(uintptr_t a) { uintptr_t itf = a + 0x648, vt = RdP(itf), fn = vt ? RdP(vt + 0x10) : 0; return fn ? SafeUidGet(fn, itf) : -1; }

struct NpcRow { uintptr_t addr = 0; int uid = -1, idx = 0, hidden = 0; float hp = -1; double loc[3] = {}; bool haveLoc = false; double dist = 1e18; std::string cls; };

static void CmdNpcs(const std::vector<std::string>& t, Out& o) {
  uopt::Args ao = uopt::Parse(t, 1);
  uintptr_t pawn = api->find("pawn"); double nearLoc[3] = {}; bool haveNear = false, rFilter = ao.Has("r");
  std::string ne = ao.Has("near") ? ao.Str("near") : "pawn";
  if (uopt::ParseXyz(ne, nearLoc)) haveNear = true;
  else { uintptr_t no = api->find(ne.c_str()); if (no) haveNear = ActorLoc(no, nearLoc); else if (ao.Has("near")) { o.line("error: cannot resolve near=" + ne); return; } }
  double rad = ao.Dbl("r", 0); long long wantUid = ao.Has("uid") ? ao.Int("uid", 0) : -1; int newN = (int)ao.Int("new", 0);
  int mx = (int)ao.Int("max", ao.pos.empty() ? 50 : atoi(ao.pos[0].c_str()));
  std::string cf = Lower(ao.Str("class")); bool all = ao.Flag("all");
  std::string r = Cmd("find isa:Obj 1000000 loc nodef");
  std::vector<NpcRow> rows; size_t i = 0;
  while (i < r.size()) {
    size_t j = r.find('\n', i); if (j == std::string::npos) j = r.size();
    std::vector<std::string> tk = Split(r.substr(i, j - i)); i = j + 1;
    if (tk.size() < 2 || tk[0].rfind("0x", 0) != 0) continue;
    NpcRow w; w.addr = (uintptr_t)strtoull(tk[0].c_str(), nullptr, 16); w.cls = tk[1];
    if (w.addr == pawn && !all) continue;
    if (!cf.empty() && Lower(w.cls).find(cf) == std::string::npos) continue;
    for (auto& k : tk) {
      if (k.rfind("idx=", 0) == 0) w.idx = atoi(k.c_str() + 4);
      else if (k.rfind("hidden=", 0) == 0) w.hidden = atoi(k.c_str() + 7);
      else if (k.rfind("loc=", 0) == 0) w.haveLoc = uopt::ParseXyz(k.substr(4), w.loc);
    }
    w.uid = UidOf(w.addr);
    if (wantUid >= 0 && w.uid != wantUid) continue;
    if (w.haveLoc && haveNear) w.dist = uopt::Dist(w.loc, nearLoc);
    if (rFilter && (!w.haveLoc || w.dist > rad)) continue;
    uintptr_t hc = RdP(w.addr + 0x650); w.hp = hc ? RdT<float>(hc + 0x148) : -1.0f;
    rows.push_back(w);
  }
  std::stable_sort(rows.begin(), rows.end(), [](const NpcRow& a, const NpcRow& b) { return a.dist < b.dist; });
  if (newN > 0) { std::stable_sort(rows.begin(), rows.end(), [](const NpcRow& a, const NpcRow& b) { return a.idx > b.idx; }); if ((int)rows.size() > newN) rows.resize(newN); }
  int total = (int)rows.size(); if ((int)rows.size() > mx) rows.resize(mx);
  for (auto& w : rows) {
    std::string d = w.dist < 1e17 ? Fmt("%.0f", w.dist) : "-", lc = w.haveLoc ? Fmt("%.1f,%.1f,%.1f", w.loc[0], w.loc[1], w.loc[2]) : "-";
    o.f("uid=%d 0x%llx %s hp=%g dist=%s loc=%s hidden=%d idx=%d", w.uid, (unsigned long long)w.addr, w.cls.c_str(), w.hp, d.c_str(), lc.c_str(), w.hidden, w.idx);
  }
  o.f("%d npcs", total);
}

static void CmdUid(const std::vector<std::string>& t, Out& o) {
  if (t.size() < 2) { o.line("usage: uid <obj>"); return; }
  uintptr_t a = api->find(t[1].c_str()); if (!a) { o.line("cannot resolve object " + t[1]); return; }
  if (!IsObjActor(a)) { o.line("error: not an Obj actor: " + ClassOf(a)); return; }
  o.f("uid=%d 0x%llx %s", UidOf(a), (unsigned long long)a, ClassOf(a).c_str());
}

static qr::Ring g_qring(2000);
static std::mutex g_qm;
static bool g_qtap, g_qprevOk;
static std::vector<qst::Quest> g_qprev;
static uint64_t g_qlast;
static const qst::QLayout QL;

static bool QRdFn(uint64_t a, void* o, size_t n) { return Rd((uintptr_t)a, o, n); }
static uintptr_t QPool() { static uintptr_t a; if (!a) a = SigFind(0, SIG_NAMEPOOL, SIG_NAMEPOOL_RIP); return a; }
static uintptr_t QSmGlobal() { static uintptr_t a; if (!a) a = SigFind(0, SIG_SM, SIG_SM_RIP); return a; }

static bool QSid(uint32_t h, std::string& out) {
  static std::mutex m; static std::unordered_map<uint32_t, std::string> memo;
  { std::lock_guard<std::mutex> l(m); auto it = memo.find(h); if (it != memo.end()) { out = it->second; return !out.empty(); } }
  std::string r; qst::PoolSlot ps;
  uintptr_t p0 = QPool();
  if (p0 && qst::PoolSlotOf(h, ps)) {
    uintptr_t pool = p0 + (ps.neg ? qst::kNegPoolDelta : 0);
    uintptr_t chunk = RdP(pool + 8ull * ps.chunk);
    if (chunk) {
      uintptr_t e = chunk + ps.entry;
      uintptr_t str = RdP(e); int32_t len = RdT<int32_t>(e + 8);
      if (str && len > 0 && len <= 256) {
        wchar_t buf[257] = {};
        if (Rd(str, buf, size_t(len) * sizeof(wchar_t))) {
          bool good = true; std::string tmp;
          for (int k = 0; k < len && buf[k]; ++k) { if (buf[k] > 0x7e) { good = false; break; } tmp += (char)buf[k]; }
          if (good) r = tmp;
        }
      }
    }
  }
  if (!r.empty()) { std::lock_guard<std::mutex> l(m); memo[h] = r; }
  out = r; return !r.empty();
}

static bool QRead(std::vector<qst::Quest>& qs, std::string& err, bool check = true) {
  uintptr_t g = QSmGlobal(); uintptr_t sm = g ? RdP(g) : 0;
  if (!sm) { err = "ScenarioManager not found"; return false; }
  if (!qst::ReadAll(QRdFn, sm, QL, qs, err)) return false;
  if (check) { std::string why; if (!qst::Sane(qs, QSid, why)) { err = "quest layout check failed: " + why; return false; } }
  return true;
}

static void QuestTick() {
  if (!g_qtap) return;
  uint64_t now = GetTickCount64();
  if (now - g_qlast < 200) return;
  g_qlast = now;
  std::vector<qst::Quest> cur; std::string err;
  if (!QRead(cur, err)) return;
  std::lock_guard<std::mutex> l(g_qm);
  if (g_qprevOk) {
    uint64_t s0 = g_qring.Seq();
    qst::Diff(g_qprev, cur, QSid, g_qring, now);
    for (auto& e : g_qring.Since(s0)) api->log("qev %llu %s %s %s", (unsigned long long)e.ms, e.kind.c_str(), e.guid.c_str(), e.sid.c_str());
  }
  g_qprev.swap(cur); g_qprevOk = true;
}

static std::string QStateLine(const std::vector<qst::Quest>& qs, const std::string& sid) {
  qst::NodeInfo n = qst::NodeState(qs, QSid, sid);
  if (n.state == "none") return sid + ": none";
  std::string s = sid + ": " + n.state + " (quest " + n.quest + ": " + std::to_string(n.active) + " active, " + std::to_string(n.finished) + " finished";
  if (n.obj) { std::string c = ClassOf((uintptr_t)n.obj); s += Fmt("; obj 0x%llx %s", (unsigned long long)n.obj, c.empty() ? "?" : c.c_str()); }
  return s + ")";
}

static void CmdQuestState(const std::string& sid, Out& o) {
  std::vector<qst::Quest> qs; std::string err;
  if (!QRead(qs, err)) { o.line("error: " + err); return; }
  const qst::Quest* q = qst::FindQuest(qs, QSid, sid);
  qst::NodeInfo n = qst::NodeState(qs, QSid, sid);
  if (n.state == "none" && q) {
    o.f("%s: quest, %zu active, %zu finished", sid.c_str(), q->active.size(), q->done.size());
    for (auto& a : q->active) {
      std::string ns; QSid(a.h, ns); std::string cls = ClassOf((uintptr_t)a.obj);
      o.f("  active %s obj=0x%llx %s", ns.c_str(), (unsigned long long)a.obj, cls.empty() ? "?" : cls.c_str());
    }
    return;
  }
  o.line(QStateLine(qs, sid));
}

static void CmdQuestList(const std::vector<std::string>& t, Out& o) {
  uopt::Args ao = uopt::Parse(t, 2); std::string f = Lower(ao.Str("filter"));
  std::vector<qst::Quest> qs; std::string err;
  if (!QRead(qs, err)) { o.line("error: " + err); return; }
  int shown = 0;
  for (auto& q : qs) {
    std::string s; QSid(q.h, s); if (s.empty()) continue;
    if (!f.empty() && Lower(s).find(f) == std::string::npos) continue;
    o.f("%s active=%zu finished=%zu", s.c_str(), q.active.size(), q.done.size()); shown++;
  }
  o.f("%d of %zu quests", shown, qs.size());
}

static void CmdQuestLayout(Out& o) {
  uintptr_t g = QSmGlobal(), p = QPool();
  o.f("sm global %s rva 0x%llx", g ? "found" : "NOT FOUND", (unsigned long long)(g ? g - api->base : 0));
  o.f("build-specific: arr +0x%x num +0x%x stride 0x%x sid +0x%x | active +0x%x num +0x%x stride 0x%x obj +0x%x | done +0x%x num +0x%x stride 0x%x | name pool rva 0x%llx (+0x%llx)", QL.arr, QL.num, QL.stride, QL.sid, QL.act, QL.actNum, QL.actStride, QL.actObj, QL.done, QL.doneNum, QL.doneStride, (unsigned long long)(p ? p - api->base : 0), (unsigned long long)qst::kNegPoolDelta);
  std::vector<qst::Quest> qs; std::string err;
  if (!QRead(qs, err)) { o.line("sanity: FAIL " + err); return; }
  size_t act = 0, dn = 0; for (auto& q : qs) { act += q.active.size(); dn += q.done.size(); }
  o.f("sanity: ok, %zu quests, %zu active nodes, %zu finished nodes", qs.size(), act, dn);
  size_t tot = 0, res = 0, ntot = 0, nres = 0; int shown = 0;
  auto probe = [&](uint32_t h) {
    if (h == 0xffffffffu) return;
    std::string s; bool ok = QSid(h, s); tot++; res += ok;
    if ((int32_t)h < 0) { ntot++; nres += ok; }
    if (!ok && shown < 3) { shown++; o.f("unresolved handle 0x%x", h); }
  };
  for (auto& q : qs) { probe(q.h); for (auto& a : q.active) probe(a.h); for (uint32_t h : q.done) probe(h); }
  o.f("handles: %zu resolved of %zu; negative pool %zu of %zu", res, tot, nres, ntot);
}

static void CmdQuestTap(const std::vector<std::string>& t, Out& o) {
  std::string v = t.size() > 2 ? Lower(t[2]) : "";
  uopt::Args ao = uopt::Parse(t, 3);
  if (v == "on") {
    std::vector<qst::Quest> qs; std::string err;
    if (!QRead(qs, err)) { o.line("error: " + err); return; }
    { std::lock_guard<std::mutex> l(g_qm); g_qprev.swap(qs); g_qprevOk = true; g_qlast = 0; g_qtap = true; }
    o.f("quest tap on, mark %llu", (unsigned long long)g_qring.Seq()); return;
  }
  if (v == "off") { g_qtap = false; o.f("quest tap off, mark %llu", (unsigned long long)g_qring.Seq()); return; }
  if (v == "clear") { g_qring.Clear(); o.line("quest tap cleared"); return; }
  if (v == "show") {
    auto ev = g_qring.Since((uint64_t)ao.Int("since", 0), ao.Str("sid"), (size_t)ao.Int("max", 200));
    for (auto& e : ev) o.f("qev %llu %s %s %s (#%llu)", (unsigned long long)e.ms, e.kind.c_str(), e.guid.c_str(), e.sid.c_str(), (unsigned long long)e.seq);
    o.f("%zu events, mark %llu", ev.size(), (unsigned long long)g_qring.Seq()); return;
  }
  o.line("usage: quest tap on|off|clear|show [since=<mark>] [sid=<substr>] [max=N]");
}

static void CmdQuestMove(const std::string& verb, const std::string& sid, Out& o) {
  std::vector<qst::Quest> qs; std::string err;
  if (!QRead(qs, err)) { o.line("error: " + err); return; }
  o.line("before " + QStateLine(qs, sid));
  std::string f = Cmd("find class:CustomConsoleManagerAA 5 nodef");
  uintptr_t mgr = f.rfind("0x", 0) == 0 ? (uintptr_t)strtoull(f.c_str(), nullptr, 16) : 0;
  if (!mgr) { o.line("error: CustomConsoleManagerAA instance not found"); return; }
  char b[4096];
  if (api->call(mgr, verb == "end" ? "XEndQuestNodeBySID" : "XStartQuestNodeBySID", sid.c_str(), b, sizeof b) != 1) { o.line(std::string("error: ") + b); return; }
  std::vector<qst::Quest> after;
  if (!QRead(after, err)) { o.line("error: " + err); return; }
  o.line("after  " + QStateLine(after, sid));
}

static void CmdQuest(const std::vector<std::string>& t, Out& o) {
  std::string v = t.size() > 1 ? Lower(t[1]) : "";
  if (v == "list") { CmdQuestList(t, o); return; }
  if (v == "layout") { CmdQuestLayout(o); return; }
  if (v == "tap") { CmdQuestTap(t, o); return; }
  if ((v == "state" || v == "end" || v == "start") && t.size() > 2) {
    if (v == "state") CmdQuestState(t[2], o); else CmdQuestMove(v, t[2], o);
    return;
  }
  o.line("usage: quest list [filter=<substr>] | state <QuestSID|NodeSID> | tap on|off|clear|show [since=<mark>] [sid=<substr>] | end <NodeSID> | start <NodeSID> | layout");
}

UE_EXPORT int UEPluginInit(const UEApi* a) {
  api = a;
  if (a->version < 2) return 0;
  char exe[MAX_PATH] = {}; GetModuleFileNameA(nullptr, exe, MAX_PATH);
  g_s2 = Lower(exe).find("stalker2") != std::string::npos;
  if (!g_s2) { api->log("anomaly-scanner idle: not S.T.A.L.K.E.R. 2 (%s)", exe); return 1; }
  g_nbot = NbotInit(a) == 1;
  api->log("anomaly-scanner on (nbot %s)", g_nbot ? "loaded" : "failed");
  return 1;
}
UE_EXPORT void UEPluginTick() { if (!g_s2) return; QuestTick(); if (g_nbot) NbotTick(); }
UE_EXPORT void UEPluginShutdown() { if (g_nbot) NbotShutdown(); g_nbot = false; }
UE_EXPORT const char* UEPluginHelp() { return "quest list|state|tap|end|start|layout, npcs [near=] [r=] [class=] [uid=] [new=] [max=] [all], uid <obj>"; }
UE_EXPORT int UEPluginCommand(const char* line, char* out, int n) {
  std::vector<std::string> t = Split(line); if (t.empty()) return 0;
  std::string c = Lower(t[0]);
  if (c != "quest" && c != "npcs" && c != "uid") return 0;
  Out o;
  if (!g_s2) o.line("error: " + c + " needs S.T.A.L.K.E.R. 2 (anomaly-scanner plugin is idle in this game)");
  else if (c == "quest") CmdQuest(t, o);
  else if (c == "npcs") CmdNpcs(t, o);
  else CmdUid(t, o);
  strncpy_s(out, n, o.s.c_str(), _TRUNCATE);
  return 1;
}
UE_EXPORT uintptr_t UEPluginPreCall() { if (!g_s2) return 0; s2n_pf::g_on = 1; return s2n_pf::save(); }
UE_EXPORT void UEPluginCallFault(uintptr_t v) { if (g_s2) s2n_pf::fix(v); }
