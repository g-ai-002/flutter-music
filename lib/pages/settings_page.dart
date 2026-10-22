import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';

/// 设置页：扫描目录管理 / 主题 / 关于 / 日志
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _logContent = '';
  String _logDir = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadLogDir();
  }

  Future<void> _loadLogs() async {
    final logs = LogService.getRecentLogs(200);
    if (mounted) {
      setState(() => _logContent = logs.join('\n'));
    }
  }

  Future<void> _loadLogDir() async {
    try {
      final dir = await FileSystemService.instance.getLogRoot();
      if (!mounted) {
        return;
      }
      setState(() => _logDir = dir.path);
    } catch (e, stack) {
      LogService.error('读取日志目录失败', e, stack);
    }
  }

  bool get _canOpenDir =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          // 日志目录
          if (_logDir.isNotEmpty)
            _buildDirTile(
              theme,
              icon: Icons.folder_special,
              title: '日志目录',
              path: _logDir,
              hint: '出现问题时可提供此目录下日志文件',
            ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('查看日志'),
            subtitle: const Text('查看应用运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogDialog(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDirTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String path,
    required String hint,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.copy, color: theme.colorScheme.primary),
            tooltip: '复制路径',
            onPressed: () => _copyText(context, path),
          ),
          if (_canOpenDir)
            IconButton(
              icon: Icon(Icons.open_in_new, color: theme.colorScheme.primary),
              tooltip: '打开目录',
              onPressed: () async {
                final ok =
                    await FileSystemService.instance.openDirectory(path);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('当前平台不支持打开目录')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLogDialog(BuildContext context) {
    _loadLogs();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('应用日志'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _loadLogs();
                          setDialogState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: '复制全部',
                        onPressed: () => _copyText(ctx, _logContent),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _logContent.isEmpty ? '暂无日志' : _logContent,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
      final selected = await FilePicker.getDirectoryPath(
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
