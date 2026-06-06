import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/cover_service.dart';

/// 封面显示组件：同目录磁盘文件 -> 嵌入式封面(ID3 APIC) -> 占位音符
class CoverImage extends StatefulWidget {
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
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  Uint8List? _embeddedBytes;
  bool _loadingEmbedded = false;

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.path != widget.song?.path) {
      _embeddedBytes = null;
      _loadingEmbedded = false;
      _tryLoadEmbedded();
    }
  }

  @override
  void initState() {
    super.initState();
    _tryLoadEmbedded();
  }

  void _tryLoadEmbedded() {
    final song = widget.song;
    if (song == null) return;
    if (song.coverPath != null && song.coverPath!.isNotEmpty) return; // 有同目录封面，跳过
    if (_loadingEmbedded) return;
    _loadingEmbedded = true;

    final cached = CoverService.instance.peek(song.path);
    if (cached != null) {
      _embeddedBytes = cached;
      _loadingEmbedded = false;
      return;
    }

    CoverService.instance.load(song.path).then((bytes) {
      if (mounted) {
        setState(() {
          _embeddedBytes = bytes;
          _loadingEmbedded = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget child;
    final coverPath = widget.song?.coverPath;

    if (coverPath != null && coverPath.isNotEmpty) {
      // 1. 同目录封面文件
      child = Image.file(
        File(coverPath),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: widget.size.toInt(),
        cacheHeight: widget.size.toInt(),
        errorBuilder: (_, __, ___) => _placeholder(colors),
      );
    } else if (_embeddedBytes != null) {
      // 2. 嵌入式封面
      child = Image.memory(
        _embeddedBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: widget.size.toInt(),
        cacheHeight: widget.size.toInt(),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(colors),
      );
    } else {
      // 3. 占位
      child = _placeholder(colors);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(width: widget.size, height: widget.size, child: child),
    );
  }

  Widget _placeholder(ColorScheme c) {
    return Container(
      width: widget.size,
      height: widget.size,
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
      child: Icon(Icons.music_note, color: c.onPrimary, size: widget.size * 0.5),
    );
  }
}