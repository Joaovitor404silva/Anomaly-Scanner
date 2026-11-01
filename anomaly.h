#pragma once
#include <windows.h>
#include <string>
#include "crawler_api.h"

const UEApi* AnApi();

inline std::string S2Env(const char* key, const std::string& def) {
  char b[MAX_PATH];
  DWORD n = GetEnvironmentVariableA(key, b, sizeof b);
  return n && n < sizeof b ? std::string(b) : def;
}
inline std::string S2Path(const char* rel) { char b[MAX_PATH * 2]; return AnApi()->path(rel, b, sizeof b); }
inline std::string BenchPath(const char* rel) { std::string b = S2Env("ANOMALY_BENCH", S2Path("bench")); if (!b.empty() && b.back() != '\\') b += '\\'; return b + rel; }
inline uintptr_t SigFind(uintptr_t, const char* pat, int rip = -1) { return AnApi()->sig(pat, rip); }

int NbotInit(const UEApi* a);
void NbotTick();
void NbotShutdown();
