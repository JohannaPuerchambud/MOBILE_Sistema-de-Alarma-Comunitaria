import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kToken = 'jwt_token';
  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _kToken, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  Future<String?> getToken() async {
    final secureToken = await _secureStorage.read(key: _kToken);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_kToken);
    if (legacyToken == null || legacyToken.isEmpty) return null;

    await _secureStorage.write(key: _kToken, value: legacyToken);
    await prefs.remove(_kToken);
    return legacyToken;
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _kToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }
}