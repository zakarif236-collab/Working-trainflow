import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/music_folder_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadFolderPath returns null when nothing was saved', () async {
    expect(await MusicFolderPrefs().loadFolderPath(), isNull);
    expect(await MusicFolderPrefs().loadFolderName(), isNull);
  });

  test('saveFolder persists the path and the basename', () async {
    await MusicFolderPrefs().saveFolder('/storage/emulated/0/Music Appel');

    expect(
      await MusicFolderPrefs().loadFolderPath(),
      '/storage/emulated/0/Music Appel',
    );
    expect(await MusicFolderPrefs().loadFolderName(), 'Music Appel');
  });

  test('saveFolder normalizes backslashes and trailing slashes', () async {
    await MusicFolderPrefs().saveFolder(r'C:\Music Appel\');

    expect(await MusicFolderPrefs().loadFolderPath(), 'C:/Music Appel/');
    expect(await MusicFolderPrefs().loadFolderName(), 'Music Appel');
  });

  test('clearFolder removes both keys', () async {
    final prefs = MusicFolderPrefs();
    await prefs.saveFolder('/storage/emulated/0/Music');
    await prefs.clearFolder();

    expect(await prefs.loadFolderPath(), isNull);
    expect(await prefs.loadFolderName(), isNull);
  });
}