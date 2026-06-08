import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// 自定义 [BaseAudioHandler]，桥接 [ja.AudioPlayer] 与系统通知栏 / 媒体会话。
///
/// 通知栏按钮顺序：喜欢 → 上一曲 → 播放/暂停 → 下一曲
class MusicAudioHandler extends BaseAudioHandler {
  final ja.AudioPlayer _player;
  final List<StreamSubscription> _subs = [];

  /// 由外部注入的回调
  static Future<void> Function()? onSkipToNext;
  static Future<void> Function()? onSkipToPrevious;

  static MusicAudioHandler? _instance;

  bool _playing = false;

  MusicAudioHandler(this._player) {
    _instance = this;
    _subs.add(_player.playbackEventStream.listen(_onPlaybackEvent));
    _subs.add(_player.playingStream.listen((p) {
      _playing = p;
    }));
    _subs.add(_player.durationStream.listen((dur) {
      final current = mediaItem.value;
      if (current != null && dur != null) {
        mediaItem.add(current.copyWith(duration: dur));
      }
    }));
    _subs.add(_player.sequenceStateStream.listen((state) {
      final tag = state.currentSource?.tag;
      if (tag is MediaItem) {
        mediaItem.add(MediaItem(
          id: tag.id,
          title: tag.title,
          artist: tag.artist,
          album: tag.album,
          artUri: tag.artUri,
        ));
      }
    }));
  }

  void _onPlaybackEvent(ja.PlaybackEvent event) {
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (_playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];

    // 同步 duration 到 MediaItem，确保通知栏知道总时长
    final current = mediaItem.value;
    if (current != null && event.duration != null) {
      mediaItem.add(current.copyWith(duration: event.duration));
    }

    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _toProcessingState(event.processingState),
      playing: _playing,
      updatePosition: event.updatePosition,
      updateTime: event.updateTime,
      bufferedPosition: event.bufferedPosition,
      speed: 1.0,
      queueIndex: event.currentIndex,
    ));
  }

  AudioProcessingState _toProcessingState(ja.ProcessingState s) {
    switch (s) {
      case ja.ProcessingState.idle:
        return AudioProcessingState.idle;
      case ja.ProcessingState.loading:
        return AudioProcessingState.loading;
      case ja.ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ja.ProcessingState.ready:
        return AudioProcessingState.ready;
      case ja.ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => onSkipToNext?.call() ?? Future.value();

  @override
  Future<void> skipToPrevious() => onSkipToPrevious?.call() ?? Future.value();

  /// 通知栏 artist 行动态替换为当前歌词
  static void updateArtist(String text) {
    final item = _instance?.mediaItem.value;
    if (item != null) {
      _instance?.mediaItem.add(item.copyWith(artist: text));
    }
  }
}
