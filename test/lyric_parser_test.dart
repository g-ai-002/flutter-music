import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/services/lyric_parser.dart';

void main() {
  group('LyricParser', () {
    test('parses standard LRC with multiple time tags', () {
      const text = '''
[ti:测试歌曲]
[ar:测试歌手]
[al:测试专辑]
[offset:0]
[00:01.00]第一行
[00:05.50][00:06.00]第二行
[01:00.000]第三行
''';
      final lyrics = LyricParser.parseText(text);
      expect(lyrics.tags['ti'], '测试歌曲');
      expect(lyrics.tags['ar'], '测试歌手');
      expect(lyrics.lines.length, 4);
      // 排序后
      expect(lyrics.lines[0].time, const Duration(seconds: 1));
      expect(lyrics.lines[0].text, '第一行');
      expect(lyrics.lines[1].time, const Duration(seconds: 5, milliseconds: 500));
      expect(lyrics.lines[1].text, '第二行');
      expect(lyrics.lines[2].time, const Duration(seconds: 6));
      expect(lyrics.lines[2].text, '第二行');
      expect(lyrics.lines[3].time, const Duration(minutes: 1));
      expect(lyrics.lines[3].text, '第三行');
    });

    test('indexAt finds correct line', () {
      const text = '''
[00:00.00]A
[00:05.00]B
[00:10.00]C
''';
      final lyrics = LyricParser.parseText(text);
      expect(lyrics.indexAt(const Duration(milliseconds: 0)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 4)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 5)), 1);
      expect(lyrics.indexAt(const Duration(seconds: 9)), 1);
      expect(lyrics.indexAt(const Duration(seconds: 15)), 2);
    });

    test('returns -1 before first line', () {
      const text = '[00:10.00]A\n';
      final lyrics = LyricParser.parseText(text);
      expect(lyrics.indexAt(const Duration(seconds: 5)), -1);
    });

    test('empty content returns empty lyrics', () {
      final lyrics = LyricParser.parseText('');
      expect(lyrics.isEmpty, true);
      expect(lyrics.indexAt(Duration.zero), -1);
    });

    test('handles offset tag (milliseconds)', () {
      const text = '''
[offset:500]
[00:01.00]A
''';
      final lyrics = LyricParser.parseText(text);
      expect(lyrics.lines.first.time, const Duration(milliseconds: 1500));
    });

    test('handles single-digit fraction', () {
      const text = '[00:01.5]A\n';
      final lyrics = LyricParser.parseText(text);
      expect(lyrics.lines.first.time, const Duration(milliseconds: 1500));
    });
  });
}
