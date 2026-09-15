import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user-chosen music folder across app launches.
class MusicFolderPrefs {
  MusicFolderPrefs();

  static const String _folderPathKey = 'music.folderPath';
  static const String _folderNameKey = 'music.folderName';

  /// The stored folder path (e.g. `/storage/emulated/0/Music Appel`), or null
  /// when the user has not picked a folder yet.
  Future<String?> loadFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderPathKey);
  }

  /// The stored display name (folder basename), or null.
  Future<String?> loadFolderName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderNameKey);
  }

  /// Stores [path] and its basename. The path is normalized to forward
  /// slashes so non-Android paths remain usable on other platforms.
  Future<void> saveFolder(String path) async {
    final normalized = path.replaceAll('\\', '/');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderPathKey, normalized);
    await prefs.setString(_folderNameKey, _basename(normalized));
  }

  /// Removes the stored folder (used by tests / future reset flows).
  Future<void> clearFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderPathKey);
    await prefs.remove(_folderNameKey);
  }

  String _basename(String path) {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final lastSlash = trimmed.lastIndexOf('/');
    return lastSlash == -1 ? trimmed : trimmed.substring(lastSlash + 1);
  }
}