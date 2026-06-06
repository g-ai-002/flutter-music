import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../providers/player_provider.dart';

/// 同时订阅 [PlayerProvider] 的进度 / 总时长，仅自身重建。
///
/// 避免外层 Consumer<PlayerProvider> 被 200ms 节奏的位置流频繁触发。
class PlayerPositionBuilder extends StatelessWidget {
  final PlayerProvider player;
  final Widget Function(BuildContext context, Duration position, Duration duration)
      builder;

  const PlayerPositionBuilder({
    super.key,
    required this.player,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: player.durationListenable,
      builder: (context, dur, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: player.positionListenable,
          builder: (context, pos, __) => builder(context, pos, dur),
        );
      },
    );
  }
}

/// 仅订阅播放/暂停状态的 builder
class PlayingStateBuilder extends StatelessWidget {
  final PlayerProvider player;
  final ValueWidgetBuilder<bool> builder;

  const PlayingStateBuilder({
    super.key,
    required this.player,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: player.playingListenable,
      builder: builder,
    );
  }
}
