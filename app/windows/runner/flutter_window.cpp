#include "flutter_window.h"
#include "credential_store.h"

#include <optional>

#include <wtsapi32.h>

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

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "paper_agent/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(HandleCredentialCall);
  WTSRegisterSessionNotification(GetHandle(), NOTIFY_FOR_THIS_SESSION);
  display_notification_ = RegisterPowerSettingNotification(
      GetHandle(), &GUID_CONSOLE_DISPLAY_STATE, DEVICE_NOTIFY_WINDOW_HANDLE);
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
  if (display_notification_) {
    UnregisterPowerSettingNotification(display_notification_);
    display_notification_ = nullptr;
  }
  WTSUnRegisterSessionNotification(GetHandle());
  window_channel_ = nullptr;
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
    case WM_WTSSESSION_CHANGE:
      if (wparam == WTS_SESSION_UNLOCK) NotifyVisible(hwnd, "unlock");
      if (wparam == WTS_CONSOLE_CONNECT || wparam == WTS_REMOTE_CONNECT) {
        NotifyVisible(hwnd, "session connected");
      }
      break;
    case WM_POWERBROADCAST:
      if (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND) {
        NotifyVisible(hwnd, "resume");
      }
      if (wparam == PBT_POWERSETTINGCHANGE) {
        auto setting = reinterpret_cast<const POWERBROADCAST_SETTING*>(lparam);
        // GUID_CONSOLE_DISPLAY_STATE: 0 off, 1 on, 2 dimmed.
        if (setting && setting->PowerSetting == GUID_CONSOLE_DISPLAY_STATE &&
            setting->DataLength >= sizeof(DWORD) &&
            *reinterpret_cast<const DWORD*>(setting->Data) == 1) {
          NotifyVisible(hwnd, "display on");
        }
      }
      break;
    case WM_DISPLAYCHANGE:
      NotifyVisible(hwnd, "display changed");
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::NotifyVisible(HWND hwnd, const char* reason) {
  // A minimised or hidden window is not back: Windows will say so when it is.
  if (!flutter_controller_ || !window_channel_ || IsIconic(hwnd) ||
      !IsWindowVisible(hwnd)) {
    return;
  }
  flutter_controller_->ForceRedraw();
  window_channel_->InvokeMethod(
      "visible", std::make_unique<flutter::EncodableValue>(reason));
}
