import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/note.dart';
import '../services/storage/hive_service.dart';
import 'note_editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancionero'),
      ),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          final snippet = note.songs.isNotEmpty && note.songs.first.blocks.isNotEmpty
              ? note.songs.first.blocks.first.content.split('\n').first
              : '';
          return ListTile(
            title: Text(note.title),
            subtitle: Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NoteEditorScreen(noteId: note.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final id = HiveService.newId();
          final note = Note(
            id: id,
            title: 'Nota ${notes.length + 1}',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          ref.read(notesProvider.notifier).upsert(note);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditorScreen(noteId: id),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


