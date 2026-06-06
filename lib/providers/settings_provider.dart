import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// 应用设置：主题、扫描目录、播放模式、音量
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  SettingsProvider(this._storage) {
    _darkMode = _storage.darkMode;
    _scanDirs = _storage.scanDirs.map(normalizeDirPath).where((s) => s.isNotEmpty).toSet().toList();
    _playMode = _storage.playMode.clamp(0, 2);
    _volume = _storage.volume;
  }

  late bool _darkMode;
  late List<String> _scanDirs;
  late int _playMode;
  late double _volume;

  bool get darkMode => _darkMode;
  List<String> get scanDirs => List.unmodifiable(_scanDirs);
  int get playMode => _playMode;
  double get volume => _volume;

  Future<void> toggleDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    await _storage.setDarkMode(value);
    notifyListeners();
  }

  Future<void> addScanDir(String dir) async {
    final normalized = normalizeDirPath(dir);
    if (normalized.isEmpty || _scanDirs.contains(normalized)) return;
    _scanDirs = [..._scanDirs, normalized];
    await _storage.setScanDirs(_scanDirs);
    notifyListeners();
  }

  Future<void> removeScanDir(String dir) async {
    final normalized = normalizeDirPath(dir);
    if (!_scanDirs.contains(normalized)) return;
    _scanDirs = _scanDirs.where((d) => d != normalized).toList();
    await _storage.setScanDirs(_scanDirs);
    notifyListeners();
  }

  Future<void> setPlayMode(int mode) async {
    final m = mode.clamp(0, 2);
    if (_playMode == m) return;
    _playMode = m;
    await _storage.setPlayMode(m);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    final nv = v.clamp(0.0, 1.0);
    if ((_volume - nv).abs() < 1e-3) return;
    _volume = nv;
    await _storage.setVolume(nv);
    notifyListeners();
  }
}
