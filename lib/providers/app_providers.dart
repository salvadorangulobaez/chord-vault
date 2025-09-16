import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../models/song.dart';
import '../services/storage/hive_service.dart';

final settingsProvider = StateProvider<SettingsState>((ref) => SettingsState());

class SettingsState {
  SettingsState({this.preferSharps = true, this.fontScale = 1.0});
  final bool preferSharps;
  final double fontScale;

  SettingsState copyWith({bool? preferSharps, double? fontScale}) =>
      SettingsState(
        preferSharps: preferSharps ?? this.preferSharps,
        fontScale: fontScale ?? this.fontScale,
      );
}

final notesProvider = StateNotifierProvider<NotesController, List<Note>>((ref) {
  return NotesController();
});

class NotesController extends StateNotifier<List<Note>> {
  NotesController() : super([]) {
    _load();
  }

  void _load() {
    final box = HiveService.notesBox;
    state = box.values.toList();
  }

  void upsert(Note note) {
    final idx = state.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      final newList = [...state];
      newList[idx] = note;
      state = newList;
    } else {
      state = [...state, note];
    }
    HiveService.notesBox.put(note.id, note);
  }

  void delete(String noteId) {
    HiveService.notesBox.delete(noteId);
    state = state.where((n) => n.id != noteId).toList();
  }
}

final libraryProvider = StateNotifierProvider<LibraryController, List<Song>>((ref) {
  return LibraryController();
});

class LibraryController extends StateNotifier<List<Song>> {
  LibraryController() : super([]) {
    _load();
  }

  void _load() {
    final box = HiveService.libraryBox;
    state = box.values.toList();
  }

  void upsert(Song song) {
    final idx = state.indexWhere((s) => s.id == song.id);
    if (idx >= 0) {
      final newList = [...state];
      newList[idx] = song;
      state = newList;
    } else {
      state = [...state, song];
    }
    HiveService.libraryBox.put(song.id, song);
  }
}


