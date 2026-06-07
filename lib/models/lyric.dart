/// LRC 单行歌词
class LyricLine {
  /// 起始时间
  final Duration time;
  final String text;

  const LyricLine(this.time, this.text);
}

/// LRC 歌词容器
class Lyrics {
  /// 已按时间排序的行
  final List<LyricLine> lines;
  final Map<String, String> tags;

  const Lyrics({required this.lines, this.tags = const {}});

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// 根据当前播放位置返回应高亮的行索引；无歌词或在第一行之前返回 -1
  /// 空行（段落分隔）不会被返回，会回退到最近的非空行
  int indexAt(Duration position) {
    if (lines.isEmpty) return -1;
    if (position < lines.first.time) return -1;
    // 二分查找最后一个 time <= position 的行
    int lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time <= position) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // 跳过段落分隔的空行，回退到最近的非空行
    while (ans >= 0 && lines[ans].text.isEmpty) {
      ans--;
    }
    return ans;
  }

  static const Lyrics empty = Lyrics(lines: []);
}
