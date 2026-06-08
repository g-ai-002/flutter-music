import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart' show MediaItem;
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
///
/// 设计上对高频信号做了拆分：
/// - 选歌 / 队列 / 歌词等"低频"变化通过 [notifyListeners] 通知整个订阅者；
/// - 播放进度 [positionListenable] / 总时长 [durationListenable]
///   / 是否在播 [playingListenable] 作为独立 ValueListenable 暴露，
///   仅由相关控件订阅，避免每次播放/暂停或 200ms 节奏触发整页重建。
class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player;
  final StorageService _storage;
  final SettingsProvider _settings;

  List<Song> _queue = const [];
  int _currentIndex = -1;

  /// 随机播放使用的洗牌索引序列：在 [PlayMode.shuffle] 下用其顺序循环遍历，
  /// 既不会马上重复同一首，也保证每首歌在一轮中只播一次。
  List<int> _shuffleOrder = const [];
  int _shufflePos = -1;

  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _playingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _currentLyricNotifier = ValueNotifier('');
  Lyrics _lyrics = Lyrics.empty;
  String? _errorMessage;

  bool _preparing = false;

  final List<StreamSubscription> _subs = [];
  late final VoidCallback _settingsListener;

  Timer? _saveTimer;

  final Random _random = Random();

  PlayerProvider(this._storage, this._settings, {AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _player.setVolume(_settings.volume);
    _settingsListener = () => _player.setVolume(_settings.volume);
    _settings.addListener(_settingsListener);

    _subs
      ..add(_player.positionStream.listen((p) {
        _position.value = p;
        _checkLyricUpdate(p);
      }))
      ..add(_player.durationStream.listen((d) => _duration.value = d ?? Duration.zero))
      ..add(_player.playingStream.listen((p) {
        if (_playingNotifier.value == p) return;
        _playingNotifier.value = p;
        notifyListeners();
      }))
      ..add(_player.processingStateStream.listen((s) {
        if (s == ProcessingState.completed) _onCompleted();
      }))
      ..add(_player.errorStream.listen((e) {
        _errorMessage = '播放失败: ${e.message}';
        LogService.error('播放器错误: ${e.code} - ${e.message}');
        notifyListeners();
      }));

    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  /// 由外部注入：每次开始播放时回调（用于"最近播放"等横切关注点）
  ///
  /// 设计上让 PlayerProvider 不直接依赖 FavoritesProvider，便于单测。
  void Function(Song song)? onSongStart;

  /// 由外部注入：当前歌词行变化时回调（用于通知栏等横切关注点）
  void Function(String lyricText)? onLyricUpdate;
  String _lastLyricText = '';

  // ---- getters ----
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get playing => _playingNotifier.value;

  /// 高频位置流，订阅者只重建控件本体
  ValueListenable<Duration> get positionListenable => _position;
  ValueListenable<Duration> get durationListenable => _duration;
  ValueListenable<bool> get playingListenable => _playingNotifier;
  ValueListenable<String> get currentLyricListenable => _currentLyricNotifier;

  /// 最近一次播放错误消息（null 表示无错误），UI 层可用 SnackBar 展示
  String? get errorMessage => _errorMessage;

  Duration get position => _position.value;
  Duration get duration => _duration.value;
  Lyrics get lyrics => _lyrics;
  PlayMode get mode => playModeFromInt(_settings.playMode);
  List<Song> get queue => _queue;

  /// 设置队列并尝试恢复上次播放歌曲（不自动开始播放）
  Future<void> setQueue(List<Song> songs, {bool resumeLast = false}) async {
    _queue = songs;
    _shuffleOrder = const [];
    _shufflePos = -1;
    if (resumeLast) {
      final lastPath = _storage.lastSongPath;
      if (lastPath != null) {
        final idx = _queue.indexWhere((s) => s.path == lastPath);
        if (idx >= 0) {
          _currentIndex = idx;
          final resumePos = Duration(milliseconds: _storage.lastPosition);
          await _prepare(_queue[idx], autoPlay: false, seekTo: resumePos);
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
      _queue = [..._queue, song];
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = idx;
    }
    // 切歌后随机序列从当前歌开始重建
    _shuffleOrder = const [];
    _shufflePos = -1;
    await _prepare(song, autoPlay: true);
  }

  Future<void> _prepare(Song song, {required bool autoPlay, Duration? seekTo}) async {
    if (_preparing) {
      LogService.warning('播放器正在加载中，忽略重复请求');
      return;
    }
    _preparing = true;
    _errorMessage = null;
    try {
      LogService.info('加载歌曲: ${song.path}');
      // 播放前校验文件是否存在
      final file = File(song.path);
      if (!await file.exists()) {
        _errorMessage = '文件不存在: ${song.path}';
        LogService.warning(_errorMessage!);
        notifyListeners();
        return;
      }
      final mediaItem = MediaItem(
        id: song.path,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.coverPath != null ? Uri.file(song.coverPath!) : null,
      );
      LogService.info('创建 AudioSource: ${song.path}');
      LogService.info('调用 setFilePath...');
      await _player.setFilePath(song.path,
        tag: mediaItem,
        initialPosition: seekTo ?? Duration.zero,
        preload: true,
      );
      LogService.info('setFilePath 完成');
      await _storage.setLastSongPath(song.path);
      _lyrics = song.lyricPath != null
          ? await LyricParser.parseFile(song.lyricPath!)
          : Lyrics.empty;
      _lastLyricText = '';
      _currentLyricNotifier.value = '';
      // 等待播放器就绪，最多等 30 秒
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.ready || s == ProcessingState.completed,
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        LogService.warning('播放器就绪超时: ${song.path}');
        return _player.processingState;
      });
      if (autoPlay) await _player.play();
      onSongStart?.call(song);
      notifyListeners();
    } catch (e, st) {
      _errorMessage = '加载失败: $e';
      LogService.error('加载歌曲失败: ${song.path}', e, st);
      notifyListeners();
    } finally {
      _preparing = false;
    }
  }

  Future<void> togglePlay() async {
    if (currentSong == null) return;
    if (playing) {
      _saveProgress();
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration to) => _player.seek(to);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    final idx = _resolveNextIndex();
    _currentIndex = idx;
    await _prepare(_queue[idx], autoPlay: true);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    final prev = _currentIndex <= 0 ? _queue.length - 1 : _currentIndex - 1;
    _currentIndex = prev;
    await _prepare(_queue[prev], autoPlay: true);
  }

  int _resolveNextIndex() {
    if (mode == PlayMode.shuffle) {
      if (_queue.length == 1) return 0;
      if (_shuffleOrder.length != _queue.length) _rebuildShuffleOrder();
      _shufflePos++;
      if (_shufflePos >= _shuffleOrder.length) {
        // 一轮播完，洗一轮新顺序
        _rebuildShuffleOrder();
        _shufflePos = 0;
      }
      return _shuffleOrder[_shufflePos];
    }
    return (_currentIndex + 1) % _queue.length;
  }

  /// Fisher-Yates 洗牌生成下一轮播放顺序；当前歌曲放到序列开头保证不重复
  void _rebuildShuffleOrder() {
    final order = List<int>.generate(_queue.length, (i) => i);
    for (var i = order.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = order[i];
      order[i] = order[j];
      order[j] = tmp;
    }
    if (_currentIndex >= 0) {
      order.remove(_currentIndex);
      order.insert(0, _currentIndex);
    }
    _shuffleOrder = order;
    _shufflePos = 0; // 0 是当前歌，后续 next() 才会前进
  }

  void _checkLyricUpdate(Duration pos) {
    if (_lyrics.isEmpty) return;
    final idx = _lyrics.indexAt(pos);
    if (idx < 0) return;
    final text = _lyrics.lines[idx].text;
    if (text.isEmpty || text == _lastLyricText) return;
    _lastLyricText = text;
    _currentLyricNotifier.value = text;
    onLyricUpdate?.call(text);
  }

  void _onCompleted() {
    if (mode == PlayMode.single) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      next();
    }
  }

  Future<void> setMode(PlayMode mode) async {
    await _settings.setPlayMode(mode.index);
    if (mode != PlayMode.shuffle) {
      _shuffleOrder = const [];
      _shufflePos = -1;
    }
    notifyListeners();
  }

  void _saveProgress() {
    final song = currentSong;
    if (song != null && playing) {
      _storage.setLastPosition(_position.value.inMilliseconds);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    _settings.removeListener(_settingsListener);
    for (final s in _subs) {
      s.cancel();
    }
    _position.dispose();
    _duration.dispose();
    _playingNotifier.dispose();
    _currentLyricNotifier.dispose();
    _player.dispose();
    super.dispose();
  }
}
