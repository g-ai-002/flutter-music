import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// 收藏 / 最近播放
///
/// 都以歌曲绝对路径作为标识，独立于 LibraryProvider 的歌曲列表，
/// 这样歌曲库重新扫描后历史数据依然可用。
class FavoritesProvider extends ChangeNotifier {
  final StorageService _storage;

  late Set<String> _favorites;
  late List<String> _recent;

  FavoritesProvider(this._storage) {
    _favorites = _storage.favorites.toSet();
    _recent = List<String>.from(_storage.recentPlays);
  }

  /// 当前收藏的歌曲路径（无序集合，渲染时按歌曲库排序保持稳定）
  Set<String> get favorites => _favorites;

  /// 最近播放路径，按时间倒序（头部=最近）
  List<String> get recent => List.unmodifiable(_recent);

  bool isFavorite(String songPath) => _favorites.contains(songPath);

  Future<void> toggleFavorite(String songPath) async {
    if (_favorites.contains(songPath)) {
      _favorites.remove(songPath);
    } else {
      _favorites.add(songPath);
    }
    await _storage.setFavorites(_favorites.toList());
    notifyListeners();
  }

  Future<void> setFavorite(String songPath, bool fav) async {
    final has = _favorites.contains(songPath);
    if (fav == has) return;
    if (fav) {
      _favorites.add(songPath);
    } else {
      _favorites.remove(songPath);
    }
    await _storage.setFavorites(_favorites.toList());
    notifyListeners();
  }

  /// 记录一次播放：去重后置顶，截断到上限
  Future<void> recordPlay(String songPath) async {
    final updated = <String>[songPath];
    for (final p in _recent) {
      if (p == songPath) continue;
      updated.add(p);
      if (updated.length >= AppConstants.maxRecentPlays) break;
    }
    _recent = updated;
    await _storage.setRecentPlays(_recent);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    if (_recent.isEmpty) return;
    _recent = const [];
    await _storage.setRecentPlays(_recent);
    notifyListeners();
  }
}
