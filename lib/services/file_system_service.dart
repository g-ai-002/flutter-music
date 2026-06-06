import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// 文件系统辅助：解析日志目录、平台默认音乐目录、打开目录等
class FileSystemService {
  FileSystemService._();
  static final FileSystemService instance = FileSystemService._();

  Directory? _logRoot;
  Directory? _userRoot;

  /// 用户根目录（用户可见、跨平台一致：Documents/FlutterMusic）
  Future<Directory> getUserRoot() async {
    if (_userRoot != null) return _userRoot!;
    Directory base;
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      base = ext ?? await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final root = Directory('${base.path}${Platform.pathSeparator}FlutterMusic');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _userRoot = root;
    return root;
  }

  /// 日志目录（用户目录下 logs/）
  Future<Directory> getLogRoot() async {
    if (_logRoot != null) return _logRoot!;
    final user = await getUserRoot();
    final logDir = Directory('${user.path}${Platform.pathSeparator}logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logRoot = logDir;
    return logDir;
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

  /// 打开目录（仅桌面端有效）
  Future<bool> openDirectory(String dirPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dirPath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [dirPath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dirPath]);
        return true;
      }
    } catch (e) {
      LogService.error('打开目录失败: $dirPath', e);
    }
    return false;
  }
}
