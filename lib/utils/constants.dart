/// 应用全局常量
class AppConstants {
  AppConstants._();

  static const String appName = '音乐播放器';
  static const String version = '0.1.0';

  // SharedPreferences keys
  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyScanDirs = 'scan_dirs';
  static const String prefKeyLastSongPath = 'last_song_path';
  static const String prefKeyPlayMode = 'play_mode';
  static const String prefKeyVolume = 'volume';

  // 支持的音频后缀
  static const List<String> audioExtensions = [
    '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.wma', '.ape', '.opus'
  ];

  // 支持的封面文件名（同目录优先匹配）
  static const List<String> coverFileNames = [
    'cover.jpg', 'cover.png', 'cover.jpeg', 'folder.jpg', 'folder.png',
    'album.jpg', 'album.png', 'front.jpg', 'front.png'
  ];

  // 歌词扩展名
  static const String lrcExtension = '.lrc';
}
