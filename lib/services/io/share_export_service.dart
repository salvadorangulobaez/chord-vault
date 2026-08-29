import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../models/note.dart';
import '../../models/song.dart';
import 'library_file.dart';
import 'note_file.dart';
import 'text_format.dart';

/// Servicio centralizado para exportar/compartir notas y canciones.
///
/// Extrae la duplicación previa de ~30 líneas × 4 sitios (home, library,
/// note_editor). Screens solo llaman estos helpers y chequean `mounted`.
class ShareExportService {
  static const _sanitizeRegex = r'[^\w\-]+';

  /// Sanitiza un título para uso como nombre de archivo.
  static String sanitizeTitle(String title) =>
      title.replaceAll(RegExp(_sanitizeRegex), '_');

  /// Crea un archivo temporal con el contenido dado.
  static Future<File> writeTempFile(
    String content, {
    required String prefix,
    required String extension,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${prefix}_${const Uuid().v4()}.$extension');
    return file.writeAsString(content);
  }

  static Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// Comparte un archivo usando `share_plus` con soporte para iPad `sharePositionOrigin`.
  static Future<void> shareFile(
    File file,
    String shareText,
    BuildContext context,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } else {
      await Share.shareXFiles([XFile(file.path)], text: shareText);
    }
  }

  // --- Notas ---

  static Future<void> copyNotesAsText(List<Note> notes) async {
    final text = TextFormat.exportNotes(notes, forSharing: false);
    await copyText(text);
  }

  static Future<void> shareNotesAsText(List<Note> notes) async {
    final text = TextFormat.exportNotes(notes, forSharing: true);
    await Share.share(text);
  }

  static Future<File> exportNotesToFile(
    List<Note> notes, {
    String? prefixOverride,
  }) async {
    final jsonStr = NoteFile.exportToJson(notes);
    final prefix = prefixOverride ??
        (notes.length == 1
            ? 'nota_${sanitizeTitle(notes.first.title)}'
            : 'exportacion_notas');
    return writeTempFile(jsonStr, prefix: prefix, extension: 'cvnote');
  }

  static Future<void> exportAndShareNotes(
    List<Note> notes,
    BuildContext context,
  ) async {
    final file = await exportNotesToFile(notes);
    if (!context.mounted) return;
    await shareFile(
      file,
      'Exportación de ChordVault (${notes.length} notas)',
      context,
    );
  }

  static Future<void> exportAndShareSingleNote(
    Note note,
    BuildContext context, {
    List<Song>? selectedSongs,
  }) async {
    final songs = selectedSongs ?? note.songs;
    final noteToExport = Note(
      id: note.id,
      title: note.title,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      songs: songs,
    );
    final jsonStr = NoteFile.exportToJson([noteToExport]);
    final file = await writeTempFile(
      jsonStr,
      prefix: 'nota_${sanitizeTitle(note.title)}',
      extension: 'cvnote',
    );
    if (!context.mounted) return;
    await shareFile(file, 'Nota: ${note.title}', context);
  }

  // --- Canciones (biblioteca) ---

  static Future<void> copySongsAsText(List<Song> songs) async {
    final text = TextFormat.exportSongs(songs);
    await copyText(text);
  }

  static Future<void> shareSongsAsText(List<Song> songs) async {
    final text = TextFormat.shareSongsAsText(songs);
    await Share.share(text);
  }

  static Future<File> exportSongsToFile(List<Song> songs) async {
    final jsonStr = LibraryFile.exportToJson(songs);
    return writeTempFile(
      jsonStr,
      prefix: 'exportacion_cancionero',
      extension: 'chordvault',
    );
  }

  static Future<void> exportAndShareSongs(
    List<Song> songs,
    BuildContext context,
  ) async {
    final file = await exportSongsToFile(songs);
    if (!context.mounted) return;
    await shareFile(
      file,
      'Exportación de ChordVault (${songs.length} canciones)',
      context,
    );
  }
}
