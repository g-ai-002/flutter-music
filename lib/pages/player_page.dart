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
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        final compact = wide && c.maxHeight < 500;
        return Scaffold(
          appBar: compact
              ? null
              : AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: '收起',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  title: Consumer<PlayerProvider>(
                    builder: (_, p, _) => Text(p.currentSong?.title ?? '正在播放'),
                  ),
                  actions: [
                    Consumer<PlayerProvider>(
                      builder: (_, p, _) {
                        final s = p.currentSong;
                        if (s == null) return const SizedBox.shrink();
                        return PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: '更多操作',
                          onSelected: (v) {
                            if (v == 'add_playlist') {
                              showAddToPlaylistSheet(context, songPaths: [s.path]);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'add_playlist',
                              child: ListTile(
                                leading: Icon(Icons.playlist_add),
                                title: Text('添加到歌单'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
          body: SafeArea(
            child: compact
                ? _buildCompact(context, theme)
                : wide
                    ? _buildWide(context)
                    : _buildNarrow(context),
          ),
        );
      },
    );
  }

  void _showErrorIfAny(BuildContext context, PlayerProvider p) {
    final msg = p.errorMessage;
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 3),
              ),
            );
          p.clearError();
        }
      });
    }
  }

  Widget _buildNarrow(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Consumer<PlayerProvider>(
          builder: (_, p, _) {
            _showErrorIfAny(context, p);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AspectRatio(
                aspectRatio: 1,
                child: CoverImage(song: p.currentSong, size: 320, radius: 12),
              ),
            );
          },
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
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Consumer<PlayerProvider>(
                            builder: (_, p, _) {
                              _showErrorIfAny(context, p);
                              return AspectRatio(
                                aspectRatio: 1,
                                child: CoverImage(song: p.currentSong, size: 400, radius: 16),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _SongInfo(),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: const LyricView(),
              ),
            ],
          ),
        ),
        const _ControlPanel(),
      ],
    );
  }

  /// 紧凑横屏模式：高度不足以完整显示左半部分时启用
  ///
  /// 隐藏 AppBar 和底部操作栏，左半仅封面，右半顶部为歌曲信息+控制按钮，
  /// 下方全部留给歌词滚动。
  Widget _buildCompact(BuildContext context, ThemeData theme) {
    return Consumer<PlayerProvider>(
      builder: (context, p, _) {
        _showErrorIfAny(context, p);
        final s = p.currentSong;
        return Row(
          children: [
            // 左半：仅封面，上下至少 16dp 间距
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CoverImage(song: s, size: 300, radius: 12),
                  ),
                ),
              ),
            ),
            // 右半：信息 + 控制 + 歌词
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 歌曲信息 + 控制按钮：按钮撑满两行高度
                    if (s != null)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 左侧：歌名 + 艺术家·专辑
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    s.title,
                                    style: theme.textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.artist} · ${s.album}',
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // 右侧：控制按钮（与左侧等高度，内部居中）
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                PlayingStateBuilder(
                                  player: p,
                                  builder: (context, playing, _) => IconButton(
                                    tooltip: playing ? '暂停' : '播放',
                                    icon: Icon(
                                      playing
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      color: theme.colorScheme.primary,
                                    ),
                                    iconSize: 32,
                                    onPressed: p.togglePlay,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '下一首',
                                  icon: const Icon(Icons.skip_next),
                                  iconSize: 32,
                                  onPressed: p.next,
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  tooltip: '收起',
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  iconSize: 32,
                                  onPressed: () => Navigator.maybePop(context),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (s != null) const SizedBox(height: 8),
                    // 下方：歌词滚动
                    const Expanded(child: LyricView()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, p, _) {
        final s = p.currentSong;
        if (s == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: Text(
                        s.title,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  FavoriteToggleButton(songPath: s.path),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: _modeTip(p.mode),
                    icon: Icon(_modeIcon(p.mode)),
                    onPressed: () {
                      final next = PlayMode.values[(p.mode.index + 1) % PlayMode.values.length];
                      p.setMode(next);
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 32,
                    tooltip: '上一首',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: p.previous,
                  ),
                  const SizedBox(width: 16),
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
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 32,
                    tooltip: '下一首',
                    icon: const Icon(Icons.skip_next),
                    onPressed: p.next,
                  ),
                  const SizedBox(width: 16),
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