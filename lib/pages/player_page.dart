import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../utils/constants.dart';
import '../widgets/cover_image.dart';
import '../widgets/favorite_toggle_button.dart';
import '../widgets/lyric_view.dart';
import '../widgets/player_listenables.dart';
import '../widgets/playlist_dialogs.dart';

/// 大播放器页（封面 + 歌词 + 控制条）
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<PlayerProvider>(
          builder: (_, p, __) {
            final s = p.currentSong;
            return Text(
              s?.title ?? '正在播放',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 720;
            return wide ? _buildWide(context) : _buildNarrow(context);
          },
        ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Consumer<PlayerProvider>(
          builder: (_, p, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AspectRatio(
              aspectRatio: 1,
              child: CoverImage(song: p.currentSong, size: 320, radius: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const _SongInfo(),
        const SizedBox(height: 4),
        const Expanded(child: LyricView()),
        const _ControlPanel(),
      ],
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Consumer<PlayerProvider>(
                  builder: (_, p, __) => AspectRatio(
                    aspectRatio: 1,
                    child: CoverImage(song: p.currentSong, size: 400, radius: 16),
                  ),
                ),
                const SizedBox(height: 16),
                const _SongInfo(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              const Expanded(child: LyricView()),
              const _ControlPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, p, __) {
        final s = p.currentSong;
        if (s == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      s.title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FavoriteToggleButton(songPath: s.path),
                  IconButton(
                    tooltip: '添加到歌单',
                    icon: const Icon(Icons.playlist_add),
                    onPressed: () => showAddToPlaylistSheet(
                      context,
                      songPaths: [s.path],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${s.artist} · ${s.album}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline, width: 0.5)),
      ),
      child: Consumer<PlayerProvider>(
        builder: (context, p, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProgressSlider(player: p),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: _modeTip(p.mode),
                    icon: Icon(_modeIcon(p.mode)),
                    onPressed: () {
                      final next = PlayMode.values[(p.mode.index + 1) % PlayMode.values.length];
                      p.setMode(next);
                    },
                  ),
                  IconButton(
                    iconSize: 32,
                    tooltip: '上一首',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: p.previous,
                  ),
                  /// 播放/暂停按钮仅订阅 playingListenable，避免每次播放/暂停时重建整行控制栏
                  PlayingStateBuilder(
                    player: p,
                    builder: (context, playing, _) => IconButton(
                      iconSize: 56,
                      tooltip: playing ? '暂停' : '播放',
                      icon: Icon(
                        playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: p.togglePlay,
                    ),
                  ),
                  IconButton(
                    iconSize: 32,
                    tooltip: '下一首',
                    icon: const Icon(Icons.skip_next),
                    onPressed: p.next,
                  ),
                  IconButton(
                    tooltip: '收起',
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _modeIcon(PlayMode m) {
    switch (m) {
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.loopAll:
        return Icons.repeat;
    }
  }

  String _modeTip(PlayMode m) {
    switch (m) {
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.loopAll:
        return '列表循环';
    }
  }
}

class _ProgressSlider extends StatelessWidget {
  final PlayerProvider player;
  const _ProgressSlider({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlayerPositionBuilder(
      player: player,
      builder: (context, pos, dur) {
        final max = dur.inMilliseconds == 0 ? 1.0 : dur.inMilliseconds.toDouble();
        final value = pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();
        return Row(
          children: [
            Text(formatDuration(pos), style: theme.textTheme.bodySmall),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  min: 0,
                  max: max,
                  value: value,
                  onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                ),
              ),
            ),
            Text(formatDuration(dur), style: theme.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}