import 'dart:convert';

import '../../models/song.dart';
import '../../models/block.dart';
import '../storage/hive_service.dart';

/// Servicio para exportar/importar la biblioteca como archivo JSON (.chordvault).
///
/// Formato:
/// ```json
/// {
///   "format": "chordvault_library",
///   "version": 2,
///   "exportedAt": "2026-04-22T12:00:00Z",
///   "songs": [ ... ]
/// }
/// ```
class LibraryFile {
  /// Serializa lista de songs a JSON string (formato .chordvault).
  static String exportToJson(List<Song> songs) {
    final map = {
      'format': 'chordvault_library',
      'version': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'songs': songs.map(songToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parsea JSON string a lista de songs. Lanza FormatException si el JSON
  /// no tiene el formato esperado.
  static List<Song> importFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    if (map['format'] != 'chordvault_library') {
      throw const FormatException(
        'Archivo no válido: no es un archivo .chordvault',
      );
    }
    final songsRaw = map['songs'] as List<dynamic>? ?? [];
    return songsRaw
        .map((s) => songFromMap(s as Map<String, dynamic>))
        .whereType<Song>()
        .toList();
  }

  /// Compara dos songs para ver si son exactamente iguales
  /// (título, tono original, y todos los bloques).
  static bool areSongsEqual(Song a, Song b) {
    if (a.title != b.title) return false;
    if (a.originalKey != b.originalKey) return false;
    if (a.blocks.length != b.blocks.length) return false;
    for (int i = 0; i < a.blocks.length; i++) {
      if (a.blocks[i].type != b.blocks[i].type) return false;
      if (a.blocks[i].content != b.blocks[i].content) return false;
    }
    return true;
  }

  /// Filtra songs que ya existen en la biblioteca.
  /// Retorna solo las que NO están duplicadas.
  static List<Song> filterDuplicates(
    List<Song> toImport,
    List<Song> existing,
  ) {
    return toImport.where((imported) {
      return !existing.any((e) => areSongsEqual(e, imported));
    }).toList();
  }

  // --- Serialización interna ---

  static Map<String, dynamic> songToMap(Song song) {
    return {
      'title': song.title,
      'originalKey': song.originalKey,
      'tags': song.tags,
      'author': song.author,
      'blocks': [
        for (final b in song.blocks)
          {
            'type': b.type.name,
            'content': b.content,
          }
      ],
    };
  }

  static Song? songFromMap(Map<String, dynamic> s) {
    final List<dynamic> blocksRaw = s['blocks'] as List<dynamic>? ?? [];
    final id = HiveService.newId();
    return Song(
      id: id,
      title: (s['title'] as String?) ?? 'Canción',
      originalKey: s['originalKey'] as String?,
      tags: (s['tags'] as List?)?.cast<String>() ?? const [],
      author: s['author'] as String?,
      blocks: [
        for (final br in blocksRaw)
          Block(
            id: HiveService.newId(),
            type: _blockTypeFromString(
              (br as Map<String, dynamic>)['type'] as String? ?? 'text',
            ),
            content: (br['content'] as String?) ?? '',
          )
      ],
    );
  }

  static BlockType _blockTypeFromString(String v) {
    switch (v) {
      case 'chords':
        return BlockType.chords;
      case 'note':
        return BlockType.note;
      case 'text':
      default:
        return BlockType.text;
    }
  }
}
