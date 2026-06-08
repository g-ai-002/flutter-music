import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../utils/constants.dart';

/// 简单存储服务封装：SharedPreferences + 缓存的歌曲列表
class StorageService {
  static Future<StorageService>? _initFuture;

  SharedPreferences? _prefs;
  bool _initialized = false;

  StorageService._();

  static Future<StorageService> get instance {
    final cached = _initFuture;
    if (cached != null) return cached;
    final f = _bootstrap();
    _initFuture = f;
    return f;
  }

  static Future<StorageService> _bootstrap() async {
    final s = StorageService._();
    await s._init();
    return s;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('StorageService 尚未初始化');
    }
    return p;
  }

  // ---- 主题 ----
  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;
  Future<void> setDarkMode(bool v) => _p.setBool(AppConstants.prefKeyDarkMode, v);

  // ---- 扫描目录 ----
  List<String> get scanDirs => _p.getStringList(AppConstants.prefKeyScanDirs) ?? const [];
  Future<void> setScanDirs(List<String> dirs) => _p.setStringList(AppConstants.prefKeyScanDirs, dirs);

  // ---- 上次播放歌曲 ----
  String? get lastSongPath => _p.getString(AppConstants.prefKeyLastSongPath);
  Future<void> setLastSongPath(String? v) async {
    if (v == null) {
      await _p.remove(AppConstants.prefKeyLastSongPath);
    } else {
      await _p.setString(AppConstants.prefKeyLastSongPath, v);
    }
  }

  // ---- 上次播放位置（毫秒）----
  int get lastPosition => _p.getInt(AppConstants.prefKeyLastPosition) ?? 0;
  Future<void> setLastPosition(int ms) => _p.setInt(AppConstants.prefKeyLastPosition, ms.clamp(0, 2147483647));

  // ---- 播放模式: 0=列表循环 1=单曲循环 2=随机 ----
  int get playMode => _p.getInt(AppConstants.prefKeyPlayMode) ?? 0;
  Future<void> setPlayMode(int v) => _p.setInt(AppConstants.prefKeyPlayMode, v);

  // ---- 音量 0.0~1.0 ----
  double get volume => (_p.getDouble(AppConstants.prefKeyVolume) ?? 1.0).clamp(0.0, 1.0);
  Future<void> setVolume(double v) => _p.setDouble(AppConstants.prefKeyVolume, v.clamp(0.0, 1.0));

  // ---- 缓存歌曲库 ----
  static const String _kSongs = 'cached_songs_v1';

  List<Song> loadCachedSongs() {
    final raw = _p.getString(_kSongs);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCachedSongs(List<Song> songs) async {
    final json = jsonEncode(songs.map((s) => s.toJson()).toList());
    await _p.setString(_kSongs, json);
  }

  // ---- 收藏（歌曲绝对路径集合）----
  List<String> get favorites => _p.getStringList(AppConstants.prefKeyFavorites) ?? const [];
  Future<void> setFavorites(List<String> paths) => _p.setStringList(AppConstants.prefKeyFavorites, paths);

  // ---- 最近播放（绝对路径列表，头部=最近）----
  List<String> get recentPlays => _p.getStringList(AppConstants.prefKeyRecentPlays) ?? const [];
  Future<void> setRecentPlays(List<String> paths) => _p.setStringList(AppConstants.prefKeyRecentPlays, paths);

  // ---- 歌单 ----
  List<Playlist> loadPlaylists() {
    final raw = _p.getString(AppConstants.prefKeyPlaylists);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final json = jsonEncode(playlists.map((p) => p.toJson()).toList());
    await _p.setString(AppConstants.prefKeyPlaylists, json);
  }
}
