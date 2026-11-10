import 'package:flutter/foundation.dart';
import 'package:soundpad/services/audio_engine.dart';

class FakeAudioEngine implements AudioEngine {
  @override
  VoidCallback? onPlayStateChanged;

  @override
  bool isReady = true;

  final List<String> playing = [];
  final Set<String> paused = {};

  AudioOutputDevice? _currentDevice;
  AudioDeviceStatus _deviceStatus = AudioDeviceStatus.good;
  String? _deviceError;
  List<AudioOutputDevice> devices = [
    const AudioOutputDevice(id: -1, name: 'Динамики (Realtek Audio)', isDefault: true),
    const AudioOutputDevice(id: 1, name: 'Наушники (Audrix Wireless)', isDefault: false),
    const AudioOutputDevice(id: 2, name: 'CABLE Input (VB-Audio Virtual Cable)', isDefault: false),
  ];

  @override
  AudioOutputDevice? get currentDevice => _currentDevice;

  @override
  AudioDeviceStatus get deviceStatus => _deviceStatus;

  @override
  String? get deviceError => _deviceError;

  @override
  List<AudioOutputDevice> listDevices() => List.unmodifiable(devices);

  @override
  Future<void> refreshDevices() async {}

  @override
  Future<void> changeDevice(AudioOutputDevice? device) async {
    _currentDevice = device;
    if (device != null && device.name.contains('Error')) {
      _deviceStatus = AudioDeviceStatus.error;
      _deviceError = 'Устройство не отвечает';
    } else {
      _deviceStatus = AudioDeviceStatus.good;
      _deviceError = null;
    }
    onPlayStateChanged?.call();
  }

  Duration _position = Duration.zero;
  Duration fakeDuration = const Duration(seconds: 10);

  @override
  String? get activeClipId => playing.isNotEmpty ? playing.last : null;

  @override
  bool get isPaused {
    final active = activeClipId;
    return active != null && paused.contains(active);
  }

  @override
  Duration get position => activeClipId != null ? _position : Duration.zero;

  @override
  Duration get duration => activeClipId != null ? fakeDuration : Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  void setMasterVolume(double volume) {}

  @override
  Future<void> setMonitorEnabled(bool enabled) async {}

  @override
  Future<void> stopAll() async {
    playing.clear();
    paused.clear();
    _position = Duration.zero;
    onPlayStateChanged?.call();
  }

  @override
  Future<void> unload(String clipId) async {
    playing.removeWhere((id) => id == clipId);
    paused.remove(clipId);
  }

  @override
  bool isPlaying(String clipId) => playing.contains(clipId);

  @override
  bool isClipPaused(String clipId) => paused.contains(clipId);

  @override
  Future<void> play({
    required String clipId,
    required String path,
    required double volume,
    bool overlap = true,
  }) async {
    if (!overlap) {
      playing.clear();
      paused.clear();
    }
    playing.add(clipId);
    paused.remove(clipId);
    _position = Duration.zero;
    onPlayStateChanged?.call();
  }

  @override
  Future<void> togglePause([String? clipId]) async {
    final target = clipId ?? activeClipId;
    if (target == null || !playing.contains(target)) return;
    if (paused.contains(target)) {
      paused.remove(target);
    } else {
      paused.add(target);
    }
    onPlayStateChanged?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    if (activeClipId == null) return;
    _position = position;
    onPlayStateChanged?.call();
  }
}
