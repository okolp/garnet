// lib/auth/auth_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'access_token';
  static const _langKey = 'preferred_language';

  // in‑memory cache of the language
  // defaults to English so your UI can call getPreferredLanguage() synchronously
  static String _preferredLanguage = 'English';

  /// Save the JWT for authenticated requests
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Retrieve the saved JWT (or null if not set)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Remove the saved JWT
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Save the user’s preferred language (one of your supported keys)
  static Future<void> savePreferredLanguage(String language) async {
    _preferredLanguage = language; // update cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, language);
  }

  /// Load the preferred language from disk into the in‑memory cache.
  /// Call this once at startup (or right after login) before your widgets need it.
  static Future<void> loadPreferredLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _preferredLanguage = prefs.getString(_langKey) ?? _preferredLanguage;
  }

  /// Get the cached preferred language synchronously.
  /// Falls back to 'English' if nothing was loaded yet.
  static String getPreferredLanguage() => _preferredLanguage;

  /// Clear both token and language (e.g. on logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_langKey);
    _preferredLanguage = 'English';
  }
}
