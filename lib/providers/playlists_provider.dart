import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../services/storage_service.dart';

/// 用户自建歌单的状态管理
///
/// 歌单以歌曲绝对路径为引用，与 FavoritesProvider 一致：
/// 即使歌曲库重新扫描后，歌单本身的引用仍然保留。
/// 渲染时由调用方按当前歌曲库做一次过滤。
class PlaylistsProvider extends ChangeNotifier {
  final StorageService _storage;
  late List<Playlist> _items;

  PlaylistsProvider(this._storage) {
    _items = List<Playlist>.from(_storage.loadPlaylists());
  }

  List<Playlist> get items => List.unmodifiable(_items);
  int get count => _items.length;

  Playlist? byId(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _nameTaken(String name, {String? exceptId}) {
    final n = name.trim();
    for (final p in _items) {
      if (p.id == exceptId) continue;
      if (p.name == n) return true;
    }
    return false;
  }

  /// 创建歌单，名称重复时抛出 `ArgumentError`
  Future<Playlist> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('歌单名不能为空');
    }
    if (_nameTaken(trimmed)) {
      throw ArgumentError('歌单名已存在');
    }
    final pl = Playlist(
      id: 'pl_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
    );
    _items = [pl, ..._items];
    await _persist();
    notifyListeners();
    return pl;
  }

  Future<void> rename(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('歌单名不能为空');
    }
    if (_nameTaken(trimmed, exceptId: id)) {
      throw ArgumentError('歌单名已存在');
    }
    final pl = byId(id);
    if (pl == null) return;
    if (pl.name == trimmed) return;
    pl.name = trimmed;
    pl.updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final before = _items.length;
    _items = _items.where((p) => p.id != id).toList();
    if (_items.length == before) return;
    await _persist();
    notifyListeners();
  }

  /// 向歌单追加歌曲，去重；返回实际新增的数量
  Future<int> addSongs(String id, Iterable<String> songPaths) async {
    final pl = byId(id);
    if (pl == null) return 0;
    final existing = pl.songPaths.toSet();
    var added = 0;
    for (final path in songPaths) {
      if (existing.add(path)) {
        pl.songPaths.add(path);
        added++;
      }
    }
    if (added == 0) return 0;
    pl.updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
    return added;
  }

  Future<void> removeSong(String id, String songPath) async {
    final pl = byId(id);
    if (pl == null) return;
    final removed = pl.songPaths.remove(songPath);
    if (!removed) return;
    pl.updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> clearSongs(String id) async {
    final pl = byId(id);
    if (pl == null || pl.songPaths.isEmpty) return;
    pl.songPaths.clear();
    pl.updatedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _storage.savePlaylists(_items);
}
