
#include "flutter_window.h"

#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr int kResizeCornerSize = 16;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(
    HWND hwnd,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {

  // Handle corner resizing BEFORE Flutter receives the message.
  if (message == WM_NCHITTEST) {
    RECT rect;

    if (GetWindowRect(hwnd, &rect)) {
      const int mouseX = GET_X_LPARAM(lparam);
      const int mouseY = GET_Y_LPARAM(lparam);

      const bool nearLeft =
          mouseX < rect.left + kResizeCornerSize;

      const bool nearRight =
          mouseX >= rect.right - kResizeCornerSize;

      const bool nearTop =
          mouseY < rect.top + kResizeCornerSize;

      const bool nearBottom =
          mouseY >= rect.bottom - kResizeCornerSize;

      if (nearLeft && nearTop) {
        return HTTOPLEFT;
      }

      if (nearRight && nearTop) {
        return HTTOPRIGHT;
      }

      if (nearLeft && nearBottom) {
        return HTBOTTOMLEFT;
      }

      if (nearRight && nearBottom) {
        return HTBOTTOMRIGHT;
      }

      // All other edges remain non-resizable.
      if (nearLeft || nearRight || nearTop || nearBottom) {
        return HTCLIENT;
      }
    }
  }

  // Give Flutter an opportunity to handle remaining messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(
            hwnd, message, wparam, lparam);

    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(
      hwnd, message, wparam, lparam);
}
