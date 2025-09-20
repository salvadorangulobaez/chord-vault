import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../models/song.dart';
import '../services/storage/hive_service.dart';

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController();
});

class SettingsState {
  SettingsState({this.preferSharps = true, this.fontScale = 1.0, this.readOnlyMode = false, this.gridView = false});
  final bool preferSharps;
  final double fontScale;
  final bool readOnlyMode;
  final bool gridView;

  SettingsState copyWith({bool? preferSharps, double? fontScale, bool? readOnlyMode, bool? gridView}) =>
      SettingsState(
        preferSharps: preferSharps ?? this.preferSharps,
        fontScale: fontScale ?? this.fontScale,
        readOnlyMode: readOnlyMode ?? this.readOnlyMode,
        gridView: gridView ?? this.gridView,
      );
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController() : super(SettingsState()) {
    _load();
  }

  void _load() {
    final box = HiveService.settingsBox;
    final preferSharps = box.get('preferSharps', defaultValue: true) as bool;
    final fontScale = box.get('fontScale', defaultValue: 1.0) as double;
    final readOnlyMode = box.get('readOnlyMode', defaultValue: false) as bool;
    final gridView = box.get('gridView', defaultValue: false) as bool;
    
    state = SettingsState(
      preferSharps: preferSharps,
      fontScale: fontScale,
      readOnlyMode: readOnlyMode,
      gridView: gridView,
    );
  }

  void updateSettings(SettingsState newSettings) {
    state = newSettings;
    _save();
  }

  void _save() {
    final box = HiveService.settingsBox;
    box.put('preferSharps', state.preferSharps);
    box.put('fontScale', state.fontScale);
    box.put('readOnlyMode', state.readOnlyMode);
    box.put('gridView', state.gridView);
  }
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

  void delete(String songId) {
    HiveService.libraryBox.delete(songId);
    state = state.where((s) => s.id != songId).toList();
  }
}

// Clipboard state to enable/disable paste button
final clipboardSongAvailableProvider = StateProvider<bool>((ref) => false);


