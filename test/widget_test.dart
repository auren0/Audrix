import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:soundpad/app.dart';
import 'package:soundpad/controllers/sound_pad_controller.dart';
import 'package:soundpad/models/sound_clip.dart';
import 'package:soundpad/services/audio_engine.dart';
import 'package:soundpad/services/sound_store.dart';

import 'fake_audio_engine.dart';

void main() {
  testWidgets('empty pad shows Audrix title, playback bar, and FluentIcons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = SoundPadController(
      store: SoundStore(),
      audio: FakeAudioEngine(),
    );
    await tester.pumpWidget(SoundPadApp(controller: controller));
    await tester.pump();

    expect(find.text('Audrix'), findsOneWidget);
    expect(find.text('Пока тихо'), findsOneWidget);
    expect(find.text('Ничего не воспроизводится'), findsOneWidget);
    expect(find.text('00:00 / 00:00'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(FluentIcons.settings_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.speaker_2_24_filled), findsOneWidget);
  });

  testWidgets(
    'switches between Card/ListTile, fonts, devices, and Overlap',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Directory tempDir;
      late SoundStore store;
      late SoundClip importedClip;
      final audio = FakeAudioEngine();
      late SoundPadController controller;

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('audrix_test_');
        final sampleAudio = File(p.join(tempDir.path, 'beep.wav'));
        await sampleAudio.writeAsBytes([1, 2, 3, 4]);

        store = SoundStore(rootDirectory: tempDir);
        controller = SoundPadController(store: store, audio: audio);
        importedClip = await store.importFile(sampleAudio.path, 0);
        await store.save(LibraryState(sounds: [importedClip]));
        await controller.bootstrap();
      });

      addTearDown(() async {
        await tester.runAsync(() async {
          controller.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
      });

      await tester.pumpWidget(SoundPadApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('beep'), findsOneWidget);
      expect(controller.isListView, isFalse);
      expect(controller.allowOverlap, isTrue);
      expect(controller.fontFamily, AppFontFamily.nunito);
      expect(controller.deviceStatus, AudioDeviceStatus.good);
      expect(controller.devices.length, 3);

      var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.textTheme.bodyMedium?.fontFamily, 'Nunito');

      // Test Audio Device selection
      await tester.runAsync(
        () => controller.selectDevice(controller.devices[1]),
      );
      await tester.pumpAndSettle();
      expect(controller.currentDevice?.name, 'Наушники (Audrix Wireless)');
      expect(controller.selectedDeviceName, 'Наушники (Audrix Wireless)');
      expect(controller.deviceStatus, AudioDeviceStatus.good);

      // Local monitoring and microphone muting
      await tester.runAsync(() => controller.setMonitorEnabled(true));
      expect(controller.monitorEnabled, isTrue);
      await tester.runAsync(() => controller.setMuteMicWhilePlaying(true));
      expect(controller.muteMicWhilePlaying, isTrue);

      // Switch font to JetBrainsMono
      await tester.runAsync(
        () => controller.setFontFamily(AppFontFamily.jetBrainsMono),
      );
      await tester.pumpAndSettle();
      materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(
        materialApp.theme?.textTheme.bodyMedium?.fontFamily,
        'JetBrainsMono',
      );

      // Toggle back to Nunito
      await tester.runAsync(() => controller.toggleFontFamily());
      await tester.pumpAndSettle();
      materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.textTheme.bodyMedium?.fontFamily, 'Nunito');

      // Toggle to ListTile view
      await tester.runAsync(() => controller.setIsListView(true));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsWidgets);

      expect(materialApp.theme?.useMaterial3, isTrue);

      // Play sound and test overlap & pause
      await tester.runAsync(() => controller.play(importedClip));
      await tester.runAsync(() => controller.play(importedClip));
      expect(audio.playing.length, 2);

      await tester.runAsync(() => controller.setAllowOverlap(false));
      await tester.runAsync(() => controller.play(importedClip));
      expect(audio.playing.length, 1);

      await tester.runAsync(() => controller.togglePause());
      expect(controller.isPaused, isTrue);

      await tester.runAsync(() => controller.stopAll());
      await tester.pump();

      // Export and re-import from folder
      await tester.runAsync(() async {
        final exportParent = Directory(p.join(tempDir.path, 'exports'));
        await exportParent.create();
        final exportedFolder = await store.exportAllSounds(
          exportParent.path,
          controller.allSounds,
        );
        final reimported = await store.importFromDirectory(exportedFolder, 1);
        expect(reimported.length, 1);
        expect(reimported.first.name, 'beep');
      });
    },
  );

  testWidgets(
    'monitoring switch is off and disabled for the system default output',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late Directory tempDir;
      final audio = FakeAudioEngine();
      late SoundPadController controller;

      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('audrix_monitor_');
        controller = SoundPadController(
          store: SoundStore(rootDirectory: tempDir),
          audio: audio,
        );
        await controller.bootstrap();
      });

      addTearDown(() async {
        await tester.runAsync(() async {
          controller.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
      });

      await tester.pumpWidget(SoundPadApp(controller: controller));
      await tester.pumpAndSettle();

      // Enable monitoring on a concrete output, then select the system default.
      await tester.runAsync(() => controller.selectDevice(audio.devices[1]));
      await tester.runAsync(() => controller.setMonitorEnabled(true));
      expect(controller.canMonitor, isTrue);

      await tester.tap(find.byIcon(FluentIcons.settings_24_regular));
      await tester.pumpAndSettle();

      final monitorSwitch = find.descendant(
        of: find
            .ancestor(
              of: find.text('Слышать звук локально'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(monitorSwitch).value, isTrue);

      await tester.runAsync(() => controller.selectDevice(null));
      await tester.pumpAndSettle();

      expect(controller.canMonitor, isFalse);
      expect(controller.monitorEnabled, isFalse);
      expect(tester.widget<Switch>(monitorSwitch).value, isFalse);
      expect(tester.widget<Switch>(monitorSwitch).onChanged, isNull);
    },
  );
}
