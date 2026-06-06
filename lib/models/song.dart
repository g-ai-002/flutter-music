import 'dart:io';
import 'package:path/path.dart' as p;

/// 歌曲数据模型
class Song {
  final String path; // 绝对路径
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? coverPath; // 同目录封面文件路径（嵌入封面不存到磁盘，运行时按需读取）
  final String? lyricPath; // 同名 .lrc 文件路径
  final int fileSize;

  Song({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.coverPath,
    this.lyricPath,
    this.fileSize = 0,
  });

  String get fileName => p.basename(path);
  String get parentDir => p.dirname(path);

  /// 不依赖 ID3 的文件名标题：去掉扩展名
  static String titleFromPath(String path) {
    final base = p.basenameWithoutExtension(path);
    return base.trim().isEmpty ? p.basename(path) : base;
  }

  /// 推算同名 .lrc 路径（不验证存在性）
  static String lrcPathFor(String audioPath) {
    final dir = p.dirname(audioPath);
    final name = p.basenameWithoutExtension(audioPath);
    return p.join(dir, '$name.lrc');
  }

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverPath,
    String? lyricPath,
    int? fileSize,
  }) {
    return Song(
      path: path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverPath: coverPath ?? this.coverPath,
      lyricPath: lyricPath ?? this.lyricPath,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration?.inMilliseconds,
        'coverPath': coverPath,
        'lyricPath': lyricPath,
        'fileSize': fileSize,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        path: json['path'] as String,
        title: (json['title'] as String?) ?? titleFromPath(json['path'] as String),
        artist: (json['artist'] as String?) ?? '未知艺术家',
        album: (json['album'] as String?) ?? '未知专辑',
        duration: json['duration'] != null
            ? Duration(milliseconds: json['duration'] as int)
            : null,
        coverPath: json['coverPath'] as String?,
        lyricPath: json['lyricPath'] as String?,
        fileSize: (json['fileSize'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Song && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// 同步检查文件存在
bool fileExistsSync(String? path) {
  if (path == null || path.isEmpty) return false;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}
