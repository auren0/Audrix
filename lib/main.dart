import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/sound_pad_controller.dart';
import 'services/soloud_audio_engine.dart';
import 'services/sound_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = SoundPadController(
    store: SoundStore(),
    audio: SoLoudAudioEngine(),
  );
  await controller.bootstrap();
  runApp(SoundPadApp(controller: controller));
}
