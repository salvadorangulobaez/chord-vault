import 'package:flutter_test/flutter_test.dart';
import 'package:cancionero/services/storage/hive_service.dart';
import 'package:cancionero/models/note.dart';
import 'package:cancionero/models/song.dart';
import 'package:cancionero/models/block.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Hive init/open boxes', () async {
    await HiveService.init();
    final id = HiveService.newId();
    final note = Note(
      id: id,
      title: 'Test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      songs: [
        Song(
          id: HiveService.newId(),
          title: 'Canción',
          blocks: [Block(id: HiveService.newId(), type: BlockType.chords, content: 'D A Bm G')],
        )
      ],
    );
    HiveService.notesBox.put(id, note);
    final loaded = HiveService.notesBox.get(id);
    expect(loaded != null, true);
    expect(loaded!.songs.first.blocks.first.content, 'D A Bm G');
  });
}


