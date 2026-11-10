import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/sound_pad_controller.dart';
import '../models/sound_clip.dart';
import '../widgets/sound_tile.dart';
import 'settings_screen.dart';

class SoundPadScreen extends StatefulWidget {
  const SoundPadScreen({super.key, required this.controller});

  final SoundPadController controller;

  @override
  State<SoundPadScreen> createState() => _SoundPadScreenState();
}

class _SoundPadScreenState extends State<SoundPadScreen> {
  final _search = SearchController();

  SoundPadController get _pad => widget.controller;

  @override
  void initState() {
    super.initState();
    _pad.addListener(_onPad);
    _search.addListener(() => _pad.setQuery(_search.text));
  }

  @override
  void dispose() {
    _pad.removeListener(_onPad);
    _search.dispose();
    super.dispose();
  }

  void _onPad() {
    if (!mounted) return;
    final message = _pad.takeError();
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    setState(() {});
  }

  Future<void> _add() async {
    final count = await _pad.addSounds();
    if (!mounted || count == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1 ? 'Добавлен 1 звук' : 'Добавлено звуков: $count',
        ),
      ),
    );
  }

  Future<void> _importFolder() async {
    final count = await _pad.importSoundsFromFolder();
    if (!mounted || count == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Импортирован 1 звук из папки'
              : 'Импортировано звуков из папки: $count',
        ),
      ),
    );
  }

  Future<void> _exportAll() async {
    final exportedPath = await _pad.exportAllSounds();
    if (!mounted || exportedPath == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Звуки экспортированы в папку: $exportedPath')),
    );
  }

  Future<void> _openDevicePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: _pad,
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final devices = _pad.devices;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.speaker_settings_24_filled,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Устройство вывода звука',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Обновить устройства',
                            onPressed: _pad.refreshDevices,
                            icon: const Icon(
                              FluentIcons.arrow_clockwise_24_regular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DeviceStatusBanner(
                        status: _pad.deviceStatus,
                        errorText: _pad.deviceError,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Выберите аудиоустройство:',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        selected: _pad.selectedDeviceName == null,
                        leading: Icon(
                          FluentIcons.desktop_speaker_24_regular,
                          color: scheme.primary,
                        ),
                        title: const Text('Системное по умолчанию'),
                        subtitle: const Text('Основной вывод Windows'),
                        trailing: Icon(
                          _pad.selectedDeviceName == null
                              ? FluentIcons.checkmark_circle_24_filled
                              : FluentIcons.circle_24_regular,
                          color: _pad.selectedDeviceName == null
                              ? scheme.primary
                              : scheme.outline,
                        ),
                        onTap: () => _pad.selectDevice(null),
                      ),
                      for (final dev in devices)
                        ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          selected: _pad.selectedDeviceName == dev.name,
                          leading: Icon(
                            dev.name.toLowerCase().contains('cable') ||
                                    dev.name.toLowerCase().contains('virtual')
                                ? FluentIcons.channel_share_24_regular
                                : (dev.name.toLowerCase().contains('head') ||
                                          dev.name.toLowerCase().contains(
                                            'науш',
                                          )
                                      ? FluentIcons.headphones_24_regular
                                      : FluentIcons.speaker_2_24_regular),
                            color: scheme.primary,
                          ),
                          title: Text(dev.name),
                          subtitle: Text(
                            dev.isDefault
                                ? 'Устройство по умолчанию в ОС'
                                : 'Аудиовыход',
                          ),
                          trailing: Icon(
                            _pad.selectedDeviceName == dev.name
                                ? FluentIcons.checkmark_circle_24_filled
                                : FluentIcons.circle_24_regular,
                            color: _pad.selectedDeviceName == dev.name
                                ? scheme.primary
                                : scheme.outline,
                          ),
                          onTap: () => _pad.selectDevice(dev),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          pad: _pad,
          onOpenPicker: _openDevicePicker,
          onAddFiles: _add,
          onImportFolder: _importFolder,
          onExportAll: _exportAll,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(SoundClip clip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FluentIcons.delete_24_regular),
            SizedBox(width: 10),
            Text('Удалить звук?'),
          ],
        ),
        content: Text(
          '«${clip.name}» будет удалён с панели и с диска приложения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await _pad.remove(clip.id);
  }

  Future<void> _editVolume(SoundClip clip) async {
    var value = clip.volume;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(FluentIcons.speaker_2_24_regular),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          clip.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Громкость ${(value * 100).round()}%. Можно поднять выше 100%.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Slider(
                    min: 0.05,
                    max: 2,
                    divisions: 39,
                    label: '${(value * 100).round()}%',
                    value: value,
                    onChanged: (next) => setSheet(() => value = next),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    await _pad.setClipVolume(clip.id, value);
  }

  Future<void> _rename(SoundClip clip) async {
    final editor = TextEditingController(text: clip.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(FluentIcons.edit_24_regular),
            SizedBox(width: 10),
            Text('Переименовать'),
          ],
        ),
        content: TextField(
          controller: editor,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editor.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (name != null) await _pad.rename(clip.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final sounds = _pad.sounds;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _pad.stopAll,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Audrix'),
            actions: [
              IconButton(
                tooltip: 'Настройки',
                onPressed: _openSettings,
                icon: const Icon(FluentIcons.settings_24_regular),
              ),
              // PopupMenuButton<String>(
              //   tooltip: 'Меню и действия',
              //   icon: const Icon(FluentIcons.more_vertical_24_regular),
              //   onSelected: (value) {
              //     switch (value) {
              //       case 'add_files':
              //         _add();
              //       case 'import_folder':
              //         _importFolder();
              //       case 'export_all':
              //         _exportAll();
              //       case 'toggle_overlap':
              //         _pad.setAllowOverlap(!_pad.allowOverlap);
              //       case 'toggle_view':
              //         _pad.setIsListView(!_pad.isListView);
              //       case 'toggle_m3':
              //         _pad.setUseMaterial3(!_pad.useMaterial3);
              //       case 'toggle_font':
              //         _pad.toggleFontFamily();
              //       case 'settings':
              //         _openSettings();
              //     }
              //   },
              //   itemBuilder: (context) => [
              //     const PopupMenuItem(
              //       value: 'add_files',
              //       child: Row(
              //         children: [
              //           Icon(FluentIcons.add_24_regular, size: 20),
              //           SizedBox(width: 12),
              //           Text('Импорт звуков (файлы)'),
              //         ],
              //       ),
              //     ),
              //     const PopupMenuItem(
              //       value: 'import_folder',
              //       child: Row(
              //         children: [
              //           Icon(
              //             FluentIcons.folder_arrow_right_24_regular,
              //             size: 20,
              //           ),
              //           SizedBox(width: 12),
              //           Text('Импорт звуков из папки'),
              //         ],
              //       ),
              //     ),
              //     const PopupMenuItem(
              //       value: 'export_all',
              //       child: Row(
              //         children: [
              //           Icon(FluentIcons.arrow_export_up_24_regular, size: 20),
              //           SizedBox(width: 12),
              //           Text('Экспорт всех звуков'),
              //         ],
              //       ),
              //     ),
              //     const PopupMenuDivider(),
              //     PopupMenuItem(
              //       value: 'toggle_overlap',
              //       child: Row(
              //         children: [
              //           Icon(
              //             _pad.allowOverlap
              //                 ? FluentIcons.layer_24_filled
              //                 : FluentIcons.layer_24_regular,
              //             size: 20,
              //           ),
              //           const SizedBox(width: 12),
              //           Text(
              //             _pad.allowOverlap
              //                 ? 'Наложение звука: Вкл'
              //                 : 'Наложение звука: Выкл',
              //           ),
              //         ],
              //       ),
              //     ),
              //     PopupMenuItem(
              //       value: 'toggle_view',
              //       child: Row(
              //         children: [
              //           Icon(
              //             _pad.isListView
              //                 ? FluentIcons.grid_24_regular
              //                 : FluentIcons.apps_list_24_regular,
              //             size: 20,
              //           ),
              //           const SizedBox(width: 12),
              //           Text(
              //             _pad.isListView
              //                 ? 'Вид: Карточки'
              //                 : 'Вид: Список (ListTile)',
              //           ),
              //         ],
              //       ),
              //     ),
              //     PopupMenuItem(
              //       value: 'toggle_m3',
              //       child: Row(
              //         children: [
              //           const Icon(
              //             FluentIcons.design_ideas_24_regular,
              //             size: 20,
              //           ),
              //           const SizedBox(width: 12),
              //           Text(
              //             _pad.useMaterial3
              //                 ? 'Переключить на Material 2'
              //                 : 'Переключить на Material 3',
              //           ),
              //         ],
              //       ),
              //     ),
              //     PopupMenuItem(
              //       value: 'toggle_font',
              //       child: Row(
              //         children: [
              //           const Icon(FluentIcons.text_font_24_regular, size: 20),
              //           const SizedBox(width: 12),
              //           Text(
              //             _pad.fontFamily == AppFontFamily.nunito
              //                 ? 'Шрифт: JetBrains Mono'
              //                 : 'Шрифт: Nunito',
              //           ),
              //         ],
              //       ),
              //     ),
              //     const PopupMenuDivider(),
              //     const PopupMenuItem(
              //       value: 'settings',
              //       child: Row(
              //         children: [
              //           Icon(FluentIcons.settings_24_regular, size: 20),
              //           SizedBox(width: 12),
              //           Text('Все настройки'),
              //         ],
              //       ),
              //     ),
              //   ],
              // ),
              // if (!compact)
              //   Padding(
              //     padding: const EdgeInsets.only(right: 8),
              //     child: FilledButton.tonalIcon(
              //       onPressed: _pad.stopAll,
              //       icon: const Icon(FluentIcons.stop_24_filled),
              //       label: const Text('Стоп'),
              //     ),
              //   ),
            ],
          ),
          floatingActionButton: compact
              ? FloatingActionButton(
                  onPressed: _add,
                  tooltip: 'Добавить звуки',
                  child: const Icon(FluentIcons.add_24_filled),
                )
              : FloatingActionButton.extended(
                  onPressed: _add,
                  icon: const Icon(FluentIcons.add_24_filled),
                  label: const Text('Добавить звуки'),
                ),
          body: _pad.loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      // padding: EdgeInsets.fromLTRB(
                      //   compact ? 16 : 28,
                      //   8,
                      //   compact ? 16 : 28,
                      //   8,
                      // ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SearchBar(
                              controller: _search,
                              hintText: 'Поиск по названию',
                              leading: const Icon(
                                FluentIcons.search_24_regular,
                              ),
                              trailing: [
                                if (_search.text.isNotEmpty)
                                  IconButton(
                                    onPressed: () {
                                      _search.clear();
                                      _pad.setQuery('');
                                    },
                                    icon: const Icon(
                                      FluentIcons.dismiss_24_regular,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // if (compact) ...[
                          //   const SizedBox(width: 8),
                          //   IconButton.filledTonal(
                          //     tooltip: 'Остановить всё',
                          //     onPressed: _pad.stopAll,
                          //     icon: const Icon(FluentIcons.stop_24_filled),
                          //   ),
                          // ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _MasterVolumeBar(
                        value: _pad.masterVolume,
                        onChanged: _pad.setMasterVolume,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ListenableBuilder(
                        listenable: _pad.progress,
                        builder: (context, _) => _PlaybackBar(
                          activeClip: _pad.activeClip,
                          isPaused: _pad.isPaused,
                          position: _pad.position,
                          duration: _pad.duration,
                          onTogglePause: () => _pad.togglePause(),
                          onStop: _pad.stopAll,
                          onSeek: _pad.seek,
                        ),
                      ),
                    ),
                    Expanded(
                      child: sounds.isEmpty
                          ? _EmptyPad(
                              onAdd: _add,
                              onImportFolder: _importFolder,
                            )
                          : _pad.isListView
                          ? ListView.separated(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: sounds.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final clip = sounds[index];
                                return SoundTile(
                                  key: ValueKey(clip.id),
                                  clip: clip,
                                  isListTile: true,
                                  playing: _pad.isPlaying(clip.id),
                                  paused: _pad.isClipPaused(clip.id),
                                  onPlay: () => _pad.play(clip),
                                  onTogglePause: () =>
                                      _pad.togglePause(clip.id),
                                  onDelete: () => _confirmDelete(clip),
                                  onVolume: () => _editVolume(clip),
                                  onRename: () => _rename(clip),
                                );
                              },
                            )
                          : GridView.builder(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 96),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    // maxCrossAxisExtent: compact ? 180 : 220,
                                    maxCrossAxisExtent: 180,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    // childAspectRatio: compact ? 1.05 : 1.12,
                                    childAspectRatio: 1.05,
                                  ),
                              itemCount: sounds.length,
                              itemBuilder: (context, index) {
                                final clip = sounds[index];
                                return SoundTile(
                                  key: ValueKey(clip.id),
                                  clip: clip,
                                  playing: _pad.isPlaying(clip.id),
                                  paused: _pad.isClipPaused(clip.id),
                                  onPlay: () => _pad.play(clip),
                                  onTogglePause: () =>
                                      _pad.togglePause(clip.id),
                                  onDelete: () => _confirmDelete(clip),
                                  onVolume: () => _editVolume(clip),
                                  onRename: () => _rename(clip),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MasterVolumeBar extends StatelessWidget {
  const _MasterVolumeBar({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = theme.useMaterial3
        ? const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          )
        : const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLow,
        shape: shape,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: [
            Icon(
              value == 0
                  ? FluentIcons.speaker_mute_24_regular
                  : FluentIcons.speaker_2_24_filled,
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Общая громкость  ${(value * 100).round()}%',
                    style: theme.textTheme.labelLarge,
                  ),
                  Slider(
                    min: 0,
                    max: 2,
                    divisions: 40,
                    value: value,
                    label: '${(value * 100).round()}%',
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.activeClip,
    required this.isPaused,
    required this.position,
    required this.duration,
    required this.onTogglePause,
    required this.onStop,
    required this.onSeek,
  });

  final SoundClip? activeClip;
  final bool isPaused;
  final Duration position;
  final Duration duration;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;
  final ValueChanged<Duration> onSeek;

  static String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasActive = activeClip != null;
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = hasActive
        ? position.inMilliseconds.toDouble().clamp(0.0, maxMs)
        : 0.0;

    final shape = theme.useMaterial3
        ? const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          )
        : const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLow,
        shape: shape,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: hasActive
                  ? (isPaused ? 'Продолжить' : 'Пауза')
                  : 'Нет активного звука',
              onPressed: hasActive ? onTogglePause : null,
              icon: Icon(
                isPaused
                    ? FluentIcons.play_24_filled
                    : FluentIcons.pause_24_filled,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Остановить',
              onPressed: hasActive ? onStop : null,
              icon: const Icon(FluentIcons.stop_24_regular),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasActive
                            ? FluentIcons.sound_wave_circle_24_regular
                            : FluentIcons.music_note_2_24_regular,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasActive
                              ? activeClip!.name
                              : 'Ничего не воспроизводится',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDuration(hasActive ? position : Duration.zero)} / ${_formatDuration(hasActive ? duration : Duration.zero)}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0,
                    max: maxMs,
                    value: currentMs,
                    onChanged: hasActive && duration.inMilliseconds > 0
                        ? (ms) => onSeek(Duration(milliseconds: ms.round()))
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPad extends StatelessWidget {
  const _EmptyPad({required this.onAdd, required this.onImportFolder});

  final VoidCallback onAdd;
  final VoidCallback onImportFolder;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.music_note_2_24_regular,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Пока тихо',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Добавьте mp3, wav, ogg или flac — каждый звук станет кнопкой или элементом списка на панели.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(FluentIcons.add_24_filled),
                    label: const Text('Добавить звуки'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onImportFolder,
                    icon: const Icon(FluentIcons.folder_arrow_right_24_regular),
                    label: const Text('Импорт из папки'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
