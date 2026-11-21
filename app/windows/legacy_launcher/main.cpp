// Starts the app beside this file with this file's arguments, and ends once the app's window is up: an older
// install's updater keeps its update window open as long as the program it started (rfc/054).
#include <windows.h>

#include <string>

int APIENTRY wWinMain(_In_ HINSTANCE, _In_opt_ HINSTANCE, _In_ wchar_t*, _In_ int) {
  std::wstring self(MAX_PATH, L'\0');
  DWORD length;
  while ((length = GetModuleFileNameW(nullptr, self.data(), static_cast<DWORD>(self.size()))) == self.size()) {
    self.resize(self.size() * 2);
  }
  if (length == 0) return 1;
  self.resize(length);
  const std::wstring folder = self.substr(0, self.find_last_of(L'\\') + 1);
  const std::wstring app = folder + APP_EXE;

  // The arguments after this program's own name, as they were given.
  const wchar_t* rest = GetCommandLineW();
  for (bool quoted = false; *rest && (quoted || (*rest != L' ' && *rest != L'\t')); ++rest) {
    if (*rest == L'"') quoted = !quoted;
  }
  std::wstring command = L"\"" + app + L"\"" + rest;

  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  // The lawyer asked for this window: it may come to the front.
  AllowSetForegroundWindow(ASFW_ANY);
  if (!CreateProcessW(app.c_str(), command.data(), nullptr, nullptr, FALSE, 0, nullptr, folder.c_str(), &startup,
                      &process)) {
    return 1;
  }
  WaitForInputIdle(process.hProcess, 30000);
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return 0;
}
