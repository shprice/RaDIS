#include "global_hotkey_plugin.h"

#include <flutter/encodable_value.h>

// ---------------------------------------------------------------------------
// Scan-code set 1 (non-extended) → USB HID keyboard-page usage code.
// Index = Windows scan code byte; value = HID usage (page 0x07).
// Extended keys are handled separately below.
// ---------------------------------------------------------------------------
static const uint8_t kScanToHid[128] = {
    0x00, 0x29, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23,  // 00-07
    0x24, 0x25, 0x26, 0x27, 0x2D, 0x2E, 0x2A, 0x2B,  // 08-0F
    0x14, 0x1A, 0x08, 0x15, 0x17, 0x1C, 0x18, 0x0C,  // 10-17
    0x12, 0x13, 0x2F, 0x30, 0x28, 0xE0, 0x04, 0x16,  // 18-1F
    0x07, 0x09, 0x0A, 0x0B, 0x0D, 0x0E, 0x0F, 0x33,  // 20-27
    0x34, 0x35, 0xE1, 0x31, 0x1D, 0x1B, 0x06, 0x19,  // 28-2F
    0x05, 0x11, 0x10, 0x36, 0x37, 0x38, 0xE5, 0x55,  // 30-37
    0xE2, 0x2C, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E,  // 38-3F
    0x3F, 0x40, 0x41, 0x42, 0x43, 0x53, 0x47, 0x5F,  // 40-47
    0x60, 0x61, 0x56, 0x5C, 0x5D, 0x5E, 0x57, 0x59,  // 48-4F
    0x5A, 0x5B, 0x62, 0x63, 0x00, 0x00, 0x64, 0x44,  // 50-57
    0x45, 0x67, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // 58-5F
    0x00, 0x00, 0x00, 0x00, 0x68, 0x69, 0x6A, 0x6B,  // 60-67
    0x6C, 0x6D, 0x6E, 0x6F, 0x00, 0x00, 0x00, 0x00,  // 68-6F
    0x88, 0x91, 0x90, 0x87, 0x00, 0x00, 0x00, 0x00,  // 70-77
    0x00, 0x8A, 0x00, 0x8B, 0x00, 0x89, 0x85, 0x00,  // 78-7F
};

static uint32_t ScanToUsbHid(uint8_t sc, bool extended) {
  uint8_t hid = 0;
  if (extended) {
    switch (sc) {
      case 0x1C: hid = 0x58; break;  // Numpad Enter
      case 0x1D: hid = 0xE4; break;  // Right Ctrl
      case 0x35: hid = 0x54; break;  // Numpad /
      case 0x37: hid = 0x46; break;  // Print Screen
      case 0x38: hid = 0xE6; break;  // Right Alt
      case 0x47: hid = 0x4A; break;  // Home
      case 0x48: hid = 0x52; break;  // Arrow Up
      case 0x49: hid = 0x4B; break;  // Page Up
      case 0x4B: hid = 0x50; break;  // Arrow Left
      case 0x4D: hid = 0x4F; break;  // Arrow Right
      case 0x4F: hid = 0x4D; break;  // End
      case 0x50: hid = 0x51; break;  // Arrow Down
      case 0x51: hid = 0x4E; break;  // Page Down
      case 0x52: hid = 0x49; break;  // Insert
      case 0x53: hid = 0x4C; break;  // Delete
      case 0x5B: hid = 0xE3; break;  // Left GUI
      case 0x5C: hid = 0xE7; break;  // Right GUI
      case 0x5D: hid = 0x65; break;  // Application/Menu
    }
  } else if (sc < 128) {
    hid = kScanToHid[sc];
  }
  return hid ? (0x00070000u | hid) : 0u;
}

// ---------------------------------------------------------------------------

GlobalHotkeyPlugin* GlobalHotkeyPlugin::instance_ = nullptr;

GlobalHotkeyPlugin::GlobalHotkeyPlugin(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger,
          "dis_radio/global_hotkeys",
          &flutter::StandardMethodCodec::GetInstance())) {
  instance_ = this;

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "start") {
          HandleStart();
          result->Success();
        } else if (call.method_name() == "stop") {
          HandleStop();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

GlobalHotkeyPlugin::~GlobalHotkeyPlugin() {
  HandleStop();
  if (instance_ == this) instance_ = nullptr;
}

void GlobalHotkeyPlugin::HandleStart() {
  if (!hook_) {
    hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                              nullptr, 0);
  }
}

void GlobalHotkeyPlugin::HandleStop() {
  if (hook_) {
    UnhookWindowsHookEx(hook_);
    hook_ = nullptr;
  }
}

void GlobalHotkeyPlugin::SendKeyEvent(uint32_t usb_hid, bool is_down,
                                      uint32_t modifiers) {
  flutter::EncodableMap args{
      {flutter::EncodableValue("hidCode"),
       flutter::EncodableValue(static_cast<int64_t>(usb_hid))},
      {flutter::EncodableValue("isDown"),
       flutter::EncodableValue(is_down)},
      {flutter::EncodableValue("modifiers"),
       flutter::EncodableValue(static_cast<int64_t>(modifiers))},
  };
  channel_->InvokeMethod(
      "onKey",
      std::make_unique<flutter::EncodableValue>(std::move(args)));
}

// USB HID codes for modifier keys → bitmask bit (1=Ctrl,2=Shift,4=Alt,8=Meta)
static uint32_t ModifierBit(uint32_t usb_hid) {
  switch (usb_hid) {
    case 0x000700E0: case 0x000700E4: return 1;  // Left/Right Ctrl
    case 0x000700E1: case 0x000700E5: return 2;  // Left/Right Shift
    case 0x000700E2: case 0x000700E6: return 4;  // Left/Right Alt
    case 0x000700E3: case 0x000700E7: return 8;  // Left/Right GUI
    default: return 0;
  }
}

// static
LRESULT CALLBACK GlobalHotkeyPlugin::LowLevelKeyboardProc(int nCode,
                                                            WPARAM wParam,
                                                            LPARAM lParam) {
  if (nCode == HC_ACTION && instance_) {
    auto* info = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    bool is_down = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
    bool is_up   = (wParam == WM_KEYUP   || wParam == WM_SYSKEYUP);
    if (is_down || is_up) {
      bool extended = (info->flags & LLKHF_EXTENDED) != 0;
      uint32_t usb_hid =
          ScanToUsbHid(static_cast<uint8_t>(info->scanCode), extended);
      if (!usb_hid) goto done;

      // Update internal modifier state tracking.
      uint32_t mod_bit = ModifierBit(usb_hid);
      if (mod_bit) {
        if (is_down) instance_->modifier_state_ |= mod_bit;
        else         instance_->modifier_state_ &= ~mod_bit;
        // Don't forward pure modifier events; they're only needed for state.
        goto done;
      }

      instance_->SendKeyEvent(usb_hid, is_down, instance_->modifier_state_);
    }
  }
done:
  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}
