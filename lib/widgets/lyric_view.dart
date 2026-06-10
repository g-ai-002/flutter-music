import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lyric.dart';
import '../providers/player_provider.dart';

/// 居中高亮、平滑滚动的 LRC 歌词视图
class LyricView extends StatefulWidget {
  final double lineHeight;
  final EdgeInsets padding;
  final TextAlign textAlign;
  final double activeFontSize;
  final double normalFontSize;

  const LyricView({
    super.key,
    this.lineHeight = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.textAlign = TextAlign.center,
    this.activeFontSize = 18,
    this.normalFontSize = 15,
  });

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  final ScrollController _ctrl = ScrollController();
  int _lastIndex = -2;
  Lyrics? _lastLyrics;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scrollTo(int index, double viewportHeight) {
    if (!_ctrl.hasClients) return;
    final target = (index + 1) * widget.lineHeight;
    final clamped = target.clamp(0.0, _ctrl.position.maxScrollExtent);
    _ctrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 歌词内容（行集合）随歌曲切换变更：用 Selector 取一次，避免位置流更新触发整体重建
    return Selector<PlayerProvider, Lyrics>(
      selector: (_, p) => p.lyrics,
      builder: (context, lyrics, _) {
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        // 过滤掉首个有时间戳的歌词行之前的所有空行/段落标记，
        // 确保第一行就是真正有时间戳的歌词，后续空行保留作为段落分隔
        int firstReal = 0;
        while (firstReal < lyrics.lines.length &&
            lyrics.lines[firstReal].text.isEmpty) {
          firstReal++;
        }
        final displayLines = <LyricLine>[];
        final rawToDisplay = List<int?>.filled(lyrics.lines.length, null);
        for (int i = firstReal; i < lyrics.lines.length; i++) {
          rawToDisplay[i] = displayLines.length;
          displayLines.add(lyrics.lines[i]);
        }
        if (displayLines.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        // 切歌时重置滚动位置到第一行
        if (_lastLyrics != null && _lastLyrics != lyrics) {
          _lastIndex = -2;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _ctrl.hasClients) {
              _ctrl.jumpTo(0);
            }
          });
        }
        _lastLyrics = lyrics;
        final player = context.read<PlayerProvider>();
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewportH = constraints.maxHeight;
            return ValueListenableBuilder<Duration>(
              valueListenable: player.positionListenable,
              builder: (context, pos, _) {
                final rawIdx = lyrics.indexAt(pos);
                final idx = rawIdx >= 0 ? (rawToDisplay[rawIdx] ?? -1) : -1;
                // 首行始终位于中间行下一行，通过 scroll 偏移对齐到中间高亮位
                final topPad = viewportH / 2 + widget.lineHeight / 2;

                if (idx != _lastIndex) {
                  _lastIndex = idx;
                  if (idx >= 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _scrollTo(idx, viewportH);
                    });
                  }
                }
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: ListView.builder(
                    controller: _ctrl,
                    padding: EdgeInsets.only(top: topPad, bottom: topPad),
                    itemCount: displayLines.length,
                    itemBuilder: (context, i) {
                      final line = displayLines[i];
                      final isActive = i == idx;
                      return SizedBox(
                          height: widget.lineHeight,
                          child: Padding(
                            padding: widget.padding,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: isActive ? widget.activeFontSize : widget.normalFontSize,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                height: 1.4,
                              ),
                              textAlign: widget.textAlign,
                              child: Text(
                                line.text,
                                textAlign: widget.textAlign,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                );
              },
            );
          },
        );
      },
    );
  }
}
