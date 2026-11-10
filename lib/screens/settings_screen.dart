import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../controllers/sound_pad_controller.dart';
import '../services/audio_engine.dart';
import '../services/sound_store.dart';

Color deviceStatusColor(AudioDeviceStatus status) {
  switch (status) {
    case AudioDeviceStatus.good:
      return const Color(0xFF2E7D32); // Зелёный (хорошее/активно)
    case AudioDeviceStatus.warning:
      return const Color(0xFFED6C02); // Жёлтый/оранжевый (по умолчанию)
    case AudioDeviceStatus.error:
      return const Color(0xFFD32F2F); // Красный (ошибка)
  }
}

class DeviceStatusBanner extends StatelessWidget {
  const DeviceStatusBanner({
    super.key,
    required this.status,
    required this.errorText,
  });

  final AudioDeviceStatus status;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final statusColor = deviceStatusColor(status);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  errorText ?? status.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.pad,
    required this.onOpenPicker,
    required this.onAddFiles,
    required this.onImportFolder,
    required this.onExportAll,
  });

  final SoundPadController pad;
  final VoidCallback onOpenPicker;
  final VoidCallback onAddFiles;
  final VoidCallback onImportFolder;
  final VoidCallback onExportAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainer,
      body: ListenableBuilder(
        listenable: pad,
        builder: (context, _) {
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                backgroundColor: scheme.surfaceContainer,
                title: const Text('Настройки'),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    const _SectionLabel('Воспроизведение'),
                    _Group(
                      children: [
                        _SwitchRow(
                          icon: FluentIcons.layer_24_filled,
                          title: 'Наложение звука',
                          subtitle:
                              'Нажимайте на звук много раз, чтобы накладывать дорожки',
                          value: pad.allowOverlap,
                          onChanged: pad.setAllowOverlap,
                        ),
                        _SwitchRow(
                          icon: FluentIcons.mic_off_24_filled,
                          title: 'Отключать микрофон при воспроизведении',
                          subtitle: pad.canMuteMicrophone
                              ? 'Микрофон по умолчанию выключается, пока играет звук'
                              : 'Доступно только в Windows',
                          value: pad.canMuteMicrophone &&
                              pad.muteMicWhilePlaying,
                          onChanged: pad.canMuteMicrophone
                              ? pad.setMuteMicWhilePlaying
                              : null,
                        ),
                      ],
                    ),
                    const _SectionLabel('Внешний вид'),
                    _Group(
                      children: [
                        _ChoiceRow<bool>(
                          icon: FluentIcons.grid_24_filled,
                          title: 'Вид панели',
                          value: pad.isListView,
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(FluentIcons.grid_24_regular),
                              label: Text('Сетка'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(FluentIcons.apps_list_24_regular),
                              label: Text('Список'),
                            ),
                          ],
                          onChanged: pad.setIsListView,
                        ),
                        _ChoiceRow<AppFontFamily>(
                          icon: FluentIcons.text_font_24_filled,
                          title: 'Шрифт интерфейса',
                          value: pad.fontFamily,
                          segments: const [
                            ButtonSegment(
                              value: AppFontFamily.nunito,
                              label: Text('Nunito'),
                            ),
                            ButtonSegment(
                              value: AppFontFamily.jetBrainsMono,
                              label: Text('JetBrains Mono'),
                            ),
                          ],
                          onChanged: pad.setFontFamily,
                        ),
                      ],
                    ),
                    const _SectionLabel('Аудиоустройство'),
                    _DeviceCard(pad: pad, onOpenPicker: onOpenPicker),
                    const SizedBox(height: 2),
                    _Group(
                      children: [
                        _SwitchRow(
                          icon: FluentIcons.headphones_24_filled,
                          title: 'Слышать звук локально',
                          subtitle: pad.canMonitor
                              ? 'Звук дополнительно выводится на устройство Windows по умолчанию'
                              : 'Доступно при выборе конкретного устройства вывода',
                          value: pad.canMonitor && pad.monitorEnabled,
                          onChanged: pad.canMonitor
                              ? pad.setMonitorEnabled
                              : null,
                        ),
                      ],
                    ),
                    const _SectionLabel('Библиотека звуков'),
                    _Group(
                      children: [
                        _ActionRow(
                          icon: FluentIcons.add_24_filled,
                          title: 'Выбрать звуковые файлы',
                          subtitle: 'Добавить один или несколько файлов',
                          onTap: () => _run(context, onAddFiles),
                        ),
                        _ActionRow(
                          icon: FluentIcons.folder_arrow_right_24_filled,
                          title: 'Импортировать папку со звуками',
                          subtitle: 'Из экспортированной или обычной папки',
                          onTap: () => _run(context, onImportFolder),
                        ),
                        _ActionRow(
                          icon: FluentIcons.arrow_export_up_24_filled,
                          title: 'Экспортировать все звуки',
                          subtitle: 'Сохранить папку со всеми звуками',
                          onTap: () => _run(context, onExportAll),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _run(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Группа карточек: крупные внешние углы и малые внутренние,
/// с узким зазором между элементами (Material 3 Expressive).
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerLowest;
    const outer = Radius.circular(28);
    const inner = Radius.circular(8);
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          Material(
            color: color,
            clipBehavior: Clip.antiAlias,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? outer : inner,
                bottom: i == children.length - 1 ? outer : inner,
              ),
            ),
            child: children[i],
          ),
        ],
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.color, this.enabled = true});

  final IconData icon;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primaryContainer;
    return Container(
      width: 44,
      height: 44,
      decoration: ShapeDecoration(
        color: enabled ? bg : scheme.surfaceContainerHighest,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      child: Icon(
        icon,
        size: 22,
        color: enabled
            ? scheme.onPrimaryContainer
            : scheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, this.subtitle, this.enabled = true});

  final String title;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: enabled
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            _IconBadge(icon: icon, enabled: enabled),
            const SizedBox(width: 14),
            Expanded(
              child: _RowText(
                title: title,
                subtitle: subtitle,
                enabled: enabled,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              thumbIcon: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Icon(Icons.check)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<ButtonSegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon),
              const SizedBox(width: 14),
              Expanded(child: _RowText(title: title)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: segments,
              selected: {value},
              onSelectionChanged: (set) => onChanged(set.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: scheme.secondaryContainer),
            const SizedBox(width: 14),
            Expanded(child: _RowText(title: title, subtitle: subtitle)),
            Icon(
              FluentIcons.chevron_right_24_regular,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.pad, required this.onOpenPicker});

  final SoundPadController pad;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deviceName = pad.currentDevice?.name ?? 'По умолчанию (Системное)';
    final statusColor = deviceStatusColor(pad.deviceStatus);

    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
          bottom: Radius.circular(8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(
                  icon: FluentIcons.speaker_2_24_filled,
                  color: statusColor.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _RowText(
                    title: deviceName,
                    subtitle: 'Устройство вывода звука',
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить устройства',
                  onPressed: pad.refreshDevices,
                  icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DeviceStatusBanner(
              status: pad.deviceStatus,
              errorText: pad.deviceError,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onOpenPicker,
              icon: const Icon(FluentIcons.speaker_settings_24_regular),
              label: const Text('Выбрать другое устройство'),
            ),
          ],
        ),
      ),
    );
  }
}
