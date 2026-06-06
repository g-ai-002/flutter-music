import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/models/song.dart';

void main() {
  group('Song', () {
    test('titleFromPath strips extension', () {
      expect(Song.titleFromPath('/music/abc.mp3'), 'abc');
      expect(Song.titleFromPath('/music/中文 歌名.flac'), '中文 歌名');
    });

    test('lrcPathFor produces sibling .lrc', () {
      expect(Song.lrcPathFor('/music/abc.mp3').replaceAll(r'\', '/'), '/music/abc.lrc');
    });

    test('toJson/fromJson roundtrip', () {
      final s = Song(
        path: '/m/a.mp3',
        title: 'A',
        artist: 'X',
        album: 'Y',
        duration: const Duration(seconds: 200),
        fileSize: 1024,
      );
      final json = s.toJson();
      final s2 = Song.fromJson(json);
      expect(s2.path, s.path);
      expect(s2.title, s.title);
      expect(s2.artist, s.artist);
      expect(s2.album, s.album);
      expect(s2.duration, s.duration);
      expect(s2.fileSize, s.fileSize);
    });
  });
}
