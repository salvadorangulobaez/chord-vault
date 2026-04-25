import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../models/note.dart';
import '../../providers/app_providers.dart';
import '../../services/storage/hive_service.dart';
import '../note_editor_screen.dart';

/// Lógica unificada para insertar canciones en una nota (existente o nueva).
///
/// Muestra un bottom sheet con la lista de notas + opción "Nueva nota".
/// Distingue cancelar (null) de "nueva nota" (sentinel con id vacío).
Future<void> insertSongsToNote(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  final notes = ref.read(notesProvider);

  // Sentinel: id empty = "nueva nota"
  final sentinel = Note(
    id: '',
    title: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final result = await showModalBottomSheet<Note?>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (ctx, controller) => Scaffold(
        appBar: AppBar(
          title: const Text('Insertar en nota'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: ListView(
          controller: controller,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text('Nueva nota'),
              subtitle: const Text('Crear una nueva nota'),
              onTap: () => Navigator.pop(ctx, sentinel),
            ),
            const Divider(),
            ...notes.map((note) => ListTile(
                  title: Text(note.title),
                  subtitle: Text('${note.songs.length} canción(es)'),
                  onTap: () => Navigator.pop(ctx, note),
                )),
          ],
        ),
      ),
    ),
  );

  if (result == null) return; // Cancelled

  if (result.id.isEmpty) {
    // "Nueva nota" selected
    if (!context.mounted) return;
    final newNoteTitle = await showDialog<String>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Nueva nota'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Título de la nota',
              hintText: 'Mi nueva nota',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (newNoteTitle != null && newNoteTitle.isNotEmpty) {
      final newNote = Note(
        id: HiveService.newId(),
        title: newNoteTitle,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        songs: songs,
      );
      ref.read(notesProvider.notifier).upsert(newNote);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${songs.length} canción(es) agregada(s) a nueva nota "$newNoteTitle"',
            ),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(noteId: newNote.id),
          ),
        );
      }
    }
  } else {
    // Existing note selected
    final updatedSongs = [...result.songs, ...songs];
    final updatedNote = Note(
      id: result.id,
      title: result.title,
      createdAt: result.createdAt,
      updatedAt: DateTime.now(),
      songs: updatedSongs,
    );
    ref.read(notesProvider.notifier).upsert(updatedNote);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${songs.length} canción(es) agregada(s) a "${result.title}"',
          ),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(noteId: result.id),
        ),
      );
    }
  }
}
