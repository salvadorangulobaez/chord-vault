import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/block.dart';
import '../../models/song.dart';
import '../../models/note.dart';

class HiveService {
  static const String notesBoxName = 'notes_box';
  static const String libraryBoxName = 'library_box';
  static const String settingsBoxName = 'settings_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    // Registrar adapters
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(BlockAdapter());
    }
    // Adapter para enum BlockType dentro del BlockAdapter no es necesario porque se escribe el index.
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(SongAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(NoteAdapter());
    }
    await Future.wait([
      Hive.openBox<Note>(notesBoxName),
      Hive.openBox<Song>(libraryBoxName),
      Hive.openBox(settingsBoxName),
    ]);
  }

  static Box<Note> get notesBox => Hive.box<Note>(notesBoxName);
  static Box<Song> get libraryBox => Hive.box<Song>(libraryBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);

  static String newId() => const Uuid().v4();
}


