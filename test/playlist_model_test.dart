import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/models/playlist.dart';

void main() {
  group('Playlist 序列化', () {
    test('toJson / fromJson 往返一致', () {
      final pl = Playlist(
        id: 'pl_1',
        name: '通勤路上',
        songPaths: ['/a.mp3', '/b.flac'],
        createdAt: DateTime.parse('2026-06-06T08:00:00.000'),
        updatedAt: DateTime.parse('2026-06-06T09:00:00.000'),
      );
      final json = pl.toJson();
      final restored = Playlist.fromJson(json);
      expect(restored.id, 'pl_1');
      expect(restored.name, '通勤路上');
      expect(restored.songPaths, ['/a.mp3', '/b.flac']);
      expect(restored.createdAt.toIso8601String(), '2026-06-06T08:00:00.000');
      expect(restored.updatedAt.toIso8601String(), '2026-06-06T09:00:00.000');
    });

    test('缺失字段使用默认值', () {
      final pl = Playlist.fromJson({'id': 'pl_x', 'name': '新歌单'});
      expect(pl.songPaths, isEmpty);
      // createdAt / updatedAt 自动填充为当前时间
      expect(pl.createdAt, isNotNull);
      expect(pl.updatedAt, isNotNull);
    });

    test('copyWith 仅修改指定字段并更新 updatedAt', () async {
      final pl = Playlist(
        id: 'pl_1',
        name: 'old',
        createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
        updatedAt: DateTime.parse('2026-01-01T00:00:00.000'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final updated = pl.copyWith(name: 'new');
      expect(updated.name, 'new');
      expect(updated.id, 'pl_1');
      expect(updated.createdAt, pl.createdAt);
      expect(updated.updatedAt.isAfter(pl.updatedAt), isTrue);
    });
  });
}
