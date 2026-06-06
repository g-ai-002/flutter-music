import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/lyric.dart';
import '../models/song.dart';
import '../services/log_service.dart';
import '../services/lyric_parser.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

enum PlayMode { loopAll, single, shuffle }

PlayMode playModeFromInt(int i) {
  switch (i) {
    case 1:
      return PlayMode.single;
    case 2:
      return PlayMode.shuffle;
    default:
      return PlayMode.loopAll;
  }
}

/// 音频播放状态
class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storage;
  final SettingsProvider _settings;

  /// 当前播放队列（即库内的过滤结果或全量）
  List<Song> _queue = const [];
  int _currentIndex = -1;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  Lyrics _lyrics = Lyrics.empty;

  late StreamSubscription _posSub;
  late StreamSubscription _durSub;
  late StreamSubscription _stateSub;
  late StreamSubscription _completeSub;
  late VoidCallback _settingsListener;

  final Random _random = Random();

  PlayerProvider(this._storage, this._settings) {
    _player.setVolume(_settings.volume);
    _settingsListener = () {
      _player.setVolume(_settings.volume);
    };
    _settings.addListener(_settingsListener);

    _posSub = _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durSub = _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _stateSub = _player.playingStream.listen((p) {
      _playing = p;
      notifyListeners();
    });
    _completeSub = _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        _onCompleted();
      }
    });
  }

  // ---- getters ----
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get playing => _playing;
  Duration get position => _position;
  Duration get duration => _duration;
  Lyrics get lyrics => _lyrics;
  PlayMode get mode => playModeFromInt(_settings.playMode);
  List<Song> get queue => _queue;

  /// 设置队列并尝试恢复上次播放歌曲（不自动开始播放）
  Future<void> setQueue(List<Song> songs, {bool resumeLast = false}) async {
    _queue = songs;
    if (resumeLast) {
      final lastPath = _storage.lastSongPath;
      if (lastPath != null) {
        final idx = _queue.indexWhere((s) => s.path == lastPath);
        if (idx >= 0) {
          _currentIndex = idx;
          await _prepare(_queue[idx], autoPlay: false);
        }
      }
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = -1;
    }
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    final idx = _queue.indexWhere((s) => s.path == song.path);
    if (idx < 0) {
      // 不在队列里也单独播放
      _queue = [..._queue, song];
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = idx;
    }
    await _prepare(song, autoPlay: true);
  }

  Future<void> _prepare(Song song, {required bool autoPlay}) async {
    try {
      LogService.info('加载歌曲: ${song.path}');
      await _player.setFilePath(song.path);
      await _storage.setLastSongPath(song.path);
      _lyrics = song.lyricPath != null
          ? await LyricParser.parseFile(song.lyricPath!)
          : Lyrics.empty;
      if (autoPlay) await _player.play();
      notifyListeners();
    } catch (e, st) {
      LogService.error('加载歌曲失败: ${song.path}', e, st);
    }
  }

  Future<void> togglePlay() async {
    if (currentSong == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration to) async {
    await _player.seek(to);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    final mode = this.mode;
    int next;
    if (mode == PlayMode.shuffle) {
      if (_queue.length == 1) {
        next = 0;
      } else {
        do {
          next = _random.nextInt(_queue.length);
        } while (next == _currentIndex);
      }
    } else {
      next = (_currentIndex + 1) % _queue.length;
    }
    _currentIndex = next;
    await _prepare(_queue[next], autoPlay: true);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    final prev = _currentIndex <= 0 ? _queue.length - 1 : _currentIndex - 1;
    _currentIndex = prev;
    await _prepare(_queue[prev], autoPlay: true);
  }

  void _onCompleted() {
    final mode = this.mode;
    if (mode == PlayMode.single) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      next();
    }
  }

  Future<void> setMode(PlayMode mode) async {
    await _settings.setPlayMode(mode.index);
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_settingsListener);
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _completeSub.cancel();
    _player.dispose();
    super.dispose();
  }
}
