import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/providers/favorites_provider.dart';
import 'package:flutter_music/services/storage_service.dart';
import 'package:flutter_music/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesProvider 收藏 / 最近播放', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await StorageService.instance;
      // StorageService 是单例，跨测试需手动清空状态
      await storage.setFavorites(const []);
      await storage.setRecentPlays(const []);
    });

    test('toggleFavorite 切换并持久化', () async {
      final fp = FavoritesProvider(storage);
      expect(fp.isFavorite('/a.mp3'), isFalse);
      await fp.toggleFavorite('/a.mp3');
      expect(fp.isFavorite('/a.mp3'), isTrue);
      // 再切换回去
      await fp.toggleFavorite('/a.mp3');
      expect(fp.isFavorite('/a.mp3'), isFalse);
    });

    test('setFavorite 幂等', () async {
      final fp = FavoritesProvider(storage);
      await fp.setFavorite('/a.mp3', true);
      await fp.setFavorite('/a.mp3', true); // 不应抛错或多次写
      expect(fp.favorites.length, 1);
      await fp.setFavorite('/a.mp3', false);
      await fp.setFavorite('/a.mp3', false);
      expect(fp.favorites.isEmpty, isTrue);
    });

    test('recordPlay 头部去重且保留上限', () async {
      final fp = FavoritesProvider(storage);
      await fp.recordPlay('/a.mp3');
      await fp.recordPlay('/b.mp3');
      await fp.recordPlay('/c.mp3');
      expect(fp.recent, ['/c.mp3', '/b.mp3', '/a.mp3']);

      // 再次播放 b → b 升到头部，没有重复
      await fp.recordPlay('/b.mp3');
      expect(fp.recent, ['/b.mp3', '/c.mp3', '/a.mp3']);
    });

    test('recordPlay 截断到 maxRecentPlays', () async {
      final fp = FavoritesProvider(storage);
      // 比上限多 5 条
      for (var i = 0; i < AppConstants.maxRecentPlays + 5; i++) {
        await fp.recordPlay('/song$i.mp3');
      }
      expect(fp.recent.length, AppConstants.maxRecentPlays);
      // 头部是最后一次播放
      expect(fp.recent.first,
          '/song${AppConstants.maxRecentPlays + 5 - 1}.mp3');
    });

    test('clearRecent 清空', () async {
      final fp = FavoritesProvider(storage);
      await fp.recordPlay('/a.mp3');
      await fp.clearRecent();
      expect(fp.recent, isEmpty);
    });
  });
}
