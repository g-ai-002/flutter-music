import 'dart:async';
import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:just_audio/just_audio.dart';
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

/// 时长补全进度（后台任务回调用）
class DurationFillProgress {
  final int filled;
  final int total;
  final Song updatedSong;
  const DurationFillProgress({required this.filled, required this.total, required this.updatedSong});
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

    LogService.info('扫描完成: 共 ${results.length} 歌曲, 累计遍历 $scanned 个文件');
    return results;
  }

  /// 后台补全缺失的时长
  ///
  /// 扫描完成后，对 duration 为 null 的歌曲用 just_audio 异步获取时长
  /// 每获取到一个时长就通过 [onProgress] 回调通知 UI 更新
  Future<void> fillMissingDurations(
    List<Song> songs,
    void Function(DurationFillProgress) onProgress,
  ) async {
    final missingSongs = songs.where((s) => s.duration == null).toList();
    if (missingSongs.isEmpty) {
      LogService.info('所有歌曲已有时长，无需补全');
      return;
    }

    LogService.info('开始后台补全时长: 共 ${missingSongs.length} 首需要补全');
    int filled = 0;

    for (final song in missingSongs) {
      final duration = await _getDurationFromAudio(song.path);
      filled++;
      if (duration != null) {
        final updatedSong = song.copyWith(duration: duration);
        LogService.info('补全时长 (${song.fileName}): ${duration.inSeconds}s');
        onProgress(DurationFillProgress(
          filled: filled,
          total: missingSongs.length,
          updatedSong: updatedSong,
        ));
      } else {
        LogService.warning('补全时长失败 (${song.fileName})');
      }
    }

    LogService.info('时长补全完成: $filled/${missingSongs.length}');
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
    // Windows 中文路径处理：先尝试直接读取，失败再用临时文件
    // 注意：时长获取失败时不阻塞扫描，后续由 fillMissingDurations 后台补全
    String? tempPath;
    try {
      // Windows 中文路径：先尝试直接读取（audio_metadata_reader 是纯 Dart）
      if (needsAsciiPathWorkaround() && hasNonAscii(path)) {
        try {
          final meta = readMetadata(file, getImage: false);
          if (meta.title?.trim().isNotEmpty == true) title = meta.title!.trim();
          if (meta.artist?.trim().isNotEmpty == true) artist = meta.artist!.trim();
          if (meta.album?.trim().isNotEmpty == true) album = meta.album!.trim();
          duration = meta.duration;
        } catch (directError) {
          LogService.info('直接读取失败，尝试临时文件 (${p.basename(path)}): $directError');
          tempPath = await ensureAsciiPath(path);
          final meta = readMetadata(File(tempPath), getImage: false);
          if (meta.title?.trim().isNotEmpty == true) title = meta.title!.trim();
          if (meta.artist?.trim().isNotEmpty == true) artist = meta.artist!.trim();
          if (meta.album?.trim().isNotEmpty == true) album = meta.album!.trim();
          duration = meta.duration;
        }
      } else {
        // 非 Windows 或纯 ASCII 路径，直接读取
        final meta = readMetadata(file, getImage: false);
        if (meta.title?.trim().isNotEmpty == true) title = meta.title!.trim();
        if (meta.artist?.trim().isNotEmpty == true) artist = meta.artist!.trim();
        if (meta.album?.trim().isNotEmpty == true) album = meta.album!.trim();
        duration = meta.duration;
      }
    } catch (e) {
      final ext = p.extension(path);
      LogService.warning('元数据解析失败 (${p.basename(path)}): 类型=${e.runtimeType}, 扩展名=$ext, 错误=$e');
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

  /// 降级获取时长：用 just_audio 加载音频文件获取时长
  /// 用于元数据解析失败（如无 ID3 标签的 MP3）的情况
  Future<Duration?> _getDurationFromAudio(String path) async {
    final player = AudioPlayer();
    String? tempPath;
    try {
      String loadPath = path;
      // Windows 中文路径处理
      if (needsAsciiPathWorkaround() && hasNonAscii(path)) {
        tempPath = await ensureAsciiPath(path);
        loadPath = tempPath;
      }

      // 设置音频源，等待时长信息
      await player.setFilePath(loadPath, preload: true);

      // 等待时长就绪（最多 5 秒）
      final duration = await player.durationStream
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      return duration;
    } catch (e) {
      LogService.warning('just_audio 获取时长失败 (${p.basename(path)}): $e');
      return null;
    } finally {
      await player.dispose();
      if (tempPath != null) {
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }
    }
  }
}
