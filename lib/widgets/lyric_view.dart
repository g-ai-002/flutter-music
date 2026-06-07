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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scrollTo(int index, double viewportHeight) {
    if (!_ctrl.hasClients) return;
    final target = index * widget.lineHeight;
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
        final player = context.read<PlayerProvider>();
        return LayoutBuilder(
          builder: (context, constraints) {
            final topPad = constraints.maxHeight / 2 - widget.lineHeight / 2;
            return ValueListenableBuilder<Duration>(
              valueListenable: player.positionListenable,
              builder: (context, pos, _) {
                final activeIndex = lyrics.indexAt(pos);
                if (activeIndex != _lastIndex) {
                  _lastIndex = activeIndex;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && activeIndex >= 0) {
                      _scrollTo(activeIndex, constraints.maxHeight);
                    }
                  });
                }
                return ListView.builder(
                  controller: _ctrl,
                  padding: EdgeInsets.only(top: topPad, bottom: topPad),
                  itemCount: lyrics.lines.length,
                  itemBuilder: (context, i) {
                    final line = lyrics.lines[i];
                    final isActive = i == activeIndex;
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
                            line.text.isEmpty ? '·' : line.text,
                            textAlign: widget.textAlign,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
