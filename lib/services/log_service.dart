import 'dart:io';
import 'file_system_service.dart';

/// 日志服务：按日期生成日志文件，写入用户目录 logs/ 子目录
class LogService {
  static LogService? _instance;
  File? _logFile;
  bool _initialized = false;
  final List<String> _buffer = [];
  static const int _maxBufferLines = 1000;

  LogService._();

  static Future<void> init() async {
    _instance ??= LogService._();
    await _instance!._init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    final dir = await FileSystemService.instance.getLogRoot();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}${Platform.pathSeparator}app_$dateStr.log');
    if (!await file.exists()) await file.create();
    _logFile = file;
    _initialized = true;
    _write('INFO', '==== LogService 已初始化, 日志文件: ${file.path} ====');
  }

  static void info(String message) => _instance?._write('INFO', message);

  static void warning(String message) => _instance?._write('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    _instance?._write('ERROR', msg);
    if (stack != null) _instance?._write('ERROR', stack.toString());
  }

  void _write(String level, String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$ts][$level] $message';
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) _buffer.removeAt(0);
    try {
      _logFile?.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {
      // 日志写入失败不阻塞应用
    }
  }

  static Future<String> getLogFilePath() async {
    return _instance?._logFile?.path ?? '';
  }

  static List<String> getRecentLogs([int n = 200]) {
    if (_instance == null) return const [];
    final buf = _instance!._buffer;
    if (buf.length <= n) return List.from(buf);
    return buf.sublist(buf.length - n);
  }
}
