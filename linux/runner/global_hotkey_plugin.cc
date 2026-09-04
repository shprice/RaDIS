#include "global_hotkey_plugin.h"

#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#include <X11/Xlib.h>
#endif

#include <pthread.h>
#include <unistd.h>

#include <cstdint>
#include <cstring>

// ---------------------------------------------------------------------------
// Scan-code (evdev = PS/2 scan code set 1) → USB HID keyboard-page usage.
// For standard keys the evdev code equals the Windows scan code, so a single
// table covers both platforms.  Extended keys (arrows, nav cluster, etc.) use
// different evdev codes and are handled by the switch below.
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

// evdev codes that differ from the PS/2 scan codes (nav cluster, etc.)
static uint8_t EvdevExtendedToHid(int evdev) {
  switch (evdev) {
    case  96: return 0x58;  // Numpad Enter
    case  97: return 0xE4;  // Right Ctrl
    case  98: return 0x54;  // Numpad /
    case  99: return 0x46;  // Print Screen / SysRq
    case 100: return 0xE6;  // Right Alt
    case 102: return 0x4A;  // Home
    case 103: return 0x52;  // Arrow Up
    case 104: return 0x4B;  // Page Up
    case 105: return 0x50;  // Arrow Left
    case 106: return 0x4F;  // Arrow Right
    case 107: return 0x4D;  // End
    case 108: return 0x51;  // Arrow Down
    case 109: return 0x4E;  // Page Down
    case 110: return 0x49;  // Insert
    case 111: return 0x4C;  // Delete
    case 125: return 0xE3;  // Left GUI
    case 126: return 0xE7;  // Right GUI
    case 127: return 0x65;  // Application / Menu
    default:  return 0x00;
  }
}

// X11 keycode (= evdev + 8) → USB HID usage (0x00070000 | hid_byte), or 0.
static uint32_t X11KeycodeToUsbHid(int keycode) {
  int evdev = keycode - 8;
  if (evdev < 0) return 0;
  uint8_t hid = 0;
  if (evdev < 128) hid = kScanToHid[evdev];
  if (!hid) hid = EvdevExtendedToHid(evdev);
  return hid ? (0x00070000u | hid) : 0u;
}

// Reverse: USB HID usage → evdev code (-1 if unknown).
static int UsbHidToEvdev(uint32_t usb_hid) {
  if ((usb_hid >> 16) != 0x0007) return -1;
  uint8_t hid = static_cast<uint8_t>(usb_hid & 0xFF);
  // Check extended evdev keys first (they shadow scan-code table entries).
  const int kExtended[][2] = {
      {96, 0x58}, {97, 0xE4}, {98, 0x54}, {99, 0x46},  {100, 0xE6},
      {102, 0x4A}, {103, 0x52}, {104, 0x4B}, {105, 0x50}, {106, 0x4F},
      {107, 0x4D}, {108, 0x51}, {109, 0x4E}, {110, 0x49}, {111, 0x4C},
      {125, 0xE3}, {126, 0xE7}, {127, 0x65},
  };
  for (auto& pair : kExtended) {
    if (pair[1] == hid) return pair[0];
  }
  for (int sc = 0; sc < 128; sc++) {
    if (kScanToHid[sc] == hid) return sc;
  }
  return -1;
}

// ---------------------------------------------------------------------------

#ifdef GDK_WINDOWING_X11

// Convert X11 state mask → our modifier bitmask (1=Ctrl,2=Shift,4=Alt,8=Meta).
// Ignores Lock, Num Lock and other Mod masks that vary by X configuration.
static int32_t X11StateToModifiers(unsigned int state) {
  int32_t mods = 0;
  if (state & ControlMask) mods |= 1;
  if (state & ShiftMask)   mods |= 2;
  if (state & Mod1Mask)    mods |= 4;  // Alt (Mod1 is standard Alt on Linux)
  if (state & Mod4Mask)    mods |= 8;  // Super/Meta (Mod4 is standard on most DEs)
  return mods;
}

struct KeyEventDispatch {
  FlMethodChannel* channel;
  int32_t hid_code;
  gboolean is_down;
  int32_t modifiers;
};

// Dispatched on the GLib main loop so fl_method_channel_invoke_method is
// called from the correct thread.
static gboolean DispatchKeyEvent(gpointer data) {
  auto* ev = static_cast<KeyEventDispatch*>(data);
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "hidCode",    fl_value_new_int(ev->hid_code));
  fl_value_set_string_take(args, "isDown",     fl_value_new_bool(ev->is_down));
  fl_value_set_string_take(args, "modifiers",  fl_value_new_int(ev->modifiers));
  fl_method_channel_invoke_method(ev->channel, "onKey", args,
                                  nullptr, nullptr, nullptr);
  g_object_unref(ev->channel);
  g_free(ev);
  return G_SOURCE_REMOVE;
}

struct HookState {
  FlMethodChannel* channel;   // strong ref, released in cleanup
  Display* display;
  Window root;
  int stop_pipe[2];           // [0]=read, [1]=write
  pthread_t thread;
  bool running;
};

static HookState* g_state = nullptr;

static void* EventThreadFunc(void* arg) {
  auto* st = static_cast<HookState*>(arg);
  int x11_fd = ConnectionNumber(st->display);

  while (true) {
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(x11_fd, &fds);
    FD_SET(st->stop_pipe[0], &fds);
    int max_fd = (x11_fd > st->stop_pipe[0]) ? x11_fd : st->stop_pipe[0];
    select(max_fd + 1, &fds, nullptr, nullptr, nullptr);

    if (FD_ISSET(st->stop_pipe[0], &fds)) break;

    while (XPending(st->display)) {
      XEvent event;
      XNextEvent(st->display, &event);
      if (event.type == KeyPress || event.type == KeyRelease) {
        uint32_t usb_hid = X11KeycodeToUsbHid(event.xkey.keycode);
        if (usb_hid) {
          auto* ev = g_new(KeyEventDispatch, 1);
          ev->channel   = static_cast<FlMethodChannel*>(
              g_object_ref(st->channel));
          ev->hid_code  = static_cast<int32_t>(usb_hid);
          ev->is_down   = (event.type == KeyPress);
          ev->modifiers = X11StateToModifiers(event.xkey.state);
          g_idle_add(DispatchKeyEvent, ev);
        }
      }
    }
  }

  XUngrabKey(st->display, AnyKey, AnyModifier, st->root);
  XCloseDisplay(st->display);
  close(st->stop_pipe[0]);
  return nullptr;
}

static void StopHook() {
  if (!g_state) return;
  // Signal the event thread to exit via the pipe.
  char buf = 'x';
  write(g_state->stop_pipe[1], &buf, 1);
  close(g_state->stop_pipe[1]);
  pthread_join(g_state->thread, nullptr);
  g_object_unref(g_state->channel);
  g_free(g_state);
  g_state = nullptr;
}

static void StartHook(FlMethodChannel* channel,
                      FlValue* hid_codes_list) {
  StopHook();

  Display* display = XOpenDisplay(nullptr);
  if (!display) return;

  Window root = DefaultRootWindow(display);

  // Grab each requested key (AnyModifier = fire regardless of Shift etc.)
  if (hid_codes_list && fl_value_get_type(hid_codes_list) == FL_VALUE_TYPE_LIST) {
    size_t count = fl_value_get_length(hid_codes_list);
    for (size_t i = 0; i < count; i++) {
      FlValue* v = fl_value_get_list_value(hid_codes_list, i);
      int32_t usb_hid = static_cast<int32_t>(fl_value_get_int(v));
      int evdev = UsbHidToEvdev(static_cast<uint32_t>(usb_hid));
      if (evdev >= 0) {
        int keycode = evdev + 8;
        XGrabKey(display, keycode, AnyModifier, root,
                 False, GrabModeAsync, GrabModeAsync);
      }
    }
  }

  XSelectInput(display, root, KeyPressMask | KeyReleaseMask);
  XFlush(display);

  g_state = g_new0(HookState, 1);
  g_state->channel = static_cast<FlMethodChannel*>(g_object_ref(channel));
  g_state->display = display;
  g_state->root    = root;
  g_state->running = true;
  pipe(g_state->stop_pipe);

  pthread_create(&g_state->thread, nullptr, EventThreadFunc, g_state);
}

// ---------------------------------------------------------------------------

static void MethodCallHandler(FlMethodChannel*,
                               FlMethodCall* call,
                               gpointer user_data) {
  auto* channel = static_cast<FlMethodChannel*>(user_data);
  const gchar* method = fl_method_call_get_name(call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "start") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    FlValue* hid_list = nullptr;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      hid_list = fl_value_lookup_string(args, "hidCodes");
    }
    StartHook(channel, hid_list);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "stop") == 0) {
    StopHook();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(call, response, nullptr);
}

#endif  // GDK_WINDOWING_X11

// ---------------------------------------------------------------------------

void global_hotkey_plugin_register(FlPluginRegistry* registry) {
#ifdef GDK_WINDOWING_X11
  // Only install on X11; Wayland has no equivalent without portal APIs.
  GdkDisplay* gdk_display = gdk_display_get_default();
  if (!GDK_IS_X11_DISPLAY(gdk_display)) return;

  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "GlobalHotkeyPlugin");
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, "dis_radio/global_hotkeys", FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      channel, MethodCallHandler, channel, g_object_unref);
  // channel is now owned by the handler's destroy_notify (g_object_unref).
#endif
}
