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
import '../utils/constants.dart';
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
  int _prepareGeneration = 0;
  final List<String> _tempFiles = [];

  /// 防抖定时器：用户停止切歌 1 秒后才真正加载目标歌曲
  Timer? _debounceTimer;

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
        if (!_preparing) {
          // 非加载阶段的错误（如已取消的旧加载），静默忽略
          LogService.warning('忽略非加载阶段的播放器错误: ${e.code} - ${e.message}');
          return;
        }
        _preparing = false;
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

  /// UI 展示错误后调用，避免同一条错误重复弹出
  void clearError() {
    _errorMessage = null;
  }

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
    _saveProgress();
    // 必须在 pause 之前启动防抖定时器，防止 pause 等待期间
    // _onCompleted 触发时因定时器未激活而误跳到下一首
    _scheduleDebouncedLoad(song, autoPlay: true);
    await _player.pause();
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
    _errorMessage = null;
    _lyrics = Lyrics.empty;
    _lastLyricText = '';
    _currentLyricNotifier.value = '';
    _position.value = Duration.zero;
    _duration.value = song.duration ?? Duration.zero;
    notifyListeners();
  }

  /// 防抖调度：用户停止切歌 [debounceDuration] 后才真正加载
  /// 在此期间若再次切歌，则取消前一次调度，重新计时
  void _scheduleDebouncedLoad(Song song, {required bool autoPlay}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      _prepare(song, autoPlay: autoPlay);
    });
  }

  Future<void> _prepare(Song song, {required bool autoPlay, Duration? seekTo}) async {
    // 取消正在进行的加载，避免旧请求阻塞新请求
    if (_preparing) {
      LogService.warning('播放器正在加载中，取消当前加载并开始新的请求');
      _prepareGeneration++;
      try {
        await _player.stop();
      } catch (_) {
        // stop 可能因播放器状态异常而失败，忽略
      }
    }
    _preparing = true;
    _errorMessage = null;
    _prepareGeneration++;
    final gen = _prepareGeneration;

    Timer? watchdog;
    watchdog = Timer(const Duration(seconds: 20), () {
      if (_prepareGeneration == gen && _preparing && !playing) {
        _errorMessage = '加载超时，请重试';
        LogService.error('播放器加载超时: ${song.path}');
        notifyListeners();
        _preparing = false;
      }
    });
    try {
      LogService.info('加载歌曲: ${song.path}');
      final file = File(song.path);
      if (!await file.exists()) {
        if (_prepareGeneration != gen) return;
        _errorMessage = '文件不存在: ${song.path}';
        LogService.warning(_errorMessage!);
        notifyListeners();
        return;
      }
      if (_prepareGeneration != gen) return;

      final mediaItem = MediaItem(
        id: song.path,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.coverPath != null ? Uri.file(song.coverPath!) : null,
      );
      await _loadAudio(song.path, mediaItem, seekTo);
      if (_prepareGeneration != gen) return;

      await _storage.setLastSongPath(song.path);
      _lyrics = song.lyricPath != null
          ? await LyricParser.parseFile(song.lyricPath!)
          : Lyrics.empty;
      _lastLyricText = '';
      _currentLyricNotifier.value = '';

      if (_prepareGeneration != gen) return;
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.ready || s == ProcessingState.completed,
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        LogService.warning('播放器就绪超时: ${song.path}');
        return _player.processingState;
      });

      if (_prepareGeneration != gen) return;
      if (autoPlay) await _player.play();
      onSongStart?.call(song);
      _errorMessage = null;
      notifyListeners();
    } catch (e, st) {
      if (_prepareGeneration != gen) return;
      _errorMessage = '加载失败: $e';
      LogService.error('加载歌曲失败: ${song.path}', e, st);
      notifyListeners();
    } finally {
      if (_prepareGeneration == gen) {
        watchdog.cancel();
        _preparing = false;
      } else {
        // 旧世代的 finally，只清理 watchdog，不修改 _preparing
        watchdog.cancel();
        LogService.warning('忽略已废弃加载的结束: ${song.path}');
      }
    }
  }

  Future<void> _loadAudio(String path, MediaItem mediaItem, Duration? seekTo) async {
    LogService.info('创建 AudioSource: $path');
    LogService.info('调用 setFilePath...');

    // 仅在 Windows 平台检测中文路径，避免等待超时
    // Android/iOS/macOS/Linux 本身支持 UTF-8 路径，无需此方案
    String actualPath = path;
    if (needsAsciiPathWorkaround() && hasNonAscii(path)) {
      LogService.info('路径含非 ASCII 字符，创建临时文件...');
      final tempPath = await ensureAsciiPath(path);
      _tempFiles.add(tempPath);
      actualPath = tempPath;
      LogService.info('临时文件已创建: $tempPath');
    }

    try {
      await _player.setFilePath(actualPath,
        tag: mediaItem,
        initialPosition: seekTo ?? Duration.zero,
        preload: true,
      ).timeout(const Duration(seconds: 10));
      LogService.info('setFilePath 完成');
      return;
    } on TimeoutException {
      LogService.warning('setFilePath 超时: $path');
    }
    // 如果主路径失败且未使用过临时文件，再尝试创建（仅 Windows）
    if (actualPath == path && needsAsciiPathWorkaround()) {
      final tempPath = await ensureAsciiPath(path);
      _tempFiles.add(tempPath);
      await _player.setFilePath(tempPath,
        tag: mediaItem,
        initialPosition: seekTo ?? Duration.zero,
        preload: true,
      ).timeout(const Duration(seconds: 10));
      LogService.info('临时文件加载完成: $tempPath');
      return;
    }
    throw TimeoutException('无法加载: $path');
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
    _saveProgress();
    final idx = _resolveNextIndex();
    // 必须在 pause 之前启动防抖定时器，防止 pause 等待期间
    // _onCompleted 触发时因定时器未激活而误跳到下一首
    _scheduleDebouncedLoad(_queue[idx], autoPlay: true);
    await _player.pause();
    _currentIndex = idx;
    _errorMessage = null;
    _lyrics = Lyrics.empty;
    _lastLyricText = '';
    _currentLyricNotifier.value = '';
    _position.value = Duration.zero;
    _duration.value = _queue[idx].duration ?? Duration.zero;
    notifyListeners();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    _saveProgress();
    final prev = _currentIndex <= 0 ? _queue.length - 1 : _currentIndex - 1;
    // 必须在 pause 之前启动防抖定时器，防止 pause 等待期间
    // _onCompleted 触发时因定时器未激活而误跳到下一首
    _scheduleDebouncedLoad(_queue[prev], autoPlay: true);
    await _player.pause();
    _currentIndex = prev;
    _errorMessage = null;
    _lyrics = Lyrics.empty;
    _lastLyricText = '';
    _currentLyricNotifier.value = '';
    _position.value = Duration.zero;
    _duration.value = _queue[prev].duration ?? Duration.zero;
    notifyListeners();
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
      // 用户正在防抖切歌中，忽略自然完成事件
      if (_debounceTimer?.isActive == true) return;
      // 正在加载中（可能由上一次 _onCompleted 触发），静默跳过
      if (_preparing) return;
      if (_queue.isEmpty) return;
      final idx = _resolveNextIndex();
      _currentIndex = idx;
      _errorMessage = null;
      _lyrics = Lyrics.empty;
      _lastLyricText = '';
      _currentLyricNotifier.value = '';
      _position.value = Duration.zero;
      _duration.value = _queue[idx].duration ?? Duration.zero;
      notifyListeners();
      _prepare(_queue[idx], autoPlay: true);
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
    _debounceTimer?.cancel();
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
    for (final f in _tempFiles) {
      try { File(f).deleteSync(); } catch (_) {}
    }
    _tempFiles.clear();
    super.dispose();
  }
}
