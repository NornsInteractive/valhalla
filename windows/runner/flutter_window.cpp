#include "flutter_window.h"

#include <optional>
#include <string>
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <appmodel.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  download_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "valhalla/downloads",
      &flutter::StandardMethodCodec::GetInstance());

  download_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("runtimeInfo") == 0) {
          UINT32 length = 0;
          bool from_store = false;
          if (GetCurrentPackageFullName(&length, nullptr) == ERROR_INSUFFICIENT_BUFFER && length > 0) {
            std::wstring full_name(length, L'\0');
            if (GetCurrentPackageFullName(&length, full_name.data()) == ERROR_SUCCESS) {
              using OriginQuery = LONG(WINAPI*)(PCWSTR, PackageOrigin*);
              const auto query = reinterpret_cast<OriginQuery>(GetProcAddress(
                  GetModuleHandleW(L"kernelbase.dll"), "GetStagedPackageOrigin"));
              PackageOrigin origin = PackageOrigin_Unknown;
              from_store = query && query(full_name.c_str(), &origin) == ERROR_SUCCESS &&
                           origin == PackageOrigin_Store;
            }
          }
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("storeInstall"), flutter::EncodableValue(from_store)},
          }));
        } else if (call.method_name().compare("revealFile") == 0) {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) { result->Error("INVALID_ARGUMENT", "args must be map"); return; }
          const auto it = args->find(flutter::EncodableValue("path"));
          if (it == args->end() || !std::holds_alternative<std::string>(it->second)) {
            result->Error("INVALID_ARGUMENT", "path required"); return;
          }
          const auto& path = std::get<std::string>(it->second);
          if (path.empty() || path.find('\0') != std::string::npos) {
            result->Error("INVALID_ARGUMENT", "invalid path"); return;
          }
          const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path.data(), static_cast<int>(path.size()), nullptr, 0);
          if (!length) { result->Error("INVALID_ARGUMENT", "invalid UTF-8"); return; }
          std::wstring wide(length, L'\0');
          MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path.data(), static_cast<int>(path.size()), wide.data(), length);
          for (auto& character : wide) if (character == L'/') character = L'\\';
          const DWORD attributes = GetFileAttributesW(wide.c_str());
          HRESULT hr = E_FAIL;
          if (attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY)) {
            PIDLIST_ABSOLUTE item = nullptr;
            hr = SHParseDisplayName(wide.c_str(), nullptr, &item, 0, nullptr);
            if (SUCCEEDED(hr)) {
              hr = SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
              CoTaskMemFree(item);
            }
          } else {
            const size_t separator = wide.find_last_of(L'\\');
            if (separator != std::wstring::npos) {
              const std::wstring parent = wide.substr(0, separator + 1);
              const DWORD parent_attributes = GetFileAttributesW(parent.c_str());
              if (parent_attributes != INVALID_FILE_ATTRIBUTES && (parent_attributes & FILE_ATTRIBUTE_DIRECTORY)) {
                const auto opened = reinterpret_cast<INT_PTR>(ShellExecuteW(GetHandle(), L"open", parent.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
                hr = opened > 32 ? S_OK : E_FAIL;
              }
            }
          }
          if (SUCCEEDED(hr)) result->Success();
          else result->Error("REVEAL_FAILED", "Could not show the download location");
        } else if (call.method_name().compare("openFile") == 0) {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGUMENT", "args must be map");
            return;
          }
          auto it = args->find(flutter::EncodableValue("path"));
          if (it == args->end() || !std::holds_alternative<std::string>(it->second)) {
            result->Error("INVALID_ARGUMENT", "path required");
            return;
          }
          const std::string& path = std::get<std::string>(it->second);
          int wlen = MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, nullptr, 0);
          std::wstring wpath(wlen, 0);
          MultiByteToWideChar(CP_UTF8, 0, path.c_str(), -1, &wpath[0], wlen);

          OPENASINFO oai = {};
          oai.pcszFile = wpath.c_str();
          oai.pcszClass = nullptr;
          oai.oaifInFlags = OAIF_EXEC;

          HRESULT hr = SHOpenWithDialog(GetHandle(), &oai);
          if (SUCCEEDED(hr) || hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success();
          } else {
            result->Error("OPEN_FAILED", "SHOpenWithDialog failed");
          }
        } else if (call.method_name().compare("reportProgress") == 0) {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          auto name_it = args->find(flutter::EncodableValue("name"));
          auto status_it = args->find(flutter::EncodableValue("status"));
          auto bytes_it = args->find(flutter::EncodableValue("bytes"));
          auto total_it = args->find(flutter::EncodableValue("total"));

          std::string name = (name_it != args->end() && std::holds_alternative<std::string>(name_it->second))
              ? std::get<std::string>(name_it->second) : "Download";
          std::string status = (status_it != args->end() && std::holds_alternative<std::string>(status_it->second))
              ? std::get<std::string>(status_it->second) : "running";

          auto path_it = args->find(flutter::EncodableValue("path"));
          if (path_it != args->end() && std::holds_alternative<std::string>(path_it->second)) {
            const std::string& p = std::get<std::string>(path_it->second);
            int wlen = MultiByteToWideChar(CP_UTF8, 0, p.c_str(), -1, nullptr, 0);
            last_download_path_.assign(wlen, 0);
            MultiByteToWideChar(CP_UTF8, 0, p.c_str(), -1, &last_download_path_[0], wlen);
            if (!last_download_path_.empty() && last_download_path_.back() == L'\0') {
              last_download_path_.pop_back();
            }
          } else {
            last_download_path_.clear();
          }
          last_download_completed_ = (status == "completed");

          int64_t bytes = 0;
          if (bytes_it != args->end()) {
            if (std::holds_alternative<int64_t>(bytes_it->second)) {
              bytes = std::get<int64_t>(bytes_it->second);
            } else if (std::holds_alternative<int32_t>(bytes_it->second)) {
              bytes = std::get<int32_t>(bytes_it->second);
            }
          }

          int64_t total = 0;
          if (total_it != args->end()) {
            if (std::holds_alternative<int64_t>(total_it->second)) {
              total = std::get<int64_t>(total_it->second);
            } else if (std::holds_alternative<int32_t>(total_it->second)) {
              total = std::get<int32_t>(total_it->second);
            }
          }

          NOTIFYICONDATAW nid = {};
          nid.cbSize = sizeof(nid);
          nid.hWnd = GetHandle();
          nid.uID = 1002;

          if (status == "canceled") {
            BOOL del_ok = Shell_NotifyIconW(NIM_DELETE, &nid);
            result->Success(flutter::EncodableValue(static_cast<bool>(del_ok)));
            return;
          }

          HICON hIcon = (HICON)::GetClassLongPtr(GetHandle(), GCLP_HICONSM);
          if (hIcon == nullptr) {
            hIcon = (HICON)::GetClassLongPtr(GetHandle(), GCLP_HICON);
          }
          if (hIcon == nullptr) {
            hIcon = ::LoadIcon(nullptr, IDI_APPLICATION);
          }

          nid.uFlags = NIF_INFO | NIF_ICON | NIF_TIP | NIF_MESSAGE;
          nid.uCallbackMessage = WM_APP + 42;
          nid.hIcon = hIcon;
          wcsncpy_s(nid.szTip, L"Valhalla", _TRUNCATE);
          nid.dwInfoFlags = NIIF_INFO;

          MultiByteToWideChar(CP_UTF8, 0, name.c_str(), -1, nid.szInfoTitle, ARRAYSIZE(nid.szInfoTitle));

          std::wstring text;
          if (status == "completed") {
            text = L"Download completed";
          } else if (status == "failed") {
            text = L"Download failed";
            nid.dwInfoFlags = NIIF_ERROR;
          } else if (status == "paused") {
            text = L"Download paused";
            nid.dwInfoFlags = NIIF_WARNING;
          } else if (status == "queued") {
            text = L"Queued";
          } else {
            if (total > 0) {
              int percent = static_cast<int>((bytes * 100) / total);
              if (percent < 0) percent = 0;
              if (percent > 100) percent = 100;
              wchar_t buf[64];
              swprintf_s(buf, ARRAYSIZE(buf), L"%d%% complete", percent);
              text = buf;
            } else {
              text = L"Downloading...";
            }
          }

          wcsncpy_s(nid.szInfo, text.c_str(), _TRUNCATE);

          BOOL ok = Shell_NotifyIconW(NIM_MODIFY, &nid);
          if (!ok) {
            ok = Shell_NotifyIconW(NIM_ADD, &nid);
          }

          result->Success(flutter::EncodableValue(static_cast<bool>(ok)));
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = GetHandle();
  nid.uID = 1002;
  Shell_NotifyIconW(NIM_DELETE, &nid);

  download_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_APP + 42: {
      UINT event = LOWORD(lparam);
      if (event == NIN_BALLOONUSERCLICK || event == WM_LBUTTONUP) {
        ::ShowWindow(GetHandle(), SW_RESTORE);
        ::SetForegroundWindow(GetHandle());
        if (last_download_completed_ && !last_download_path_.empty() &&
            GetFileAttributesW(last_download_path_.c_str()) != INVALID_FILE_ATTRIBUTES) {
          OPENASINFO oai = {};
          oai.pcszFile = last_download_path_.c_str();
          oai.pcszClass = nullptr;
          oai.oaifInFlags = OAIF_EXEC;
          SHOpenWithDialog(GetHandle(), &oai);
        } else if (download_channel_) {
          download_channel_->InvokeMethod("openTransfers", nullptr);
        }
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
