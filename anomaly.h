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
inline uintptr_t SigFind(uintptr_t, const char* pat, int rip = -1) { return AnApi()->sig(pat, rip); }

int NbotInit(const UEApi* a);
void NbotTick();
void NbotShutdown();
