import 'dart:io';
import 'dart:convert';
import '../models/lyric.dart';
import 'log_service.dart';

/// LRC 歌词解析器
///
/// 支持：
/// - 多时间戳: [00:01.20][00:05.10]歌词
/// - 元信息标签: [ti:title] [ar:artist] [al:album] [by:...] [offset:...]
/// - 时间格式: [mm:ss], [mm:ss.xx], [mm:ss.xxx]
/// - UTF-8 / GBK 文件回退解码
class LyricParser {
  LyricParser._();

  static final RegExp _timeTag =
      RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final RegExp _metaTag = RegExp(r'\[([a-zA-Z]+):([^\]]*)\]');
  /// 段落标记：[Intro], [Verse 1], [Chorus] 等（不含冒号，非时间格式）
  static final RegExp _sectionTag = RegExp(r'^\[([^\]:]+)\]$');

  static Future<Lyrics> parseFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return Lyrics.empty;
      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        try {
          // 简单回退到 latin1，避免编码异常导致空歌词；
          // 中文 GBK 文件可能出现乱码，但仍可显示时间轴。
          content = latin1.decode(bytes);
        } catch (_) {
          return Lyrics.empty;
        }
      }
      return parseText(content);
    } catch (e, st) {
      LogService.error('解析歌词文件失败: $path', e, st);
      return Lyrics.empty;
    }
  }

  static Lyrics parseText(String content) {
    final tags = <String, String>{};
    final lines = <LyricLine>[];
    Duration offset = Duration.zero;

    for (final raw in const LineSplitter().convert(content)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      // 提取所有时间戳
      final times = <Duration>[];
      int lastEnd = 0;
      for (final m in _timeTag.allMatches(line)) {
        times.add(_parseTime(m));
        lastEnd = m.end;
      }

      if (times.isEmpty) {
        // 段落标记如 [Intro], [Verse 1], [Chorus] → 插入空行分隔
        if (_sectionTag.hasMatch(line)) {
          final t = lines.isNotEmpty ? lines.last.time : Duration.zero;
          lines.add(LyricLine(t, ''));
          continue;
        }
        // 元信息标签
        final metaMatches = _metaTag.allMatches(line).toList();
        for (final m in metaMatches) {
          final key = m.group(1)!.toLowerCase();
          final value = (m.group(2) ?? '').trim();
          tags[key] = value;
          if (key == 'offset') {
            final ms = int.tryParse(value);
            if (ms != null) offset = Duration(milliseconds: ms);
          }
        }
        continue;
      }

      final text = line.substring(lastEnd).trim();
      for (final t in times) {
        lines.add(LyricLine(t + offset, text));
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return Lyrics(lines: lines, tags: tags);
  }

  static Duration _parseTime(RegExpMatch m) {
    final mm = int.tryParse(m.group(1) ?? '0') ?? 0;
    final ss = int.tryParse(m.group(2) ?? '0') ?? 0;
    final frac = m.group(3);
    int ms = 0;
    if (frac != null && frac.isNotEmpty) {
      // 标准化到毫秒：'5' -> 500, '50' -> 500, '500' -> 500
      if (frac.length == 1) {
        ms = int.parse(frac) * 100;
      } else if (frac.length == 2) {
        ms = int.parse(frac) * 10;
      } else {
        ms = int.parse(frac.substring(0, 3));
      }
    }
    return Duration(minutes: mm, seconds: ss, milliseconds: ms);
  }
}
