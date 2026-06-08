import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'log_service.dart';

/// 嵌入式封面读取与内存 LRU 缓存
///
/// - 解码音频元数据图片可能耗时几十毫秒，UI 必须异步访问；
/// - 同一文件可能被列表 / MiniPlayer / 大播放器同时请求，做去重；
/// - 失败结果同样缓存为 `null`，避免反复重试。
class CoverService {
  CoverService._();
  static final CoverService instance = CoverService._();

  static const int _maxEntries = 64;
  final Map<String, Uint8List?> _cache = <String, Uint8List?>{};
  final Map<String, Future<Uint8List?>> _pending = <String, Future<Uint8List?>>{};

  /// 命中返回缓存的 bytes 或 null；未命中返回 null（不会触发加载）
  Uint8List? peek(String audioPath) {
    if (!_cache.containsKey(audioPath)) return null;
    final v = _cache.remove(audioPath);
    _cache[audioPath] = v;
    return v;
  }

  bool isCached(String audioPath) => _cache.containsKey(audioPath);

  /// 异步加载嵌入封面，自动缓存与请求去重
  Future<Uint8List?> load(String audioPath) {
    if (_cache.containsKey(audioPath)) {
      return Future.value(peek(audioPath));
    }
    final inflight = _pending[audioPath];
    if (inflight != null) return inflight;

    final future = _read(audioPath).whenComplete(() => _pending.remove(audioPath));
    _pending[audioPath] = future;
    return future;
  }

  Future<Uint8List?> _read(String audioPath) async {
    Uint8List? bytes;
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        _put(audioPath, null);
        return null;
      }
      final meta = readMetadata(file, getImage: true);
      final pictures = meta.pictures;
      if (pictures.isNotEmpty) {
        bytes = pictures.first.bytes;
      }
    } catch (e) {
      LogService.warning('读取嵌入封面失败: $audioPath | $e');
    }
    _put(audioPath, bytes);
    return bytes;
  }

  void _put(String audioPath, Uint8List? bytes) {
    if (_cache.containsKey(audioPath)) {
      _cache.remove(audioPath);
    } else if (_cache.length >= _maxEntries) {
      // 删除最久未访问（map 头部）
      _cache.remove(_cache.keys.first);
    }
    _cache[audioPath] = bytes;
  }

  void clear() {
    _cache.clear();
    _pending.clear();
  }
}
