import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/player_page.dart';
import '../providers/player_provider.dart';
import 'cover_image.dart';
import 'player_listenables.dart';

/// 底部迷你播放器（点击进入大播放器）
///
/// 设计上把高频信号都下沉到子组件订阅，避免外层每次进度推进都重建整栏：
/// - 进度条订阅 [PlayerProvider.positionListenable]+[durationListenable]
/// - 播放/暂停图标订阅 [PlayerProvider.playingListenable]
/// - 仅在切歌时通过 [Selector] 重建标题/封面
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<PlayerProvider, Object?>(
      // 仅在切歌 / 队列变化（影响 currentSong）时重建
      selector: (_, p) => p.currentSong?.path,
      builder: (context, _, _) {
        final player = context.read<PlayerProvider>();
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        return Material(
          color: theme.colorScheme.surface,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              _SlideUpRoute(builder: (_) => const PlayerPage()),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniProgressBar(player: player),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        CoverImage(song: song, size: 44, radius: 6),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ValueListenableBuilder<String>(
                                valueListenable: player.currentLyricListenable,
                                builder: (context, lyric, _) => Text(
                                  lyric.isNotEmpty ? lyric : song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '上一首',
                          icon: const Icon(Icons.skip_previous),
                          onPressed: player.previous,
                        ),
                        PlayingStateBuilder(
                          player: player,
                          builder: (context, playing, _) => IconButton(
                            tooltip: playing ? '暂停' : '播放',
                            iconSize: 32,
                            icon: Icon(
                              playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: player.togglePlay,
                          ),
                        ),
                        IconButton(
                          tooltip: '下一首',
                          icon: const Icon(Icons.skip_next),
                          onPressed: player.next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final PlayerProvider player;
  const _MiniProgressBar({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlayerPositionBuilder(
      player: player,
      builder: (context, pos, dur) {
        final dms = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
        final value = (pos.inMilliseconds.clamp(0, dms)) / dms;
        return SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: value.toDouble(),
            minHeight: 2,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        );
      },
    );
  }
}

/// 纵向滑动路由：进入时从下向上滑入，返回时从上向下滑出
class _SlideUpRoute extends PageRouteBuilder {
  _SlideUpRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}
