import 'dart:math';
import 'package:flutter/material.dart';

/// 动态频谱动画 — 多条竖条上下跳动，模拟均衡器效果
///
/// 仅在歌曲正在播放时使用；暂停时可显示静态图标。
class AnimatedEqualizer extends StatefulWidget {
  final double size;
  final double barWidth;
  final int barCount;
  final Color? color;

  const AnimatedEqualizer({
    super.key,
    this.size = 18,
    this.barWidth = 2.5,
    this.barCount = 3,
    this.color,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _barHeight(int index) {
    // 每个 bar 有不同的相位偏移，sin 波动产生上下跳跃效果
    final phase = (index / widget.barCount) * 2 * pi;
    final t = _controller.value * 2 * pi;
    // 0.3 ~ 1.0 之间的高度比例
    final ratio = 0.35 + 0.65 * (0.5 + 0.5 * sin(t + phase));
    return widget.size * ratio;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final gap = widget.barWidth * 0.8;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: gap / 2),
                child: Container(
                  width: widget.barWidth,
                  height: _barHeight(i),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(widget.barWidth / 2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
