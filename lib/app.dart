import 'package:flutter/material.dart';

import 'controllers/sound_pad_controller.dart';
import 'screens/sound_pad_screen.dart';
import 'services/sound_store.dart';
import 'theme.dart';

class SoundPadApp extends StatelessWidget {
  const SoundPadApp({super.key, required this.controller});

  final SoundPadController controller;

  @override
  Widget build(BuildContext context) {
    // Слушаем только смену шрифта: тема (ColorScheme.fromSeed) дорогая
    // и не должна пересоздаваться при каждом уведомлении контроллера.
    return ValueListenableBuilder<AppFontFamily>(
      valueListenable: controller.fontListenable,
      builder: (context, fontFamily, _) {
        final font = fontFamily.name;
        return MaterialApp(
          title: 'Audrix',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          theme: SoundPadTheme.light(fontFamily: font),
          darkTheme: SoundPadTheme.dark(fontFamily: font),
          themeMode: ThemeMode.system,
          home: SoundPadScreen(controller: controller),
        );
      },
    );
  }
}
