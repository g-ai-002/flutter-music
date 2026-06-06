import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/log_service.dart';
import '../services/music_scanner.dart';
import '../services/storage_service.dart';

/// 歌曲库状态：列表、扫描进度
class LibraryProvider extends ChangeNotifier {
  final StorageService _storage;
  LibraryProvider(this._storage) {
    _songs = _storage.loadCachedSongs();
  }

  late List<Song> _songs;
  bool _scanning = false;
  ScanProgress? _progress;
  String _searchKeyword = '';

  List<Song> get songs => _songs;
  bool get scanning => _scanning;
  ScanProgress? get progress => _progress;
  String get searchKeyword => _searchKeyword;

  List<Song> get filtered {
    if (_searchKeyword.isEmpty) return _songs;
    final k = _searchKeyword.toLowerCase();
    return _songs.where((s) =>
      s.title.toLowerCase().contains(k) ||
      s.artist.toLowerCase().contains(k) ||
      s.album.toLowerCase().contains(k)
    ).toList();
  }

  void updateSearch(String keyword) {
    _searchKeyword = keyword.trim();
    notifyListeners();
  }

  Future<void> scan(List<String> dirs) async {
    if (_scanning) return;
    if (dirs.isEmpty) {
      _songs = const [];
      await _storage.saveCachedSongs(_songs);
      notifyListeners();
      return;
    }
    _scanning = true;
    _progress = null;
    notifyListeners();
    LogService.info('开始扫描: ${dirs.join(', ')}');
    try {
      final result = await MusicScanner.instance.scanDirs(
        dirs,
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );
      result.sort((a, b) {
        final byArtist = a.artist.compareTo(b.artist);
        if (byArtist != 0) return byArtist;
        final byAlbum = a.album.compareTo(b.album);
        if (byAlbum != 0) return byAlbum;
        return a.title.compareTo(b.title);
      });
      _songs = result;
      await _storage.saveCachedSongs(_songs);
      LogService.info('扫描完成: ${_songs.length} 首');
    } catch (e, st) {
      LogService.error('扫描失败', e, st);
    } finally {
      _scanning = false;
      _progress = null;
      notifyListeners();
    }
  }
}
