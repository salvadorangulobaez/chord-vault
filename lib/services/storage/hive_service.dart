import 'dart:io';

import 'package:flutter/services.dart';
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
    try {
      await Hive.initFlutter();
    } on MissingPluginException {
      // En tests de VM, path_provider puede no estar disponible.
      final dir = await Directory.systemTemp.createTemp('cancionero_hive_');
      Hive.init(dir.path);
    }

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

    final opens = <Future<dynamic>>[
      if (!Hive.isBoxOpen(notesBoxName)) Hive.openBox<Note>(notesBoxName),
      if (!Hive.isBoxOpen(libraryBoxName)) Hive.openBox<Song>(libraryBoxName),
      if (!Hive.isBoxOpen(settingsBoxName)) Hive.openBox(settingsBoxName),
    ];
    if (opens.isNotEmpty) {
      await Future.wait(opens);
    }

    // Cargar preferencias iniciales si existen
    // gridView persisted can be read by UI via settingsProvider initialization if desired
  }

  static Box<Note> get notesBox => Hive.box<Note>(notesBoxName);
  static Box<Song> get libraryBox => Hive.box<Song>(libraryBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);

  static String newId() => const Uuid().v4();
}


