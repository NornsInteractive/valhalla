#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <sddl.h>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {
// User-scoped names are shared by Store, installed and portable editions.
class SingleInstance {
 public:
  ~SingleInstance() {
    if (owned_) ReleaseMutex(mutex_);
    if (mutex_) CloseHandle(mutex_);
    if (activate_) CloseHandle(activate_);
  }

  bool Initialize() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
    DWORD length = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &length);
    std::vector<BYTE> buffer(length);
    const BOOL ok = GetTokenInformation(token, TokenUser, buffer.data(), length, &length);
    CloseHandle(token);
    if (!ok) return false;
    LPWSTR sid = nullptr;
    if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &sid)) return false;
    const std::wstring prefix = std::wstring(L"Local\\Norns.Valhalla.") + sid;
    LocalFree(sid);
    // Auto-reset event retains an activation request during engine startup.
    activate_ = CreateEventW(nullptr, FALSE, FALSE, (prefix + L".activate").c_str());
    mutex_ = CreateMutexW(nullptr, FALSE, (prefix + L".instance").c_str());
    if (!activate_ || !mutex_) return false;
    const DWORD result = WaitForSingleObject(mutex_, 0);
    owned_ = result == WAIT_OBJECT_0 || result == WAIT_ABANDONED;
    if (!owned_ && result != WAIT_TIMEOUT) return false;
    if (!owned_) {
      const HWND existing = FindWindowW(L"NORNS_VALHALLA_WIN32_WINDOW", nullptr);
      DWORD owner = 0;
      if (existing) GetWindowThreadProcessId(existing, &owner);
      if (owner) AllowSetForegroundWindow(owner);
      SetEvent(activate_);
    }
    return true;
  }
  bool owns_instance() const { return owned_; }
  HANDLE activation_event() const { return activate_; }

 private:
  HANDLE mutex_ = nullptr;
  HANDLE activate_ = nullptr;
  bool owned_ = false;
};
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  SingleInstance singleton;
  if (!singleton.Initialize()) return EXIT_FAILURE;
  if (!singleton.owns_instance()) return EXIT_SUCCESS;
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Valhalla", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  const HANDLE activate = singleton.activation_event();
  bool running = true;
  while (running) {
    const DWORD result = MsgWaitForMultipleObjects(1, &activate, FALSE, INFINITE, QS_ALLINPUT);
    if (result == WAIT_OBJECT_0) {
      const HWND hwnd = window.GetHandle();
      ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
      SetForegroundWindow(hwnd);
    } else if (result == WAIT_OBJECT_0 + 1) {
      MSG msg;
      while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) { running = false; break; }
        TranslateMessage(&msg);
        DispatchMessage(&msg);
      }
    } else {
      running = false;
    }
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
