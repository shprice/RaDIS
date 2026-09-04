import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(1024, 768));
  await windowManager.setTitle('RaDIS');
  await windowManager.center();

  runApp(const DisRadioApp());
}
