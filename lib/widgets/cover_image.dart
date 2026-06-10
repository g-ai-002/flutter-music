import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';
import '../services/cover_service.dart';
import '../utils/constants.dart';

/// 封面显示组件：同目录磁盘文件 -> 嵌入式封面(ID3 APIC) -> 占位音符
///
/// 加载优先级：
/// 1. Song.coverPath（扫描时已解析的同目录封面）
/// 2. 运行时按歌曲同名匹配的图片文件（处理扫描后新增封面的情况）
/// 3. 音频文件内嵌封面（ID3 APIC）
/// 4. 占位渐变图标
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
  String? _runtimeCoverPath;
  bool _resolvingRuntime = false;

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.path != widget.song?.path) {
      _embeddedBytes = null;
      _loadingEmbedded = false;
      _runtimeCoverPath = null;
      _resolvingRuntime = false;
      _tryLoadCover();
    }
  }

  @override
  void initState() {
    super.initState();
    _tryLoadCover();
  }

  /// 统一封面加载入口：按优先级尝试各来源
  void _tryLoadCover() {
    final song = widget.song;
    if (song == null) return;

    if (song.coverPath != null && song.coverPath!.isNotEmpty) return;
    if (_runtimeCoverPath != null) return;

    if (!_resolvingRuntime) {
      _resolvingRuntime = true;
      _resolveRuntimeCover(song);
      return;
    }

    _tryLoadEmbedded();
  }

  /// 运行时匹配歌曲同名图片文件（处理扫描后新增封面的场景）
  Future<void> _resolveRuntimeCover(Song song) async {
    final dir = song.parentDir;
    final audioName = p.basenameWithoutExtension(song.path);
    String? found;
    for (final ext in AppConstants.coverSameNameExts) {
      final candidate = p.join(dir, '$audioName$ext');
      if (await File(candidate).exists()) {
        found = candidate;
        break;
      }
    }
    if (!mounted) return;
    _resolvingRuntime = false;
    if (found != null) {
      setState(() => _runtimeCoverPath = found);
    } else {
      _tryLoadEmbedded();
    }
  }

  void _tryLoadEmbedded() {
    final song = widget.song;
    if (song == null) return;
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
    final coverPath = widget.song?.coverPath ?? _runtimeCoverPath;

    if (coverPath != null && coverPath.isNotEmpty) {
      // 1. 同目录封面文件
      child = Image.file(
        File(coverPath),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(colors),
      );
    } else if (_embeddedBytes != null) {
      // 2. 嵌入式封面
      child = Image.memory(
        _embeddedBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(colors),
      );
    } else {
      // 3. 占位
      child = _placeholder(colors);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(width: widget.size, height: widget.size, child: child),
      ),
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