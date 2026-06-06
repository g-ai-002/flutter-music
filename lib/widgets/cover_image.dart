import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';

/// 封面显示组件：优先磁盘文件 -> 占位音符
class CoverImage extends StatelessWidget {
  final Song? song;
  final double size;
  final double radius;

  const CoverImage({
    super.key,
    required this.song,
    this.size = 48,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget child;
    final cover = song?.coverPath;
    if (cover != null && cover.isNotEmpty) {
      child = Image.file(
        File(cover),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: size.toInt(),
        cacheHeight: size.toInt(),
        errorBuilder: (_, __, ___) => _placeholder(colors),
      );
    } else {
      child = _placeholder(colors);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _placeholder(ColorScheme c) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.primary.withValues(alpha: 0.8),
            c.primary.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.music_note, color: c.onPrimary, size: size * 0.5),
    );
  }
}