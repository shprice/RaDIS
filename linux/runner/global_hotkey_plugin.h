#ifndef RUNNER_GLOBAL_HOTKEY_PLUGIN_H_
#define RUNNER_GLOBAL_HOTKEY_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

// Registers the dis_radio/global_hotkeys MethodChannel and installs an
// XGrabKey hook on the root X11 window so key events arrive even when the
// application window does not have focus.
//
// Call global_hotkey_plugin_register() once after fl_register_plugins().
void global_hotkey_plugin_register(FlPluginRegistry* registry);

#endif  // RUNNER_GLOBAL_HOTKEY_PLUGIN_H_
