import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 应用全局常量
class AppConstants {
  AppConstants._();

  static const String appName = '音乐播放器';
  static const String version = '0.3.42';

  // SharedPreferences keys (playlists 列表 JSON)
  static const String prefKeyPlaylists = 'playlists_v1';

  // SharedPreferences keys
  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyScanDirs = 'scan_dirs';
  static const String prefKeyLastSongPath = 'last_song_path';
  static const String prefKeyLastPosition = 'last_position';
  static const String prefKeyPlayMode = 'play_mode';
  static const String prefKeyVolume = 'volume';
  static const String prefKeyFavorites = 'favorites_v1';
  static const String prefKeyRecentPlays = 'recent_plays_v1';

  // 支持的音频后缀
  static const List<String> audioExtensions = [
    '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.wma', '.ape', '.opus'
  ];

  // 支持的封面文件名（同目录优先匹配）
  static const List<String> coverFileNames = [
    'cover.jpg', 'cover.png', 'cover.jpeg', 'folder.jpg', 'folder.png',
    'album.jpg', 'album.png', 'front.jpg', 'front.png'
  ];

  // 同文件名封面扩展名（优先级高于 coverFileNames）
  static const List<String> coverSameNameExts = [
    '.jpg', '.jpeg', '.png', '.webp', '.bmp'
  ];

  // 歌词扩展名
  static const String lrcExtension = '.lrc';

  // 最近播放保留条数
  static const int maxRecentPlays = 100;
}

/// 切歌防抖时长：用户停止切歌后等待此时间才真正加载音频
const Duration debounceDuration = Duration(seconds: 1);

/// 检测路径是否包含非 ASCII 字符（如中文）
bool hasNonAscii(String path) {
  return path.contains(RegExp(r'[^\x00-\x7F]'));
}

/// 判断当前平台是否需要使用临时文件处理中文路径
///
/// Windows 平台的底层库对 UTF-8 路径处理有兼容性问题，
/// Android/iOS/macOS/Linux 等平台本身支持 UTF-8，无需此方案。
bool needsAsciiPathWorkaround() {
  return Platform.isWindows;
}

/// 为非 ASCII 路径创建临时副本，返回临时文件路径；ASCII 路径或非 Windows 平台原样返回
///
/// 用于解决 Windows 上某些库（audio_metadata_reader、just_audio）
/// 无法正确处理含中文路径的问题。
Future<String> ensureAsciiPath(String sourcePath) async {
  if (!needsAsciiPathWorkaround()) return sourcePath;
  if (!hasNonAscii(sourcePath)) return sourcePath;
  final dir = await getTemporaryDirectory();
  final ext = p.extension(sourcePath);
  final tempName = 'tmp_${DateTime.now().microsecondsSinceEpoch}$ext';
  final tempPath = p.join(dir.path, tempName);
  await File(sourcePath).copy(tempPath);
  return tempPath;
}

/// 通用时长格式化：`mm:ss` 或 `h:mm:ss`
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// 规范化扫描目录路径：trim + 去末尾路径分隔符 + 平台分隔符统一
///
/// 用于避免用户重复添加同一目录的多种表示（结尾有/无斜杠等）。
String normalizeDirPath(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  // 统一为系统分隔符
  if (Platform.isWindows) {
    s = s.replaceAll('/', r'\');
  }
  s = p.normalize(s);
  // 去除末尾分隔符（保留根：'/' 或 'C:\'）
  final sep = Platform.pathSeparator;
  while (s.length > 1 && s.endsWith(sep)) {
    // 保留 'C:\' 这种根
    if (s.length == 3 && s.endsWith(':$sep')) break;
    s = s.substring(0, s.length - 1);
  }
  return s;
}
