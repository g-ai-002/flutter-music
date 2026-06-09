import 'dart:async';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 扫描结果（流式回调用）
class ScanProgress {
  final int scanned;
  final int found;
  final String currentDir;
  const ScanProgress({required this.scanned, required this.found, required this.currentDir});
}

/// 音乐扫描器：递归遍历指定目录，提取元数据，匹配同目录封面 / 同名歌词
class MusicScanner {
  MusicScanner._();
  static final MusicScanner instance = MusicScanner._();

  /// 扫描多个根目录
  ///
  /// [onProgress] 可选进度回调（节流到每 50 个文件一次）
  Future<List<Song>> scanDirs(
    List<String> rootDirs, {
    void Function(ScanProgress)? onProgress,
  }) async {
    final results = <Song>[];
    final seenPaths = <String>{};
    int scanned = 0;

    for (final root in rootDirs) {
      final dir = Directory(root);
      if (!await dir.exists()) {
        LogService.warning('扫描目录不存在: $root');
        continue;
      }
      LogService.info('开始扫描目录: $root');

      // 按目录缓存封面，减少重复查找
      final coverCache = <String, String?>{};

      await for (final entity in dir.list(recursive: true, followLinks: false).handleError((e) {
        LogService.warning('遍历异常: $e');
      })) {
        if (entity is! File) continue;
        scanned++;
        final ext = p.extension(entity.path).toLowerCase();
        if (!AppConstants.audioExtensions.contains(ext)) {
          if (scanned % 200 == 0 && onProgress != null) {
            onProgress(ScanProgress(scanned: scanned, found: results.length, currentDir: p.dirname(entity.path)));
          }
          continue;
        }
        if (seenPaths.contains(entity.path)) continue;
        seenPaths.add(entity.path);

        final song = await _buildSong(entity, coverCache);
        results.add(song);

        if (results.length % 25 == 0 && onProgress != null) {
          onProgress(ScanProgress(
            scanned: scanned,
            found: results.length,
            currentDir: p.dirname(entity.path),
          ));
        }
      }
    }

    LogService.info('扫描完成: 共 ${results.length} 首歌曲, 累计遍历 $scanned 个文件');
    return results;
  }

  Future<Song> _buildSong(File file, Map<String, String?> coverCache) async {
    final path = file.path;
    final dir = p.dirname(path);

    String title = Song.titleFromPath(path);
    String artist = '未知艺术家';
    String album = '未知专辑';
    Duration? duration;
    int fileSize = 0;
    try {
      fileSize = await file.length();
    } catch (_) {}

    // 元数据读取（失败时降级使用文件名）
    // 对于中文路径，先复制到临时文件再读取
    String? tempPath;
    File metaFile = file;
    try {
      if (hasNonAscii(path)) {
        tempPath = await ensureAsciiPath(path);
        metaFile = File(tempPath);
      }
      final meta = readMetadata(metaFile, getImage: false);
      if (meta.title?.trim().isNotEmpty == true) title = meta.title!.trim();
      if (meta.artist?.trim().isNotEmpty == true) artist = meta.artist!.trim();
      if (meta.album?.trim().isNotEmpty == true) album = meta.album!.trim();
      duration = meta.duration;
    } catch (e) {
      LogService.warning('读取元数据失败 (${p.basename(path)}): $e');
    } finally {
      // 及时清理临时文件
      if (tempPath != null) {
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }
    }

    // 同目录封面（优先同名图片，再按预定义文件名匹配）
    final coverPath = await _resolveCover(path, dir, coverCache);

    // 同名 .lrc
    final lrc = Song.lrcPathFor(path);
    final lyricPath = await File(lrc).exists() ? lrc : null;

    return Song(
      path: path,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      coverPath: coverPath,
      lyricPath: lyricPath,
      fileSize: fileSize,
    );
  }

  Future<String?> _resolveCover(String audioPath, String dir, Map<String, String?> cache) async {
    // 1. 同名图片：song.flac → song.jpg / song.png / ...（不缓存，每首独立）
    final audioName = p.basenameWithoutExtension(audioPath);
    for (final ext in AppConstants.coverSameNameExts) {
      final candidate = p.join(dir, '$audioName$ext');
      if (await File(candidate).exists()) return candidate;
    }

    // 2. 目录级封面缓存（预定义文件名：cover.jpg / folder.jpg / ...）
    if (cache.containsKey(dir)) return cache[dir];
    String? found;

    for (final name in AppConstants.coverFileNames) {
      final candidate = p.join(dir, name);
      if (await File(candidate).exists()) {
        found = candidate;
        break;
      }
    }

    // 大小写不敏感兜底：只在常见命名失败时再尝试列目录
    if (found == null) {
      try {
        await for (final e in Directory(dir).list(followLinks: false)) {
          if (e is! File) continue;
          final name = p.basename(e.path).toLowerCase();
          if (AppConstants.coverFileNames.contains(name)) {
            found = e.path;
            break;
          }
        }
      } catch (_) {}
    }
    cache[dir] = found;
    return found;
  }
}
