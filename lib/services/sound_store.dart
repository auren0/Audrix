import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sound_clip.dart';

enum AppFontFamily {
  nunito('Nunito', 'Nunito'),
  jetBrainsMono('JetBrainsMono', 'JetBrains Mono');

  const AppFontFamily(this.name, this.displayName);
  final String name;
  final String displayName;
}

class LibraryState {
  const LibraryState({
    required this.sounds,
    this.masterVolume = 1.0,
    this.allowOverlap = true,
    this.isListView = false,
    this.fontFamily = AppFontFamily.nunito,
    this.selectedDeviceName,
    this.monitorEnabled = false,
    this.muteMicWhilePlaying = false,
  });

  final List<SoundClip> sounds;
  final double masterVolume;
  final bool allowOverlap;
  final bool isListView;
  final AppFontFamily fontFamily;
  final String? selectedDeviceName;
  final bool monitorEnabled;
  final bool muteMicWhilePlaying;

  LibraryState copyWith({
    List<SoundClip>? sounds,
    double? masterVolume,
    bool? allowOverlap,
    bool? isListView,
    AppFontFamily? fontFamily,
    String? selectedDeviceName,
    bool clearSelectedDevice = false,
    bool? monitorEnabled,
    bool? muteMicWhilePlaying,
  }) {
    return LibraryState(
      sounds: sounds ?? this.sounds,
      masterVolume: masterVolume ?? this.masterVolume,
      allowOverlap: allowOverlap ?? this.allowOverlap,
      isListView: isListView ?? this.isListView,
      fontFamily: fontFamily ?? this.fontFamily,
      selectedDeviceName: clearSelectedDevice
          ? null
          : (selectedDeviceName ?? this.selectedDeviceName),
      monitorEnabled: monitorEnabled ?? this.monitorEnabled,
      muteMicWhilePlaying: muteMicWhilePlaying ?? this.muteMicWhilePlaying,
    );
  }
}

class SoundStore {
  SoundStore({Directory? rootDirectory}) : _root = rootDirectory;

  Directory? _root;

  Future<Directory> _ensureRoot() async {
    if (_root != null) {
      await _root!.create(recursive: true);
      await Directory(p.join(_root!.path, 'sounds')).create(recursive: true);
      return _root!;
    }
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'soundpad'));
    await _migrateLegacyData(support, root);
    await root.create(recursive: true);
    await Directory(p.join(root.path, 'sounds')).create(recursive: true);
    _root = root;
    return root;
  }

  /// Older builds used the default "com.example/soundpad" Windows metadata.
  /// Move that data to the new location once so existing sounds are not lost.
  Future<void> _migrateLegacyData(
    Directory support,
    Directory root,
  ) async {
    if (await root.exists()) return;
    final appData = p.dirname(p.dirname(support.path));
    final legacy = Directory(
      p.join(appData, 'com.example', 'soundpad', 'soundpad'),
    );
    if (legacy.path == root.path || !await legacy.exists()) return;
    try {
      await root.parent.create(recursive: true);
      await legacy.rename(root.path);
    } catch (_) {
      try {
        await _copyDirectory(legacy, root);
      } catch (_) {
        // If migration fails, continue with an empty library.
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list()) {
      final destination = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destination));
      } else if (entity is File) {
        await entity.copy(destination);
      }
    }
  }

  Future<String> soundsDir() async {
    final root = await _ensureRoot();
    return p.join(root.path, 'sounds');
  }

  Future<String> clipPath(SoundClip clip) async {
    return p.join(await soundsDir(), clip.fileName);
  }

  File _libraryFile(Directory root) => File(p.join(root.path, 'library.json'));

  Future<LibraryState> load() async {
    final root = await _ensureRoot();
    final file = _libraryFile(root);
    if (!await file.exists()) {
      return const LibraryState(sounds: []);
    }

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final sounds = (json['sounds'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map((item) => SoundClip.fromJson(Map<String, Object?>.from(item)))
          .toList();
      final master = (json['masterVolume'] as num?)?.toDouble() ?? 1.0;
      final allowOverlap = json['allowOverlap'] as bool? ?? true;
      final isListView = json['isListView'] as bool? ?? false;
      final fontStr = json['fontFamily'] as String? ?? 'Nunito';
      final fontFamily = fontStr == 'JetBrainsMono'
          ? AppFontFamily.jetBrainsMono
          : AppFontFamily.nunito;
      final selectedDeviceName = json['selectedDeviceName'] as String?;
      final monitorEnabled = json['monitorEnabled'] as bool? ?? false;
      final muteMicWhilePlaying =
          json['muteMicWhilePlaying'] as bool? ?? false;
      return LibraryState(
        sounds: sounds,
        masterVolume: master.clamp(0.0, 2.0),
        allowOverlap: allowOverlap,
        isListView: isListView,
        fontFamily: fontFamily,
        selectedDeviceName: selectedDeviceName,
        monitorEnabled: monitorEnabled,
        muteMicWhilePlaying: muteMicWhilePlaying,
      );
    } catch (_) {
      return const LibraryState(sounds: []);
    }
  }

  Future<void> save(LibraryState state) async {
    final root = await _ensureRoot();
    final payload = jsonEncode({
      'masterVolume': state.masterVolume,
      'allowOverlap': state.allowOverlap,
      'isListView': state.isListView,
      'fontFamily': state.fontFamily.name,
      'selectedDeviceName': state.selectedDeviceName,
      'monitorEnabled': state.monitorEnabled,
      'muteMicWhilePlaying': state.muteMicWhilePlaying,
      'sounds': state.sounds.map((clip) => clip.toJson()).toList(),
    });
    await _libraryFile(root).writeAsString(payload, flush: true);
  }

  Future<SoundClip> importFile(
    String sourcePath,
    int colorIndex, {
    String? customName,
    double volume = 1.0,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Файл не найден', sourcePath);
    }

    final ext = p.extension(sourcePath).toLowerCase();
    final id = _newId();
    final fileName = '$id$ext';
    final dest = File(p.join(await soundsDir(), fileName));
    await source.copy(dest.path);

    final name = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : p.basenameWithoutExtension(sourcePath);
    return SoundClip(
      id: id,
      name: name.isEmpty ? 'Звук' : name,
      fileName: fileName,
      volume: volume.clamp(0.05, 2.0),
      colorIndex: colorIndex,
    );
  }

  Future<String> exportAllSounds(
    String parentDirectoryPath,
    List<SoundClip> clips,
  ) async {
    final parent = Directory(parentDirectoryPath);
    if (!await parent.exists()) {
      throw FileSystemException('Директория не найдена', parentDirectoryPath);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final exportDir = Directory(
      p.join(parentDirectoryPath, 'Audrix_Sounds_$timestamp'),
    );
    await exportDir.create(recursive: true);

    final manifestSounds = <Map<String, Object?>>[];
    final usedNames = <String>{};

    for (final clip in clips) {
      final srcFile = File(await clipPath(clip));
      if (!await srcFile.exists()) continue;

      final ext = p.extension(clip.fileName);
      final safeBase = clip.name
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final baseName = safeBase.isEmpty ? clip.id : safeBase;
      var exportedFileName = '$baseName$ext';
      var counter = 1;
      while (usedNames.contains(exportedFileName.toLowerCase())) {
        exportedFileName = '${baseName}_$counter$ext';
        counter += 1;
      }
      usedNames.add(exportedFileName.toLowerCase());

      await srcFile.copy(p.join(exportDir.path, exportedFileName));
      manifestSounds.add({
        'name': clip.name,
        'exportedFileName': exportedFileName,
        'volume': clip.volume,
        'colorIndex': clip.colorIndex,
      });
    }

    final manifestFile = File(p.join(exportDir.path, 'manifest.json'));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'app': 'Audrix',
        'exportedAt': DateTime.now().toIso8601String(),
        'sounds': manifestSounds,
      }),
      flush: true,
    );

    return exportDir.path;
  }

  Future<List<SoundClip>> importFromDirectory(
    String sourceDirectoryPath,
    int startColorIndex,
  ) async {
    final dir = Directory(sourceDirectoryPath);
    if (!await dir.exists()) {
      throw FileSystemException('Папка не найдена', sourceDirectoryPath);
    }

    const allowedExtensions = {
      '.mp3',
      '.wav',
      '.ogg',
      '.flac',
      '.m4a',
      '.aac',
    };
    final imported = <SoundClip>[];
    final processedFiles = <String>{};
    var color = startColorIndex;

    final manifestFile = File(p.join(dir.path, 'manifest.json'));
    if (await manifestFile.exists()) {
      try {
        final data =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        final items = (data['sounds'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>();
        for (final item in items) {
          final fileName =
              (item['exportedFileName'] ?? item['fileName']) as String?;
          if (fileName == null) continue;
          final audioFile = File(p.join(dir.path, fileName));
          if (!await audioFile.exists()) continue;

          final name = item['name'] as String?;
          final volume = (item['volume'] as num?)?.toDouble() ?? 1.0;
          final colorIndex = (item['colorIndex'] as int?) ?? (color % 8);
          final clip = await importFile(
            audioFile.path,
            colorIndex,
            customName: name,
            volume: volume,
          );
          imported.add(clip);
          processedFiles.add(p.normalize(audioFile.path).toLowerCase());
          color += 1;
        }
      } catch (_) {
        // Fallback to scanning audio files directly if manifest is invalid.
      }
    }

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final normalized = p.normalize(entity.path).toLowerCase();
      if (processedFiles.contains(normalized)) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!allowedExtensions.contains(ext)) continue;

      final clip = await importFile(entity.path, color % 8);
      imported.add(clip);
      color += 1;
    }

    return imported;
  }

  Future<void> deleteFile(SoundClip clip) async {
    final file = File(await clipPath(clip));
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    return '${now.toRadixString(16)}${rand.toRadixString(16)}';
  }
}
