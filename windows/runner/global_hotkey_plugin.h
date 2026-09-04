#ifndef RUNNER_GLOBAL_HOTKEY_PLUGIN_H_
#define RUNNER_GLOBAL_HOTKEY_PLUGIN_H_

#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

class GlobalHotkeyPlugin {
 public:
  explicit GlobalHotkeyPlugin(flutter::BinaryMessenger* messenger);
  ~GlobalHotkeyPlugin();

  // Non-copyable.
  GlobalHotkeyPlugin(const GlobalHotkeyPlugin&) = delete;
  GlobalHotkeyPlugin& operator=(const GlobalHotkeyPlugin&) = delete;

  // modifiers: bitmask (1=Ctrl, 2=Shift, 4=Alt, 8=Meta)
  void SendKeyEvent(uint32_t usb_hid, bool is_down, uint32_t modifiers);

 private:
  void HandleStart();
  void HandleStop();

  static LRESULT CALLBACK LowLevelKeyboardProc(int nCode,
                                                WPARAM wParam,
                                                LPARAM lParam);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HHOOK hook_ = nullptr;
  uint32_t modifier_state_ = 0;  // live modifier bitmask

  // Singleton pointer used by the static hook callback.
  static GlobalHotkeyPlugin* instance_;
};

#endif  // RUNNER_GLOBAL_HOTKEY_PLUGIN_H_
