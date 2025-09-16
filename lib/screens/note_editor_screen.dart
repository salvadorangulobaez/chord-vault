import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/note.dart';
import '../models/song.dart';
import '../models/block.dart';
import '../services/chords/parser.dart';
import '../services/chords/transpose.dart';
import '../services/storage/hive_service.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final Map<String, int> _transposeBySong = {}; // songId -> semitonos

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final settings = ref.watch(settingsProvider);
    final note = notes.firstWhere((n) => n.id == widget.noteId);
    return Scaffold(
      appBar: AppBar(title: Text(note.title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final song in note.songs) _SongCard(
            song: song,
            semitones: _transposeBySong[song.id] ?? 0,
            onTranspose: (delta) {
              setState(() {
                _transposeBySong[song.id] = (_transposeBySong[song.id] ?? 0) + delta;
              });
            },
            onReset: () {
              setState(() {
                _transposeBySong[song.id] = 0;
              });
            },
            onApplyPermanently: () {
              final semitones = _transposeBySong[song.id] ?? 0;
              if (semitones == 0) return;
              final updatedBlocks = song.blocks.map((b) {
                if (b.type == BlockType.chords) {
                  final lines = b.content.split('\n');
                  final out = lines.map((line) {
                    final tokens = parseLineToTokens(line);
                    return tokens
                        .map((t) => t.isChord
                            ? transposeToken(t.raw, semitones, TransposeOptions(preferSharps: settings.preferSharps))
                            : t.raw)
                        .join(' ');
                  }).join('\n');
                  return Block(id: b.id, type: b.type, content: out);
                }
                return b;
              }).toList();
              final updatedSong = Song(
                id: song.id,
                title: song.title,
                blocks: updatedBlocks,
                originalKey: song.originalKey,
                tags: song.tags,
                author: song.author,
                isFavorite: song.isFavorite,
              );
              final updatedNote = Note(
                id: note.id,
                title: note.title,
                createdAt: note.createdAt,
                updatedAt: DateTime.now(),
                songs: [
                  for (final s in note.songs) if (s.id == song.id) updatedSong else s
                ],
              );
              ref.read(notesProvider.notifier).upsert(updatedNote);
              setState(() {
                _transposeBySong[song.id] = 0;
              });
            },
            preferSharps: settings.preferSharps,
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final song = Song(
            id: HiveService.newId(),
            title: 'Nueva canción',
            blocks: [
              Block(id: HiveService.newId(), type: BlockType.text, content: 'INTRO'),
              Block(id: HiveService.newId(), type: BlockType.chords, content: 'D A Bm G'),
            ],
          );
          final updated = Note(
            id: note.id,
            title: note.title,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
            songs: [...note.songs, song],
          );
          ref.read(notesProvider.notifier).upsert(updated);
        },
        icon: const Icon(Icons.music_note),
        label: const Text('Añadir canción'),
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.semitones,
    required this.onTranspose,
    required this.onReset,
    required this.onApplyPermanently,
    required this.preferSharps,
  });

  final Song song;
  final int semitones;
  final void Function(int delta) onTranspose;
  final VoidCallback onReset;
  final VoidCallback onApplyPermanently;
  final bool preferSharps;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(onPressed: () => onTranspose(-1), icon: const Icon(Icons.remove)),
                Text('$semitones'),
                IconButton(onPressed: () => onTranspose(1), icon: const Icon(Icons.add)),
                TextButton(onPressed: onReset, child: const Text('Reset')),
                TextButton(onPressed: onApplyPermanently, child: const Text('Aplicar')),
              ],
            ),
            const SizedBox(height: 8),
            for (final block in song.blocks) ...[
              if (block.type == BlockType.text)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    block.content.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              else
                _ChordBlockView(
                  content: block.content,
                  semitones: semitones,
                  preferSharps: preferSharps,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChordBlockView extends StatelessWidget {
  const _ChordBlockView({
    required this.content,
    required this.semitones,
    required this.preferSharps,
  });

  final String content;
  final int semitones;
  final bool preferSharps;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final options = TransposeOptions(preferSharps: preferSharps);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(
              _transposeLine(line, semitones, options),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
        ],
      ),
    );
  }

  String _transposeLine(String line, int semi, TransposeOptions options) {
    final tokens = parseLineToTokens(line);
    return tokens.map((t) => t.isChord ? transposeToken(t.raw, semi, options) : t.raw).join(' ');
  }
}


