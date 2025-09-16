import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/note.dart';
import '../models/song.dart';
import '../models/block.dart';
import '../services/chords/parser.dart';
import '../services/chords/transpose.dart';
import '../services/storage/hive_service.dart';
import '../services/clipboard/song_clipboard.dart';

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
      appBar: AppBar(
        title: TextFormField(
          initialValue: note.title,
          decoration: const InputDecoration(border: InputBorder.none, hintText: 'Título de la nota'),
          style: Theme.of(context).textTheme.titleLarge,
          onChanged: (v) {
            final updated = Note(
              id: note.id,
              title: v,
              createdAt: note.createdAt,
              updatedAt: DateTime.now(),
              songs: note.songs,
            );
            ref.read(notesProvider.notifier).upsert(updated);
          },
        ),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: note.songs.length,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Opacity(
                opacity: 0.9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          final newSongs = [...note.songs];
          final moved = newSongs.removeAt(oldIndex);
          newSongs.insert(newIndex, moved);
          final updated = Note(
            id: note.id,
            title: note.title,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
            songs: newSongs,
          );
          ref.read(notesProvider.notifier).upsert(updated);
          setState(() {});
        },
        itemBuilder: (context, index) {
          final song = note.songs[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(song.id),
            index: index,
            child: _SongCard(
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
              onEditSong: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _SongEditorSheet(note: note, song: song),
                );
                setState(() {});
              },
              onCopy: () async {
                await copySongToClipboard(song);
                ref.read(clipboardSongAvailableProvider.notifier).state = true;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción copiada')));
                }
              },
              onDuplicate: () {
                final newSong = Song(
                  id: HiveService.newId(),
                  title: song.title + ' (copia)',
                  blocks: [for (final b in song.blocks) Block(id: HiveService.newId(), type: b.type, content: b.content)],
                  originalKey: song.originalKey,
                  tags: song.tags,
                  author: song.author,
                  isFavorite: song.isFavorite,
                );
                final updated = Note(
                  id: note.id,
                  title: note.title,
                  createdAt: note.createdAt,
                  updatedAt: DateTime.now(),
                  songs: [...note.songs, newSong],
                );
                ref.read(notesProvider.notifier).upsert(updated);
                setState(() {});
              },
              onDelete: () {
                final updated = Note(
                  id: note.id,
                  title: note.title,
                  createdAt: note.createdAt,
                  updatedAt: DateTime.now(),
                  songs: [for (final s in note.songs) if (s.id != song.id) s],
                );
                ref.read(notesProvider.notifier).upsert(updated);
                setState(() {});
              },
            ),
          );
        },
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
      bottomNavigationBar: ref.watch(clipboardSongAvailableProvider)
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final paste = await pasteSongFromClipboard();
                        if (paste == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Portapapeles sin canción válida')));
                          }
                          return;
                        }
                        final updated = Note(
                          id: note.id,
                          title: note.title,
                          createdAt: note.createdAt,
                          updatedAt: DateTime.now(),
                          songs: [...note.songs, paste],
                        );
                        ref.read(notesProvider.notifier).upsert(updated);
                        ref.read(clipboardSongAvailableProvider.notifier).state = false;
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción pegada')));
                        }
                      },
                      icon: const Icon(Icons.paste),
                      label: const Text('Pegar canción'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => ref.read(clipboardSongAvailableProvider.notifier).state = false,
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancelar pegar',
                  ),
                ],
              ),
            )
          : null,
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
    required this.onEditSong,
    required this.onCopy,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Song song;
  final int semitones;
  final void Function(int delta) onTranspose;
  final VoidCallback onReset;
  final VoidCallback onApplyPermanently;
  final bool preferSharps;
  final VoidCallback onEditSong;
  final VoidCallback onCopy;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

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
                const Spacer(),
                IconButton(onPressed: onEditSong, tooltip: 'Editar', icon: const Icon(Icons.edit)),
                IconButton(onPressed: () => onTranspose(-1), icon: const Icon(Icons.remove)),
                Text('$semitones'),
                IconButton(onPressed: () => onTranspose(1), icon: const Icon(Icons.add)),
                TextButton(onPressed: onReset, child: const Text('Reset')),
                TextButton(onPressed: onApplyPermanently, child: const Text('Aplicar')),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'copy':
                        onCopy();
                        break;
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'copy', child: Text('Copiar')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) + 1,
                  ),
            ),
            const SizedBox(height: 8),
            for (final block in song.blocks) ...[
              if (block.type == BlockType.text)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    block.content.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                )
              else if (block.type == BlockType.note)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    block.content,
                    style: Theme.of(context).textTheme.bodyMedium,
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
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              softWrap: true,
              overflow: TextOverflow.visible,
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

class _SongEditorSheet extends ConsumerStatefulWidget {
  const _SongEditorSheet({required this.note, required this.song});
  final Note note;
  final Song song;

  @override
  ConsumerState<_SongEditorSheet> createState() => _SongEditorSheetState();
}

class _SongEditorSheetState extends ConsumerState<_SongEditorSheet> {
  late TextEditingController _titleCtrl;
  late List<Block> _blocks;
  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.song.title);
    _blocks = widget.song.blocks
        .map((b) => Block(id: b.id, type: b.type, content: b.content))
        .toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _save(Note note, Song song, List<Block> blocks, String title) {
    final updatedSong = Song(
      id: song.id,
      title: title,
      blocks: blocks,
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
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final song = widget.song;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Editar canción'),
              actions: [
                TextButton(
                  onPressed: () {
                    _save(note, song, _blocks, _titleCtrl.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
            body: ListView(
              controller: controller,
              padding: const EdgeInsets.all(12),
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título de la canción'),
                ),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _blocks.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _blocks.removeAt(oldIndex);
                    _blocks.insert(newIndex, item);
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final b = _blocks[index];
                    return Card(
                      key: ValueKey(b.id),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                DropdownButton<BlockType>(
                                  value: b.type,
                                  items: const [
                                    DropdownMenuItem(value: BlockType.text, child: Text('Etiqueta')),
                                    DropdownMenuItem(value: BlockType.chords, child: Text('Acordes')),
                                    DropdownMenuItem(value: BlockType.note, child: Text('Nota')),
                                  ],
                                  onChanged: (t) {
                                    if (t != null) {
                                      _blocks[index] = Block(id: b.id, type: t, content: b.content);
                                      setState(() {});
                                    }
                                  },
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    _blocks.removeAt(index);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.delete),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _blocks.insert(index + 1, Block(id: HiveService.newId(), type: b.type, content: b.content));
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.copy),
                                ),
                              ],
                            ),
                            TextField(
                              controller: TextEditingController(text: b.content),
                              maxLines: b.type == BlockType.chords ? null : 3,
                              decoration: InputDecoration(
                                labelText: b.type == BlockType.chords ? 'Acordes (por espacios)' : (b.type == BlockType.text ? 'Etiqueta' : 'Nota'),
                              ),
                              onChanged: (v) {
                                _blocks[index] = Block(id: b.id, type: b.type, content: v);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _blocks.add(Block(id: HiveService.newId(), type: BlockType.text, content: 'INTRO'));
                        setState(() {});
                      },
                      icon: const Icon(Icons.label),
                      label: const Text('Agregar etiqueta'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _blocks.add(Block(id: HiveService.newId(), type: BlockType.chords, content: ''));
                        setState(() {});
                      },
                      icon: const Icon(Icons.music_note),
                      label: const Text('Agregar acordes'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _blocks.add(Block(id: HiveService.newId(), type: BlockType.note, content: ''));
                        setState(() {});
                      },
                      icon: const Icon(Icons.note_alt),
                      label: const Text('Agregar nota'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


