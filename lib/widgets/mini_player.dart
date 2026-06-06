import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/player_page.dart';
import '../providers/player_provider.dart';
import 'cover_image.dart';

/// 底部迷你播放器（点击进入大播放器）
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();
        return Material(
          color: theme.colorScheme.surface,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerPage()),
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
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '上一首',
                          icon: const Icon(Icons.skip_previous),
                          onPressed: player.previous,
                        ),
                        IconButton(
                          tooltip: player.playing ? '暂停' : '播放',
                          iconSize: 32,
                          icon: Icon(
                            player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: player.togglePlay,
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

/// 高频进度条单独订阅，避免 200ms 节奏触发整个 MiniPlayer 重建
class _MiniProgressBar extends StatelessWidget {
  final PlayerProvider player;
  const _MiniProgressBar({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<Duration>(
      valueListenable: player.durationListenable,
      builder: (context, dur, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: player.positionListenable,
          builder: (context, pos, __) {
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
      },
    );
  }
}
