import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../models/sound_clip.dart';

class SoundTile extends StatelessWidget {
  const SoundTile({
    super.key,
    required this.clip,
    required this.playing,
    this.paused = false,
    this.isListTile = false,
    required this.onPlay,
    this.onTogglePause,
    required this.onDelete,
    required this.onVolume,
    required this.onRename,
  });

  final SoundClip clip;
  final bool playing;
  final bool paused;
  final bool isListTile;
  final VoidCallback onPlay;
  final VoidCallback? onTogglePause;
  final VoidCallback onDelete;
  final VoidCallback onVolume;
  final VoidCallback onRename;

  Widget _buildPopupMenu(Color foregroundColor) {
    return PopupMenuButton<String>(
      tooltip: 'Действия',
      onSelected: (value) {
        switch (value) {
          case 'play':
            onPlay();
          case 'pause':
            onTogglePause?.call();
          case 'volume':
            onVolume();
          case 'rename':
            onRename();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'play',
          child: Row(
            children: [
              const Icon(FluentIcons.play_24_regular, size: 20),
              const SizedBox(width: 12),
              const Text('Воспроизвести'),
            ],
          ),
        ),
        if (playing && onTogglePause != null)
          PopupMenuItem(
            value: 'pause',
            child: Row(
              children: [
                Icon(
                  paused
                      ? FluentIcons.play_circle_24_regular
                      : FluentIcons.pause_24_regular,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(paused ? 'Продолжить' : 'Пауза'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'volume',
          child: Row(
            children: [
              Icon(FluentIcons.speaker_2_24_regular, size: 20),
              SizedBox(width: 12),
              Text('Громкость'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(FluentIcons.edit_24_regular, size: 20),
              SizedBox(width: 12),
              Text('Переименовать'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(FluentIcons.delete_24_regular, size: 20),
              SizedBox(width: 12),
              Text('Удалить'),
            ],
          ),
        ),
      ],
      icon: Icon(
        FluentIcons.more_vertical_24_regular,
        color: foregroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final useM3 = theme.useMaterial3;
    final palette = <(Color, Color)>[
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.surfaceContainerHighest, scheme.onSurface),
      (scheme.inversePrimary, scheme.onPrimary),
      (scheme.primary.withValues(alpha: 0.18), scheme.primary),
      (scheme.secondary.withValues(alpha: 0.18), scheme.secondary),
      (scheme.tertiary.withValues(alpha: 0.22), scheme.tertiary),
    ];
    final colors = palette[clip.colorIndex % palette.length];
    final bgColor = playing ? scheme.primary : colors.$1;
    final fgColor = playing ? scheme.onPrimary : colors.$2;

    final statusIcon = playing
        ? (paused
            ? FluentIcons.pause_24_filled
            : FluentIcons.sound_wave_circle_24_filled)
        : FluentIcons.play_24_filled;

    final shape = useM3
        ? RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(isListTile ? 20 : 28),
            ),
          )
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(isListTile ? 10 : 12),
            ),
          );

    if (isListTile) {
      return Material(
        color: bgColor,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onPlay,
          onLongPress: onVolume,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(
            statusIcon,
            color: fgColor,
            size: 28,
          ),
          title: Text(
            clip.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'Громкость: ${(clip.volume * 100).round()}%${playing ? (paused ? ' • Пауза' : ' • Играет') : ''}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: fgColor.withValues(alpha: 0.8),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playing && onTogglePause != null)
                IconButton(
                  tooltip: paused ? 'Продолжить' : 'Пауза',
                  onPressed: onTogglePause,
                  icon: Icon(
                    paused
                        ? FluentIcons.play_24_filled
                        : FluentIcons.pause_24_filled,
                    color: fgColor,
                  ),
                ),
              _buildPopupMenu(fgColor),
            ],
          ),
        ),
      );
    }

    return Material(
      color: bgColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        onLongPress: onVolume,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: fgColor,
                    size: 28,
                  ),
                  const Spacer(),
                  if (playing && onTogglePause != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: paused ? 'Продолжить' : 'Пауза',
                      onPressed: onTogglePause,
                      icon: Icon(
                        paused
                            ? FluentIcons.play_24_filled
                            : FluentIcons.pause_24_filled,
                        color: fgColor,
                        size: 20,
                      ),
                    ),
                  _buildPopupMenu(fgColor),
                ],
              ),
              const Spacer(),
              Text(
                clip.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(clip.volume * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: playing
                      ? scheme.onPrimary.withValues(alpha: 0.8)
                      : colors.$2.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
