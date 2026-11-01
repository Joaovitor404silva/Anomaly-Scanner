#include "../opts.h"
#include "../quest.h"
#include <map>
#include <stdio.h>
#include <string.h>

static int g_fail, g_pass;
#define CHECK(c) do { if (c) g_pass++; else { g_fail++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

static void TestUopt() {
  auto a = uopt::Parse({ "find", "isa:X", "10", "near=1,2,3", "r=300", "loc", "new=2" }, 2);
  CHECK(a.pos.size() == 1 && a.pos[0] == "10" && a.Str("near") == "1,2,3" && a.Int("r", 0) == 300 && a.Flag("loc") && a.Int("new", 0) == 2 && !a.Has("hidden"));
  double v[3]; CHECK(uopt::ParseXyz("1,2.5,-3", v) && v[0] == 1 && v[1] == 2.5 && v[2] == -3);
  CHECK(!uopt::ParseXyz("pawn", v) && !uopt::ParseXyz("1,2", v) && !uopt::ParseXyz("1,2,3,4", v));
  double p[3] = { 0, 0, 0 }, q[3] = { 3, 4, 0 }; CHECK(uopt::Dist(p, q) == 5.0);
  std::vector<uopt::Row> rows(3); rows[0].idx = 5; rows[0].dist = 30; rows[1].idx = 9; rows[1].dist = 10; rows[2].idx = 7; rows[2].dist = 20;
  auto byDist = rows; uopt::SelectRows(byDist, true, 0); CHECK(byDist[0].dist == 10 && byDist[2].dist == 30);
  auto byNew = rows; uopt::SelectRows(byNew, false, 2); CHECK(byNew.size() == 2 && byNew[0].idx == 9 && byNew[1].idx == 7);
}
static void TestQring() {
  qr::Ring r(4);
  for (int i = 1; i <= 6; i++) { qr::Ev e; e.sid = i % 2 ? "Bar_" + std::to_string(i) : "Tech_" + std::to_string(i); e.kind = "end"; r.Push(e); }
  CHECK(r.Seq() == 6);
  auto all = r.Since(0);
  CHECK(all.size() == 4 && all[0].seq == 3 && all[3].seq == 6);
  auto bar = r.Since(0, "Bar");
  CHECK(bar.size() == 2 && bar[0].seq == 3 && bar[1].seq == 5);
  CHECK(r.Since(5).size() == 1);
  CHECK(r.Since(6).empty());
  auto lim = r.Since(0, "", 2);
  CHECK(lim.size() == 2 && lim[1].seq == 6);
  r.Clear(); CHECK(r.Seq() == 0 && r.Since(0).empty());
}

static void TestQuest() {
  std::vector<uint8_t> mem(0x6000, 0);
  auto put = [&](uint64_t off, const void* p, size_t n) { memcpy(&mem[off], p, n); };
  uint64_t sm = 0x100, arr = 0x2000, act0 = 0x3000, done0 = 0x4000, done1 = 0x4400; int32_t nq = 2;
  put(sm + 0x340, &arr, 8); put(sm + 0x350, &nq, 4);
  uint32_t h0 = 11, h1 = 12; put(arr, &h0, 4); put(arr + 0x118, &h1, 4);
  int32_t an = 2; put(arr + 0x10, &act0, 8); put(arr + 0x18, &an, 4);
  uint32_t a0 = 21, a1 = 22; uint64_t o0 = 0xabc0, o1 = 0xabc8; put(act0, &a0, 4); put(act0 + 8, &o0, 8); put(act0 + 0x18, &a1, 4); put(act0 + 0x18 + 8, &o1, 8);
  int32_t dn = 3; put(arr + 0xb0, &done0, 8); put(arr + 0xb8, &dn, 4);
  uint32_t d[3] = { 31, 32, 33 }; for (int i = 0; i < 3; i++) put(done0 + i * 0xc, &d[i], 4);
  int32_t dn1 = 1; put(arr + 0x118 + 0xb0, &done1, 8); put(arr + 0x118 + 0xb8, &dn1, 4); uint32_t dd = 41; put(done1, &dd, 4);
  cnt::ReadFn rd = [&](uint64_t a, void* o, size_t n) { if (a == 0 || a + n > mem.size()) return false; memcpy(o, &mem[a], n); return true; };
  std::map<uint32_t, std::string> nm = { {11, "E02_MQ03"}, {12, "E01_MQ01"}, {21, "E02_MQ03_Bar"}, {22, "E02_MQ03_Door"}, {31, "E02_MQ03_A"}, {32, "E02_MQ03_B"}, {33, "E02_MQ03_C"}, {41, "E01_MQ01_X"} };
  qst::SidFn sid = [&](uint32_t h, std::string& s) { auto it = nm.find(h); if (it == nm.end()) return false; s = it->second; return true; };
  std::vector<qst::Quest> qs; std::string err;
  CHECK(qst::ReadAll(rd, sm, qst::QLayout(), qs, err));
  CHECK(qs.size() == 2 && qs[0].active.size() == 2 && qs[0].done.size() == 3 && qs[1].done.size() == 1 && qs[0].active[1].obj == 0xabc8);
  std::string why; CHECK(qst::Sane(qs, sid, why));
  auto n1 = qst::NodeState(qs, sid, "E02_MQ03_Bar"); CHECK(n1.state == "active" && n1.quest == "E02_MQ03" && n1.obj == 0xabc0 && n1.active == 2 && n1.finished == 3);
  auto n2 = qst::NodeState(qs, sid, "E01_MQ01_X"); CHECK(n2.state == "finished" && n2.quest == "E01_MQ01");
  CHECK(qst::NodeState(qs, sid, "Nope").state == "none");
  CHECK(qst::FindQuest(qs, sid, "E01_MQ01") == &qs[1] && !qst::FindQuest(qs, sid, "Nope"));
  std::map<uint32_t, std::string> bad; nm.swap(bad); CHECK(!qst::Sane(qs, sid, why)); nm.swap(bad);
  int32_t zero = 0; put(sm + 0x350, &zero, 4); CHECK(!qst::ReadAll(rd, sm, qst::QLayout(), qs, err));
  put(sm + 0x350, &nq, 4); CHECK(qst::ReadAll(rd, sm, qst::QLayout(), qs, err));
  std::vector<qst::Quest> before = qs, after = qs;
  after[0].active.erase(after[0].active.begin()); after[0].done.push_back(21); after[1].active.push_back({ 22, 0x1 });
  qr::Ring ring(16);
  CHECK(qst::Diff(before, after, sid, ring, 5) == 3);
  auto ev = ring.Since(0);
  CHECK(ev.size() == 3 && ev[0].kind == "end" && ev[0].sid == "E02_MQ03_Bar" && ev[1].kind == "done" && ev[1].sid == "E02_MQ03_Bar" && ev[2].kind == "start" && ev[2].guid == "E01_MQ01");
  CHECK(qst::Diff(after, after, sid, ring, 6) == 0);
}
static void TestQuestPool() {
  qst::PoolSlot s;
  CHECK(qst::PoolSlotOf(0xd720, s) && !s.neg && s.chunk == 53 && s.entry == 0x6400);
  CHECK(qst::PoolSlotOf((uint32_t)-1, s) && s.neg && s.chunk == 0 && s.entry == 0);
  CHECK(qst::PoolSlotOf((uint32_t)-1026, s) && s.neg && s.chunk == 1 && s.entry == (1u << 5));
  CHECK(!qst::PoolSlotOf(0, s));
  CHECK(qst::kNegPoolDelta == 0x20090);
}

int main() {
  TestUopt(); TestQring(); TestQuest(); TestQuestPool();
  printf("quest: %d pass, %d fail\n", g_pass, g_fail);
  return g_fail ? 1 : 0;
}
