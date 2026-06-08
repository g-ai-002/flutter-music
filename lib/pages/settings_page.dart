import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';

/// 设置页：扫描目录管理 / 主题 / 关于 / 日志
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('扫描目录'),
          const _ScanDirSection(),
          const Divider(height: 0.5),
          const _SectionHeader('外观'),
          const _DarkModeTile(),
          const Divider(height: 0.5),
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: Text('v${AppConstants.version}'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('查看日志路径'),
            subtitle: FutureBuilder<String>(
              future: LogService.getLogFilePath(),
              builder: (context, snap) =>
                  Text(snap.data ?? '加载中…', maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            trailing: const Icon(Icons.folder_outlined, size: 20),
            onTap: () async {
              final path = await LogService.getLogFilePath();
              if (path.isEmpty) return;
              await FileSystemService.instance.openDirectory(File(path).parent.path);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DarkModeTile extends StatelessWidget {
  const _DarkModeTile();
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SwitchListTile(
      title: const Text('深色模式'),
      secondary: const Icon(Icons.dark_mode_outlined),
      value: settings.darkMode,
      onChanged: (v) => settings.toggleDarkMode(v),
    );
  }
}

class _ScanDirSection extends StatelessWidget {
  const _ScanDirSection();

  Future<void> _addDir(BuildContext context) async {
    if (Platform.isAndroid) {
      // Android 13+ 需要分别申请音频和图片权限（细粒度媒体权限）
      final audioStatus = await Permission.audio.request();
      final photosStatus = await Permission.photos.request();
      if (!audioStatus.isGranted || !photosStatus.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要授予音频和图片访问权限')),
          );
        }
        return;
      }
    }
    try {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐目录',
      );
      if (selected == null || !context.mounted) return;
      final settings = context.read<SettingsProvider>();
      await settings.addScanDir(selected);
      if (!context.mounted) return;
      // 立即触发扫描
      context.read<LibraryProvider>().scan(settings.scanDirs);
    } catch (e, st) {
      LogService.error('选择目录失败', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dirs = settings.scanDirs;
    return Column(
      children: [
        if (dirs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '尚未添加任何目录',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ...dirs.map((d) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: '移除',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  await context.read<SettingsProvider>().removeScanDir(d);
                  if (context.mounted) {
                    context.read<LibraryProvider>().scan(
                          context.read<SettingsProvider>().scanDirs,
                        );
                  }
                },
              ),
            )),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('添加目录'),
          onTap: () => _addDir(context),
        ),
      ],
    );
  }
}
