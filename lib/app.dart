import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/radio_provider.dart';
import 'providers/dis_provider.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

class DisRadioApp extends StatelessWidget {
  const DisRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => AudioProvider()..initialize()),
        ChangeNotifierProxyProvider<SettingsProvider, RadioProvider>(
          create: (_) => RadioProvider(),
          update: (context, settings, rp) {
            rp ??= RadioProvider();
            rp.load();
            return rp;
          },
        ),
        ChangeNotifierProxyProvider2<RadioProvider, SettingsProvider, DisProvider>(
          create: (_) => DisProvider(),
          update: (context, rp, sp, dis) {
            dis ??= DisProvider();
            dis.updateRadios(rp.radios.toList(), rp.intercoms.toList());
            return dis;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'RaDIS',
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: settings.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
