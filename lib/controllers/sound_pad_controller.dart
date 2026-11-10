import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../models/sound_clip.dart';
import '../services/audio_engine.dart';
import '../services/microphone_service.dart';
import '../services/sound_store.dart';

class SoundPadController extends ChangeNotifier with WidgetsBindingObserver {
  SoundPadController({
    required this.store,
    required this.audio,
    MicrophoneService? microphone,
  }) : microphone = microphone ?? MicrophoneService() {
    WidgetsBinding.instance.addObserver(this);
    audio.onPlayStateChanged = () {
      _playTick += 1;
      _syncProgressTimer();
      _syncMicrophone();
      notifyListeners();
    };
  }

  final SoundStore store;
  final AudioEngine audio;
  final MicrophoneService microphone;

  LibraryState _state = const LibraryState(sounds: []);
  String _query = '';
  String? _error;
  bool _loading = false;
  int _playTick = 0;
  Timer? _saveTimer;
  Timer? _progressTimer;

  /// Тикает во время воспроизведения; слушает только полоса прогресса,
  /// чтобы не перестраивать весь экран каждые 100 мс.
  final ValueNotifier<int> progress = ValueNotifier<int>(0);

  /// Меняется только при смене шрифта, чтобы не пересоздавать тему.
  late final ValueNotifier<AppFontFamily> fontListenable =
      ValueNotifier<AppFontFamily>(_state.fontFamily);

  List<SoundClip> get sounds {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _state.sounds;
    return _state.sounds
        .where((clip) => clip.name.toLowerCase().contains(q))
        .toList();
  }

  List<SoundClip> get allSounds => _state.sounds;

  double get masterVolume => _state.masterVolume;
  bool get allowOverlap => _state.allowOverlap;
  bool get isListView => _state.isListView;
  AppFontFamily get fontFamily => _state.fontFamily;
  bool get monitorEnabled => _state.monitorEnabled;
  bool get muteMicWhilePlaying => _state.muteMicWhilePlaying;
  bool get canMuteMicrophone => microphone.isSupported;
  String get query => _query;

  String? takeError() {
    final message = _error;
    _error = null;
    return message;
  }

  bool get loading => _loading;
  bool get engineReady => audio.isReady;
  int get playTick => _playTick;

  bool isPlaying(String id) => audio.isPlaying(id);
  bool isClipPaused(String id) => audio.isClipPaused(id);

  SoundClip? get activeClip {
    final activeId = audio.activeClipId;
    if (activeId == null) return null;
    for (final clip in _state.sounds) {
      if (clip.id == activeId) return clip;
    }
    return null;
  }

  bool get isPaused => audio.isPaused;
  Duration get position => audio.position;
  Duration get duration => audio.duration;

  List<AudioOutputDevice> get devices => audio.listDevices();
  AudioOutputDevice? get currentDevice => audio.currentDevice;
  AudioDeviceStatus get deviceStatus => audio.deviceStatus;
  String? get deviceError => audio.deviceError;
  String? get selectedDeviceName => _state.selectedDeviceName;

  /// Local monitoring needs a concrete, non-default output device: with the
  /// system default the primary stream is already audible.
  bool get canMonitor {
    final device = audio.currentDevice;
    return device != null && !device.isDefault;
  }

  void _syncProgressTimer() {
    final shouldRun = audio.activeClipId != null && !audio.isPaused;
    if (shouldRun && _progressTimer == null) {
      _progressTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          if (audio.activeClipId == null || audio.isPaused) {
            _progressTimer?.cancel();
            _progressTimer = null;
          }
          progress.value++;
        },
      );
    } else if (!shouldRun && _progressTimer != null) {
      _progressTimer?.cancel();
      _progressTimer = null;
    }
  }

  void _syncMicrophone() {
    final shouldMute = _state.muteMicWhilePlaying &&
        audio.activeClipId != null &&
        !audio.isPaused;
    unawaited(microphone.setMuted(shouldMute));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(microphone.restore());
      case AppLifecycleState.resumed:
        _syncMicrophone();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    try {
      await audio.init();
      _state = await store.load();
      fontListenable.value = _state.fontFamily;
      audio.setMasterVolume(_state.masterVolume);

      // Restore saved device
      if (_state.selectedDeviceName != null) {
        final available = audio.listDevices();
        final matched = available
            .where((d) => d.name == _state.selectedDeviceName)
            .firstOrNull;
        if (matched != null) {
          await audio.changeDevice(matched);
        }
      }
      await audio.setMonitorEnabled(_state.monitorEnabled);

      _error = null;
    } catch (error) {
      _error = 'Не удалось запустить аудио: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Future<void> setMasterVolume(double value) async {
    _state = _state.copyWith(masterVolume: value.clamp(0.0, 2.0));
    audio.setMasterVolume(_state.masterVolume);
    notifyListeners();
    _scheduleSave();
  }

  Future<void> setAllowOverlap(bool value) async {
    _state = _state.copyWith(allowOverlap: value);
    notifyListeners();
    await store.save(_state);
  }

  Future<void> setIsListView(bool value) async {
    _state = _state.copyWith(isListView: value);
    notifyListeners();
    await store.save(_state);
  }

  Future<void> setFontFamily(AppFontFamily value) async {
    _state = _state.copyWith(fontFamily: value);
    fontListenable.value = value;
    notifyListeners();
    await store.save(_state);
  }

  Future<void> toggleFontFamily() async {
    final next = _state.fontFamily == AppFontFamily.nunito
        ? AppFontFamily.jetBrainsMono
        : AppFontFamily.nunito;
    await setFontFamily(next);
  }

  Future<void> setMonitorEnabled(bool value) async {
    _state = _state.copyWith(monitorEnabled: value);
    await audio.setMonitorEnabled(value);
    notifyListeners();
    await store.save(_state);
  }

  Future<void> setMuteMicWhilePlaying(bool value) async {
    _state = _state.copyWith(muteMicWhilePlaying: value);
    _syncMicrophone();
    notifyListeners();
    await store.save(_state);
  }

  Future<void> selectDevice(AudioOutputDevice? device) async {
    // A device flagged as the OS default behaves exactly like "Системное по
    // умолчанию": monitoring has nothing to duplicate into.
    final target = device != null && device.isDefault ? null : device;
    await audio.changeDevice(target);
    _state = _state.copyWith(
      selectedDeviceName: target?.name,
      clearSelectedDevice: target == null,
    );
    if (target == null && _state.monitorEnabled) {
      // The option is unavailable for this output. Clear the flag instead of
      // leaving a hidden "on" state that would reappear as an enabled switch.
      _state = _state.copyWith(monitorEnabled: false);
      await audio.setMonitorEnabled(false);
    }
    await store.save(_state);
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    await audio.refreshDevices();
    notifyListeners();
  }

  Future<void> setClipVolume(String id, double value) async {
    _state = _state.copyWith(
      sounds: [
        for (final clip in _state.sounds)
          if (clip.id == id)
            clip.copyWith(volume: value.clamp(0.05, 2.0))
          else
            clip,
      ],
    );
    notifyListeners();
    _scheduleSave();
  }

  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _state = _state.copyWith(
      sounds: [
        for (final clip in _state.sounds)
          if (clip.id == id) clip.copyWith(name: trimmed) else clip,
      ],
    );
    notifyListeners();
    await store.save(_state);
  }

  Future<int> addSounds() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Выберите звуковые файлы',
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'],
    );
    if (result == null || result.files.isEmpty) return 0;

    var imported = 0;
    var color = _state.sounds.length;
    final next = [..._state.sounds];

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      try {
        final clip = await store.importFile(path, color % 8);
        next.add(clip);
        color += 1;
        imported += 1;
      } catch (error) {
        _error = 'Не удалось добавить ${file.name}: $error';
      }
    }

    _state = _state.copyWith(sounds: next);
    await store.save(_state);
    notifyListeners();
    return imported;
  }

  Future<int> importSoundsFromFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку со звуками для импорта',
    );
    if (dirPath == null) return 0;

    try {
      final imported = await store.importFromDirectory(
        dirPath,
        _state.sounds.length,
      );
      if (imported.isEmpty) return 0;
      _state = _state.copyWith(sounds: [..._state.sounds, ...imported]);
      await store.save(_state);
      notifyListeners();
      return imported.length;
    } catch (error) {
      _error = 'Не удалось импортировать звуки из папки: $error';
      notifyListeners();
      return 0;
    }
  }

  Future<String?> exportAllSounds() async {
    if (_state.sounds.isEmpty) {
      _error = 'Нет звуков для экспорта.';
      notifyListeners();
      return null;
    }

    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите директорию, куда сохранить папку со звуками',
    );
    if (dirPath == null) return null;

    try {
      final exportedPath = await store.exportAllSounds(dirPath, _state.sounds);
      return exportedPath;
    } catch (error) {
      _error = 'Ошибка экспорта звуков: $error';
      notifyListeners();
      return null;
    }
  }

  Future<void> remove(String id) async {
    SoundClip? removed;
    final next = <SoundClip>[];
    for (final clip in _state.sounds) {
      if (clip.id == id) {
        removed = clip;
      } else {
        next.add(clip);
      }
    }
    if (removed == null) return;

    await audio.unload(id);
    await store.deleteFile(removed);
    _state = _state.copyWith(sounds: next);
    await store.save(_state);
    _syncProgressTimer();
    notifyListeners();
  }

  Future<void> play(SoundClip clip) async {
    try {
      final path = await store.clipPath(clip);
      await audio.play(
        clipId: clip.id,
        path: path,
        volume: clip.volume,
        overlap: _state.allowOverlap,
      );
      _error = null;
      _playTick += 1;
      _syncProgressTimer();
      notifyListeners();
    } catch (error) {
      _error = 'Не удалось воспроизвести «${clip.name}»: $error';
      notifyListeners();
    }
  }

  Future<void> togglePause([String? clipId]) async {
    await audio.togglePause(clipId);
    _playTick += 1;
    _syncProgressTimer();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await audio.seek(position);
    progress.value++;
  }

  Future<void> stopAll() async {
    await audio.stopAll();
    _playTick += 1;
    _syncProgressTimer();
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(store.save(_state));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(microphone.restore());
    _saveTimer?.cancel();
    _progressTimer?.cancel();
    progress.dispose();
    fontListenable.dispose();
    super.dispose();
  }
}
