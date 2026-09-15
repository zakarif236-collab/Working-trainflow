import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/music_folder_picker.dart';

void main() {
  testWidgets('header shows the folder name and fires the change callback',
      (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MusicFolderHeader(
            folderName: 'Music Appel',
            onChangeFolder: () => changed = true,
          ),
        ),
      ),
    );

    expect(find.text('Music Appel'), findsOneWidget);
    expect(find.text('Change Music Folder'), findsOneWidget);

    await tester.tap(find.text('Change Music Folder'));
    expect(changed, isTrue);
  });

  testWidgets('header falls back when no folder name is available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MusicFolderHeader(folderName: null, onChangeFolder: () {}),
        ),
      ),
    );

    expect(find.text('No folder selected'), findsOneWidget);
  });
}