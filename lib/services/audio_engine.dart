import 'package:flutter/foundation.dart';

class AudioOutputDevice {
  const AudioOutputDevice({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final bool isDefault;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioOutputDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'AudioOutputDevice(id: $id, name: $name, isDefault: $isDefault)';
}

enum AudioDeviceStatus {
  good('Готово к работе', 'Устройство подключено, звук выводится без ошибок'),
  warning('Используется по умолчанию', 'Выбрано системное устройство вывода'),
  error('Ошибка устройства', 'Не удалось подключиться к аудиоустройству');

  const AudioDeviceStatus(this.label, this.description);
  final String label;
  final String description;
}

abstract class AudioEngine {
  VoidCallback? onPlayStateChanged;

  bool get isReady;

  String? get activeClipId;

  bool get isPaused;

  Duration get position;

  Duration get duration;

  List<AudioOutputDevice> listDevices();

  AudioOutputDevice? get currentDevice;

  AudioDeviceStatus get deviceStatus;

  String? get deviceError;

  Future<void> refreshDevices();

  Future<void> changeDevice(AudioOutputDevice? device);

  Future<void> init();

  Future<void> dispose();

  void setMasterVolume(double volume);

  /// When enabled and a non-default output device is selected, every sound is
  /// also played on the system default output so the user can hear it locally.
  Future<void> setMonitorEnabled(bool enabled);

  Future<void> stopAll();

  Future<void> unload(String clipId);

  bool isPlaying(String clipId);

  bool isClipPaused(String clipId);

  Future<void> play({
    required String clipId,
    required String path,
    required double volume,
    bool overlap = true,
  });

  Future<void> togglePause([String? clipId]);

  Future<void> seek(Duration position);
}
