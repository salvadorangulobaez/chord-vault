import 'dart:convert';

import '../../models/note.dart';
import '../../models/song.dart';
import '../storage/hive_service.dart';
import 'library_file.dart';

/// Servicio para exportar/importar notas completas como archivo JSON (.cvnote).
///
/// Formato:
/// ```json
/// {
///   "format": "chordvault_note",
///   "version": 1,
///   "exportedAt": "2026-04-25T12:00:00Z",
///   "notes": [ ... ]
/// }
/// ```
class NoteFile {
  /// Serializa lista de notas a JSON string (formato .cvnote).
  static String exportToJson(List<Note> notes) {
    final map = {
      'format': 'chordvault_note',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'notes': notes.map(_noteToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parsea JSON string a lista de notas. Lanza FormatException si el JSON
  /// no tiene el formato esperado.
  static List<Note> importFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    if (map['format'] != 'chordvault_note') {
      throw const FormatException(
        'Archivo no válido: no es un archivo .cvnote',
      );
    }
    final notesRaw = map['notes'] as List<dynamic>? ?? [];
    return notesRaw
        .map((n) => _noteFromMap(n as Map<String, dynamic>))
        .whereType<Note>()
        .toList();
  }

  // --- Serialización interna ---

  static Map<String, dynamic> _noteToMap(Note note) {
    return {
      'title': note.title,
      'createdAt': note.createdAt.toUtc().toIso8601String(),
      'updatedAt': note.updatedAt.toUtc().toIso8601String(),
      'songs': note.songs.map((s) => LibraryFile.songToMap(s)).toList(),
    };
  }

  static Note? _noteFromMap(Map<String, dynamic> n) {
    final List<dynamic> songsRaw = n['songs'] as List<dynamic>? ?? [];
    final id = HiveService.newId();
    final createdAtStr = n['createdAt'] as String?;
    final updatedAtStr = n['updatedAt'] as String?;
    DateTime parseOrNow(String? s) {
      if (s == null) return DateTime.now();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    try {
      return Note(
        id: id,
        title: (n['title'] as String?) ?? 'Nota',
        createdAt: parseOrNow(createdAtStr),
        updatedAt: parseOrNow(updatedAtStr),
        songs: songsRaw
            .map((s) {
              try {
                return LibraryFile.songFromMap(s as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<Song>()
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}
