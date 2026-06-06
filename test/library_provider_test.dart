import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/models/song.dart';
import 'package:flutter_music/providers/library_provider.dart';
import 'package:flutter_music/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _s(String path, {String? title, String? artist, String? album}) {
  return Song(
    path: path,
    title: title ?? Song.titleFromPath(path),
    artist: artist ?? '未知艺术家',
    album: album ?? '未知专辑',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryProvider 搜索过滤', () {
    late StorageService storage;
    late LibraryProvider lib;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.instance;
      // 写入一份缓存歌曲列表，构造时直接载入
      await storage.saveCachedSongs([
        _s('/m/a.mp3', title: 'Hello World', artist: 'Alice', album: 'Greetings'),
        _s('/m/b.mp3', title: 'Foo Bar', artist: 'Bob', album: 'Greetings'),
        _s('/m/c.mp3', title: '中文歌名', artist: '周华健', album: '经典'),
      ]);
      lib = LibraryProvider(storage);
    });

    test('空搜索返回完整列表（同一引用，避免重复 toList）', () {
      expect(lib.filtered.length, 3);
      expect(identical(lib.filtered, lib.songs), isTrue);
    });

    test('按标题匹配，大小写不敏感', () {
      lib.updateSearch('hello');
      expect(lib.filtered.length, 1);
      expect(lib.filtered.first.path, '/m/a.mp3');
    });

    test('按艺术家匹配', () {
      lib.updateSearch('bob');
      expect(lib.filtered.length, 1);
      expect(lib.filtered.first.title, 'Foo Bar');
    });

    test('按专辑匹配（多结果）', () {
      lib.updateSearch('greetings');
      expect(lib.filtered.length, 2);
    });

    test('中文匹配', () {
      lib.updateSearch('周华健');
      expect(lib.filtered.length, 1);
      expect(lib.filtered.first.path, '/m/c.mp3');
    });

    test('无匹配返回空', () {
      lib.updateSearch('nothing-found');
      expect(lib.filtered, isEmpty);
    });

    test('相同关键字不重复通知', () {
      var n = 0;
      lib.addListener(() => n++);
      lib.updateSearch('hello');
      lib.updateSearch('hello');
      lib.updateSearch('  hello  '); // trim 后相同
      expect(n, 1);
    });

    test('清空搜索恢复全部', () {
      lib.updateSearch('hello');
      lib.updateSearch('');
      expect(lib.filtered.length, 3);
      expect(identical(lib.filtered, lib.songs), isTrue);
    });
  });
}
