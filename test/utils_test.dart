import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/utils/constants.dart';

void main() {
  group('formatDuration', () {
    test('formats mm:ss for <1h', () {
      expect(formatDuration(const Duration(seconds: 5)), '00:05');
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '03:07');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('formats h:mm:ss for >=1h', () {
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatDuration(const Duration(hours: 2, minutes: 5, seconds: 9)),
        '2:05:09',
      );
    });
  });

  group('normalizeDirPath', () {
    test('trims whitespace', () {
      expect(normalizeDirPath('  /music  '), Platform.isWindows ? r'\music' : '/music');
    });

    test('removes trailing separator', () {
      if (Platform.isWindows) {
        expect(normalizeDirPath(r'C:\Music\\'), r'C:\Music');
      } else {
        expect(normalizeDirPath('/home/user/Music/'), '/home/user/Music');
      }
    });

    test('keeps root path intact', () {
      if (!Platform.isWindows) {
        expect(normalizeDirPath('/'), '/');
      }
    });

    test('empty input returns empty', () {
      expect(normalizeDirPath(''), '');
      expect(normalizeDirPath('   '), '');
    });
  });
}
