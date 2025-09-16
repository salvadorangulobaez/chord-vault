import 'hive_service.dart';
import '../../models/note.dart';
import '../../models/song.dart';
import '../../models/block.dart';

Future<void> seedExampleData() async {
  if (HiveService.notesBox.isNotEmpty) return;
  // Glorioso Dia (D)
  final song1 = Song(
    id: HiveService.newId(),
    title: 'Glorioso Dia (D)',
    blocks: [
      Block(id: HiveService.newId(), type: BlockType.text, content: 'INTRO'),
      Block(id: HiveService.newId(), type: BlockType.chords, content: 'D'),
      Block(id: HiveService.newId(), type: BlockType.text, content: 'ESTROFA'),
      Block(id: HiveService.newId(), type: BlockType.chords, content: 'D A Bm G'),
      Block(id: HiveService.newId(), type: BlockType.text, content: 'CORO'),
      Block(id: HiveService.newId(), type: BlockType.chords, content: 'D A Bm G'),
      Block(id: HiveService.newId(), type: BlockType.text, content: 'PUENTE'),
      Block(id: HiveService.newId(), type: BlockType.chords, content: 'Bm A G Em'),
    ],
  );

  final song2 = Song(
    id: HiveService.newId(),
    title: 'Variedad #1',
    blocks: [
      Block(id: HiveService.newId(), type: BlockType.chords, content: 'E/G# A B'),
    ],
  );

  final song3 = Song(
    id: HiveService.newId(),
    title: 'Variedad #2',
    blocks: [
      Block(id: HiveService.newId(), type: BlockType.chords, content: 'F#5b-F Bbmaj7'),
    ],
  );

  final note = Note(
    id: HiveService.newId(),
    title: 'Ejemplos',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    songs: [song1, song2, song3],
  );

  HiveService.notesBox.put(note.id, note);
}


