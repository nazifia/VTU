import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class ThemeProvider with ChangeNotifier {
  final StorageService _storage;
  bool _isDark = false;

  ThemeProvider(this._storage);

  bool get isDark => _isDark;

  Future<void> init() async {
    _isDark = await _storage.isDarkTheme();
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    await _storage.setDarkTheme(_isDark);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await _storage.setDarkTheme(value);
    notifyListeners();
  }
}
