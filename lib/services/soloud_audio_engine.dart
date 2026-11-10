import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'audio_engine.dart';

/// Thin Dart wrapper around the SoLoud C++ mixer (via FFI).
///
/// Sounds stay on disk and are decoded lazily. Only a small LRU of sources
/// is kept in memory so a large pad does not sit fully decoded in RAM.
class SoLoudAudioEngine implements AudioEngine {
  SoLoudAudioEngine({this.maxCachedSources = 12});

  final int maxCachedSources;
  final LinkedHashMap<String, AudioSource> _cache = LinkedHashMap();
  final Map<SoundHandle, String> _active = {};
  final Map<String, Duration> _durations = {};
  final Set<SoundHandle> _pausedHandles = {};

  final Map<ap.AudioPlayer, _MonitorVoice> _monitors = {};
  bool _monitorEnabled = false;
  double _masterVolume = 1.0;

  SoundHandle? _primaryHandle;
  String? _primaryClipId;

  SoLoud? _soloud;
  bool _ready = false;

  AudioOutputDevice? _currentDevice;
  AudioDeviceStatus _deviceStatus = AudioDeviceStatus.good;
  String? _deviceError;
  List<AudioOutputDevice> _devices = [];

  @override
  VoidCallback? onPlayStateChanged;

  @override
  bool get isReady => _ready;

  @override
  AudioOutputDevice? get currentDevice => _currentDevice;

  @override
  AudioDeviceStatus get deviceStatus => _deviceStatus;

  @override
  String? get deviceError => _deviceError;

  @override
  List<AudioOutputDevice> listDevices() => List.unmodifiable(_devices);

  bool get _shouldMonitor =>
      _monitorEnabled &&
      _currentDevice != null &&
      !_currentDevice!.isDefault;

  @override
  Future<void> refreshDevices() async {
    try {
      final nativeDevices = _engine.listPlaybackDevices();
      _devices = nativeDevices
          .map((d) => AudioOutputDevice(
                id: d.id,
                name: d.name,
                isDefault: d.isDefault,
              ))
          .toList();
      _deviceError = null;
      if (_currentDevice != null) {
        final stillExists = _devices.any((d) => d.name == _currentDevice!.name);
        if (!stillExists) {
          _deviceStatus = AudioDeviceStatus.error;
          _deviceError = 'Устройство «${_currentDevice!.name}» отключено';
        } else {
          _deviceStatus = AudioDeviceStatus.good;
        }
      } else {
        _deviceStatus = AudioDeviceStatus.good;
      }
    } catch (e) {
      _deviceStatus = AudioDeviceStatus.error;
      _deviceError = 'Не удалось обновить список устройств: $e';
    }
    onPlayStateChanged?.call();
  }

  @override
  Future<void> changeDevice(AudioOutputDevice? device) async {
    if (!_ready) return;
    try {
      if (device == null) {
        await _switchToSystemDefault();
        _currentDevice = null;
        _deviceStatus = AudioDeviceStatus.good;
        _deviceError = null;
      } else {
        final nativeDevices = _engine.listPlaybackDevices();
        final nativeDevice = nativeDevices
            .where((d) => d.id == device.id || d.name == device.name)
            .firstOrNull;
        if (nativeDevice == null) {
          throw StateError('Устройство «${device.name}» не найдено');
        }
        _engine.changeDevice(newDevice: nativeDevice);
        // A device flagged as the OS default is equivalent to the system
        // default output: there is nothing to monitor into.
        _currentDevice = device.isDefault ? null : device;
        _deviceStatus = AudioDeviceStatus.good;
        _deviceError = null;
      }
    } catch (e) {
      _deviceStatus = AudioDeviceStatus.error;
      _deviceError = 'Не удалось переключить устройство: $e';
    }
    if (!_shouldMonitor) {
      await _stopAllMonitors();
    }
    onPlayStateChanged?.call();
  }

  /// Switches the primary output back to the OS default device.
  ///
  /// The plugin's `changeDevice()` without an argument (device id `-1`) is
  /// rejected by the native bounds check, and switching to an id obtained from
  /// a previous device enumeration can silently keep the old output. Reopening
  /// the engine without a device is the only reliable way to fall back to the
  /// default output, so it is always used here.
  Future<void> _switchToSystemDefault() async {
    await _reinitOnDefaultDevice();
  }

  Future<void> _reinitOnDefaultDevice() async {
    await _stopAllMonitors();
    try {
      _engine.deinit();
      // The native engine disposed every loaded source, so drop stale
      // references before reopening it.
      _cache.clear();
      _active.clear();
      _pausedHandles.clear();
      _durations.clear();
      _primaryHandle = null;
      _primaryClipId = null;
      await _engine.init(
        automaticCleanup: true,
        bufferSize: 2048,
        channels: Channels.stereo,
      );
      _ready = true;
    } catch (_) {
      _ready = false;
      rethrow;
    }
  }

  @override
  String? get activeClipId {
    if (_primaryHandle != null && _active.containsKey(_primaryHandle)) {
      return _primaryClipId;
    }
    if (_active.isNotEmpty) {
      return _active.values.last;
    }
    return null;
  }

  SoundHandle? get _currentHandle {
    if (_primaryHandle != null && _active.containsKey(_primaryHandle)) {
      return _primaryHandle;
    }
    if (_active.isNotEmpty) {
      return _active.keys.last;
    }
    return null;
  }

  @override
  bool get isPaused {
    final handle = _currentHandle;
    if (!_ready || handle == null) return false;
    return _pausedHandles.contains(handle);
  }

  @override
  Duration get position {
    final handle = _currentHandle;
    if (!_ready || handle == null) return Duration.zero;
    try {
      if (!_engine.getIsValidVoiceHandle(handle)) return Duration.zero;
      return _engine.getPosition(handle);
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Duration get duration {
    final clipId = activeClipId;
    if (!_ready || clipId == null) return Duration.zero;
    final cachedDuration = _durations[clipId];
    if (cachedDuration != null && cachedDuration > Duration.zero) {
      return cachedDuration;
    }
    final source = _cache[clipId];
    if (source == null) return Duration.zero;
    try {
      final len = _engine.getLength(source);
      _durations[clipId] = len;
      return len;
    } catch (_) {
      return Duration.zero;
    }
  }

  SoLoud get _engine {
    final engine = _soloud ??= SoLoud.instance;
    return engine;
  }

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      await _engine.init(
        automaticCleanup: true,
        bufferSize: 2048,
        channels: Channels.stereo,
      );
      _ready = true;
      _deviceStatus = AudioDeviceStatus.good;
      _deviceError = null;
    } catch (e) {
      _deviceStatus = AudioDeviceStatus.error;
      _deviceError = 'Ошибка инициализации аудиодвижка: $e';
      rethrow;
    }
    await refreshDevices();
  }

  @override
  Future<void> dispose() async {
    await _stopAllMonitors();
    if (!_ready) return;
    await stopAll();
    await _clearCache();
    _engine.deinit();
    _ready = false;
  }

  @override
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 2.0);
    if (_ready) {
      _engine.setGlobalVolume(_masterVolume);
    }
    _updateMonitorVolumes();
  }

  @override
  Future<void> setMonitorEnabled(bool enabled) async {
    if (_monitorEnabled == enabled) return;
    _monitorEnabled = enabled;
    if (!enabled) {
      await _stopAllMonitors();
    }
  }

  @override
  Future<void> stopAll() async {
    await _stopAllMonitors();
    if (!_ready) return;
    final handles = _active.keys.toList();
    _active.clear();
    _pausedHandles.clear();
    _primaryHandle = null;
    _primaryClipId = null;
    for (final handle in handles) {
      await _engine.stop(handle);
    }
    onPlayStateChanged?.call();
  }

  @override
  Future<void> unload(String clipId) async {
    await _stopMonitorsForClip(clipId);
    final source = _cache.remove(clipId);
    if (source != null) {
      await _engine.disposeSource(source);
    }
    _durations.remove(clipId);
    final removedHandles = _active.entries
        .where((e) => e.value == clipId)
        .map((e) => e.key)
        .toList();
    for (final h in removedHandles) {
      _active.remove(h);
      _pausedHandles.remove(h);
      if (_primaryHandle == h) {
        _primaryHandle = null;
        _primaryClipId = null;
      }
    }
  }

  @override
  bool isPlaying(String clipId) => _active.containsValue(clipId);

  @override
  bool isClipPaused(String clipId) {
    final handles = _active.entries
        .where((e) => e.value == clipId)
        .map((e) => e.key)
        .toList();
    if (handles.isEmpty) return false;
    return handles.every(_pausedHandles.contains);
  }

  @override
  Future<void> play({
    required String clipId,
    required String path,
    required double volume,
    bool overlap = true,
  }) async {
    if (!_ready) {
      throw StateError('Аудиодвижок ещё не готов.');
    }

    if (!overlap && _active.isNotEmpty) {
      await _stopAllMonitors();
      final handles = _active.keys.toList();
      _active.clear();
      _pausedHandles.clear();
      _primaryHandle = null;
      _primaryClipId = null;
      for (final handle in handles) {
        await _engine.stop(handle);
      }
    }

    final source = await _sourceFor(clipId, path);
    try {
      _durations[clipId] = _engine.getLength(source);
    } catch (_) {}

    final handle = await _engine.play(
      source,
      volume: volume.clamp(0.0, 2.0),
    );
    _active[handle] = clipId;
    _primaryHandle = handle;
    _primaryClipId = clipId;
    if (_shouldMonitor) {
      await _startMonitor(clipId, path, volume);
    }
    onPlayStateChanged?.call();
  }

  @override
  Future<void> togglePause([String? clipId]) async {
    if (!_ready || _active.isEmpty) return;

    final targetHandles = clipId != null
        ? _active.entries
            .where((e) => e.value == clipId)
            .map((e) => e.key)
            .toList()
        : (_currentHandle != null ? [_currentHandle!] : <SoundHandle>[]);

    if (targetHandles.isEmpty) return;

    final shouldPause = targetHandles.any((h) => !_pausedHandles.contains(h));
    for (final handle in targetHandles) {
      try {
        if (_engine.getIsValidVoiceHandle(handle)) {
          _engine.setPause(handle, shouldPause);
          if (shouldPause) {
            _pausedHandles.add(handle);
          } else {
            _pausedHandles.remove(handle);
          }
        }
      } catch (_) {}
    }
    final targetClip = clipId ??
        (_currentHandle != null ? _active[_currentHandle] : null);
    if (targetClip != null) {
      await _setMonitorsPaused(targetClip, shouldPause);
    }
    onPlayStateChanged?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    final handle = _currentHandle;
    if (!_ready || handle == null) return;
    try {
      if (_engine.getIsValidVoiceHandle(handle)) {
        final maxLen = duration;
        final clamped = maxLen > Duration.zero && position > maxLen
            ? maxLen
            : (position.isNegative ? Duration.zero : position);
        _engine.seek(handle, clamped);
        final clipId = _active[handle];
        if (clipId != null) {
          await _seekMonitors(clipId, clamped);
        }
        onPlayStateChanged?.call();
      }
    } catch (_) {}
  }

  Future<AudioSource> _sourceFor(String clipId, String path) async {
    final cached = _cache.remove(clipId);
    if (cached != null) {
      _cache[clipId] = cached;
      return cached;
    }

    while (_cache.length >= maxCachedSources) {
      final oldestId = _cache.keys.first;
      final oldest = _cache.remove(oldestId);
      if (oldest != null) {
        await _engine.disposeSource(oldest);
      }
    }

    final source = await _engine.loadFile(path, mode: LoadMode.disk);
    _cache[clipId] = source;
    source.soundEvents.listen((event) {
      if (event.event == SoundEventType.handleIsNoMoreValid) {
        _active.remove(event.handle);
        _pausedHandles.remove(event.handle);
        if (_primaryHandle == event.handle) {
          _primaryHandle = _active.isNotEmpty ? _active.keys.last : null;
          _primaryClipId = _primaryHandle != null ? _active[_primaryHandle] : null;
        }
        onPlayStateChanged?.call();
      }
    });
    return source;
  }

  double _monitorVolume(double clipVolume) =>
      (_masterVolume * clipVolume).clamp(0.0, 1.0);

  Future<void> _startMonitor(
    String clipId,
    String path,
    double clipVolume,
  ) async {
    ap.AudioPlayer? player;
    try {
      player = ap.AudioPlayer();
      final voice = _MonitorVoice(clipId: clipId, clipVolume: clipVolume);
      _monitors[player] = voice;
      player.onPlayerComplete.listen((_) => unawaited(_stopMonitor(player!)));
      await player.setReleaseMode(ap.ReleaseMode.stop);
      await player.setVolume(_monitorVolume(clipVolume));
      await player.play(ap.DeviceFileSource(path));
    } catch (_) {
      // Monitoring is best-effort: the primary output must keep working.
      if (player != null) {
        await _stopMonitor(player);
      }
    }
  }

  Future<void> _stopMonitor(ap.AudioPlayer player) async {
    _monitors.remove(player);
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  Future<void> _stopAllMonitors() async {
    for (final player in _monitors.keys.toList()) {
      await _stopMonitor(player);
    }
  }

  Future<void> _stopMonitorsForClip(String clipId) async {
    final players = _monitors.entries
        .where((entry) => entry.value.clipId == clipId)
        .map((entry) => entry.key)
        .toList();
    for (final player in players) {
      await _stopMonitor(player);
    }
  }

  Future<void> _setMonitorsPaused(String clipId, bool paused) async {
    final entries = _monitors.entries.toList();
    for (final entry in entries) {
      if (entry.value.clipId != clipId || !_monitors.containsKey(entry.key)) {
        continue;
      }
      try {
        if (paused) {
          await entry.key.pause();
        } else {
          await entry.key.resume();
        }
        entry.value.paused = paused;
      } catch (_) {}
    }
  }

  Future<void> _seekMonitors(String clipId, Duration position) async {
    final entries = _monitors.entries.toList();
    for (final entry in entries) {
      if (entry.value.clipId != clipId || !_monitors.containsKey(entry.key)) {
        continue;
      }
      try {
        await entry.key.seek(position);
      } catch (_) {}
    }
  }

  void _updateMonitorVolumes() {
    for (final entry in _monitors.entries) {
      unawaited(
        _applyMonitorVolume(entry.key, _monitorVolume(entry.value.clipVolume)),
      );
    }
  }

  Future<void> _applyMonitorVolume(
    ap.AudioPlayer player,
    double volume,
  ) async {
    try {
      await player.setVolume(volume);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    await _stopAllMonitors();
    for (final source in _cache.values) {
      await _engine.disposeSource(source);
    }
    _cache.clear();
    _active.clear();
    _pausedHandles.clear();
    _durations.clear();
    _primaryHandle = null;
    _primaryClipId = null;
  }
}

class _MonitorVoice {
  _MonitorVoice({required this.clipId, required this.clipVolume});

  final String clipId;
  final double clipVolume;
  bool paused = false;
}
