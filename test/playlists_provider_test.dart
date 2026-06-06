import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/providers/playlists_provider.dart';
import 'package:flutter_music/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistsProvider CRUD', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.instance;
      await storage.savePlaylists(const []);
    });

    test('create 写入并去除前后空白', () async {
      final p = PlaylistsProvider(storage);
      final pl = await p.create('  日常通勤  ');
      expect(pl.name, '日常通勤');
      expect(p.count, 1);
      expect(p.items.first.songPaths, isEmpty);
    });

    test('create 空名抛出 ArgumentError', () async {
      final p = PlaylistsProvider(storage);
      expect(() => p.create('   '), throwsArgumentError);
    });

    test('create 名称重复抛出 ArgumentError', () async {
      final p = PlaylistsProvider(storage);
      await p.create('A');
      expect(() => p.create('A'), throwsArgumentError);
      // 改变前后空白也算重复
      expect(() => p.create(' A '), throwsArgumentError);
    });

    test('rename 校验空名和重名', () async {
      final p = PlaylistsProvider(storage);
      final a = await p.create('A');
      await p.create('B');
      expect(() => p.rename(a.id, ''), throwsArgumentError);
      expect(() => p.rename(a.id, 'B'), throwsArgumentError);
      await p.rename(a.id, 'A2');
      expect(p.byId(a.id)!.name, 'A2');
      // 重命名为自身名是 no-op，不抛
      await p.rename(a.id, 'A2');
      expect(p.byId(a.id)!.name, 'A2');
    });

    test('remove 删除指定歌单', () async {
      final p = PlaylistsProvider(storage);
      final a = await p.create('A');
      await p.create('B');
      await p.remove(a.id);
      expect(p.count, 1);
      expect(p.byId(a.id), isNull);
    });

    test('addSongs 去重并返回新增数量', () async {
      final p = PlaylistsProvider(storage);
      final pl = await p.create('A');
      final n1 = await p.addSongs(pl.id, ['/a.mp3', '/b.mp3', '/a.mp3']);
      expect(n1, 2);
      expect(p.byId(pl.id)!.songPaths, ['/a.mp3', '/b.mp3']);
      // 再次添加全部已存在 → 返回 0
      final n2 = await p.addSongs(pl.id, ['/a.mp3', '/b.mp3']);
      expect(n2, 0);
      final n3 = await p.addSongs(pl.id, ['/c.mp3']);
      expect(n3, 1);
      expect(p.byId(pl.id)!.songPaths, ['/a.mp3', '/b.mp3', '/c.mp3']);
    });

    test('removeSong / clearSongs', () async {
      final p = PlaylistsProvider(storage);
      final pl = await p.create('A');
      await p.addSongs(pl.id, ['/a.mp3', '/b.mp3']);
      await p.removeSong(pl.id, '/a.mp3');
      expect(p.byId(pl.id)!.songPaths, ['/b.mp3']);
      await p.clearSongs(pl.id);
      expect(p.byId(pl.id)!.songPaths, isEmpty);
    });

    test('持久化：新实例可读到上一次的歌单', () async {
      final p1 = PlaylistsProvider(storage);
      final pl = await p1.create('A');
      await p1.addSongs(pl.id, ['/a.mp3', '/b.mp3']);
      // 模拟下一次启动
      final p2 = PlaylistsProvider(storage);
      expect(p2.count, 1);
      expect(p2.items.first.name, 'A');
      expect(p2.items.first.songPaths, ['/a.mp3', '/b.mp3']);
    });
  });
}
