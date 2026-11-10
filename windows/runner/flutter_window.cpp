#include "flutter_window.h"

#include <endpointvolume.h>
#include <mmdeviceapi.h>

#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

bool g_microphone_muted_by_app = false;
bool g_microphone_previous_mute = false;

HRESULT GetDefaultCaptureVolume(IAudioEndpointVolume** volume) {
  *volume = nullptr;

  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
      __uuidof(IMMDeviceEnumerator),
      reinterpret_cast<void**>(&enumerator));
  if (FAILED(hr)) {
    return hr;
  }

  IMMDevice* device = nullptr;
  hr = enumerator->GetDefaultAudioEndpoint(eCapture, eCommunications, &device);
  if (FAILED(hr)) {
    hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
  }

  if (SUCCEEDED(hr)) {
    hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                          reinterpret_cast<void**>(volume));
    device->Release();
  }
  enumerator->Release();
  return hr;
}

void RestoreMicrophoneIfMutedByApp() {
  if (!g_microphone_muted_by_app) {
    return;
  }

  const HRESULT com_result =
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool com_initialized = SUCCEEDED(com_result);
  if (com_initialized || com_result == RPC_E_CHANGED_MODE) {
    IAudioEndpointVolume* volume = nullptr;
    if (SUCCEEDED(GetDefaultCaptureVolume(&volume)) && volume != nullptr) {
      volume->SetMute(g_microphone_previous_mute, nullptr);
      volume->Release();
    }
  }
  if (com_initialized) {
    CoUninitialize();
  }
  g_microphone_muted_by_app = false;
}

}  // namespace

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

  microphone_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "audrix/microphone",
          &flutter::StandardMethodCodec::GetInstance());
  microphone_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HandleMicrophoneCall(call, std::move(result));
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
  RestoreMicrophoneIfMutedByApp();
  microphone_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleMicrophoneCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "getMute" && call.method_name() != "setMute") {
    result->NotImplemented();
    return;
  }

  const HRESULT com_result =
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool com_initialized = SUCCEEDED(com_result);
  if (!com_initialized && com_result != RPC_E_CHANGED_MODE) {
    result->Error("mic_error", "COM initialization failed");
    return;
  }

  bool handled = false;
  IAudioEndpointVolume* volume = nullptr;
  if (SUCCEEDED(GetDefaultCaptureVolume(&volume)) && volume != nullptr) {
    if (call.method_name() == "getMute") {
      BOOL muted = FALSE;
      if (SUCCEEDED(volume->GetMute(&muted))) {
        result->Success(flutter::EncodableValue(muted != FALSE));
        handled = true;
      }
    } else {
      const bool* muted = std::get_if<bool>(call.arguments());
      if (muted != nullptr) {
        if (*muted) {
          if (!g_microphone_muted_by_app) {
            BOOL previous = FALSE;
            if (SUCCEEDED(volume->GetMute(&previous))) {
              g_microphone_previous_mute = previous != FALSE;
            }
          }
          if (SUCCEEDED(volume->SetMute(TRUE, nullptr))) {
            g_microphone_muted_by_app = true;
            handled = true;
          }
        } else if (SUCCEEDED(volume->SetMute(FALSE, nullptr))) {
          g_microphone_muted_by_app = false;
          handled = true;
        }
      }
    }
    volume->Release();
  }

  if (!handled) {
    result->Error("mic_error", "Unable to access the default microphone");
  }

  if (com_initialized) {
    CoUninitialize();
  }
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
