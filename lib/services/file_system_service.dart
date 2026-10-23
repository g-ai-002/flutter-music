import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// 文件系统服务：解析用户目录与日志目录、打开系统文件管理器。
class FileSystemService {
  FileSystemService._(this.appDirName);

  static final FileSystemService instance =
      FileSystemService._('FlutterMusic');

  /// 应用数据目录名（位于 Documents 或应用外部存储下）
  final String appDirName;

  Directory? _logRoot;

  Future<Directory> _baseDir() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      return ext ?? await getApplicationDocumentsDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  /// 日志根目录：<Documents 或 external>/<appDirName>/logs
  Future<Directory> getLogRoot() async {
    if (_logRoot != null) return _logRoot!;
    final base = await _baseDir();
    final logDir = Directory(
      '${base.path}${Platform.pathSeparator}$appDirName'
      '${Platform.pathSeparator}logs',
    );
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logRoot = logDir;
    return logDir;
  }

  /// 打开系统文件管理器定位到目录（桌面端），失败返回 false
  Future<bool> openDirectory(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      }
    } catch (e, stack) {
      LogService.error('打开目录失败: $path', e, stack);
    }
    return false;
  }

  Directory? _userRoot;

  /// 用户根目录（用户可见、跨平台一致：Documents/<appDirName>）
  Future<Directory> getUserRoot() async {
    if (_userRoot != null) return _userRoot!;
    final base = await _baseDir();
    final root = Directory(
      '${base.path}${Platform.pathSeparator}$appDirName',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _userRoot = root;
    return root;
  }

  /// 平台默认音乐目录候选；用于初次启动时建议
  Future<List<Directory>> getDefaultMusicDirs() async {
    final dirs = <Directory>[];
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final music = Directory('$userProfile\\Music');
          if (await music.exists()) dirs.add(music);
        }
      } else if (Platform.isAndroid) {
        const candidates = [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
        ];
        for (final p in candidates) {
          final d = Directory(p);
          if (await d.exists()) dirs.add(d);
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null) {
          final m = Directory('$home/Music');
          if (await m.exists()) dirs.add(m);
        }
      }
    } catch (e) {
      LogService.warning('解析默认音乐目录失败: $e');
    }
    return dirs;
  }
}
