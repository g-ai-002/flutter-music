import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/services/cover_service.dart';

void main() {
  group('CoverService 基础方法', () {
    test('未缓存的 path peek 返回 null 且不算命中', () {
      final svc = CoverService.instance;
      svc.clear();
      expect(svc.peek('/never_seen.mp3'), isNull);
      expect(svc.isCached('/never_seen.mp3'), isFalse);
    });

    test('clear 清空所有缓存', () {
      final svc = CoverService.instance;
      svc.clear();
      expect(svc.isCached('/a.mp3'), isFalse);
    });
  });
}