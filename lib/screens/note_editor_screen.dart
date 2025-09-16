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
import '../services/io/text_format.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final Map<String, int> _transposeBySong = {}; // songId -> semitonos
  bool _fabMenuOpen = false;

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
        actions: [
          IconButton(
            tooltip: settings.readOnlyMode ? 'Modo edición' : 'Modo lectura',
            icon: Icon(settings.readOnlyMode ? Icons.edit : Icons.visibility),
            onPressed: () {
              final s = ref.read(settingsProvider);
              ref.read(settingsProvider.notifier).state = s.copyWith(readOnlyMode: !s.readOnlyMode);
            },
          ),
        ],
      ),
      body: note.songs.isEmpty
          ? const _EmptyNotePlaceholder()
          : ReorderableListView.builder(
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
                // Actualizar también el tono original si existe (o si está en el título)
                String? baseKey = song.originalKey;
                final titleMatch = RegExp(r"^(.*)\(([^)]+)\)\s*$").firstMatch(song.title);
                if ((baseKey == null || baseKey.isEmpty) && titleMatch != null) {
                  baseKey = titleMatch.group(2)!.trim();
                }
                final newKey = baseKey == null || baseKey.isEmpty
                    ? song.originalKey
                    : transposeKey(baseKey, semitones, preferSharps: settings.preferSharps);
                final updatedSong = Song(
                  id: song.id,
                  title: song.title,
                  blocks: updatedBlocks,
                  originalKey: newKey,
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
              readOnly: settings.readOnlyMode,
              onEditSong: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _SongEditorSheet(
                    note: note,
                    song: song,
                    onOriginalKeyChanged: () {
                      setState(() {
                        _transposeBySong[song.id] = 0;
                      });
                    },
                  ),
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
              onDelete: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Eliminar canción'),
                    content: Text('¿Eliminar "' + song.title + '" de esta nota?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (confirm == true) {
                  final updated = Note(
                    id: note.id,
                    title: note.title,
                    createdAt: note.createdAt,
                    updatedAt: DateTime.now(),
                    songs: [for (final s in note.songs) if (s.id != song.id) s],
                  );
                  ref.read(notesProvider.notifier).upsert(updated);
                  setState(() {});
                }
              },
              onSaveToLibrary: () {
                final libSong = Song(
                  id: HiveService.newId(),
                  title: song.title,
                  blocks: [for (final b in song.blocks) Block(id: HiveService.newId(), type: b.type, content: b.content)],
                  originalKey: song.originalKey,
                  tags: song.tags,
                  author: song.author,
                  isFavorite: song.isFavorite,
                );
                ref.read(libraryProvider.notifier).upsert(libSong);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardada en biblioteca')));
              },
            ),
          );
        },
      ),
      floatingActionButton: settings.readOnlyMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_fabMenuOpen) ...[
                  FloatingActionButton.extended(
                    heroTag: 'fab-insert-lib',
                    onPressed: () async {
                      final picked = await showModalBottomSheet<Song>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _LibraryPickerSheet(),
                      );
                      if (picked != null) {
                        final updated = Note(
                          id: note.id,
                          title: note.title,
                          createdAt: note.createdAt,
                          updatedAt: DateTime.now(),
                          songs: [...note.songs, picked],
                        );
                        ref.read(notesProvider.notifier).upsert(updated);
                        setState(() {});
                      }
                      setState(() => _fabMenuOpen = false);
                    },
                    icon: const Icon(Icons.library_add),
                    label: const Text('Insertar de biblioteca'),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.extended(
                    heroTag: 'fab-add-song',
                    onPressed: () async {
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
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _SongEditorSheet(
                          note: updated,
                          song: song,
                          onOriginalKeyChanged: () {
                            setState(() {
                              _transposeBySong[song.id] = 0;
                            });
                          },
                        ),
                      );
                      if (mounted) setState(() {});
                      setState(() => _fabMenuOpen = false);
                    },
                    icon: const Icon(Icons.music_note),
                    label: const Text('Añadir canción'),
                  ),
                  const SizedBox(height: 8),
                ],
                FloatingActionButton(
                  heroTag: 'fab-main',
                  onPressed: () => setState(() => _fabMenuOpen = !_fabMenuOpen),
                  child: Icon(_fabMenuOpen ? Icons.close : Icons.add),
                ),
              ],
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
                  // Importar texto solo en biblioteca/nota desde FAB 'Insertar de biblioteca';
                  // Se retiró aquí por requerimiento.
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showModalBottomSheet<Song>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const _LibraryPickerSheet(),
                      );
                      if (picked != null) {
                        final updated = Note(
                          id: note.id,
                          title: note.title,
                          createdAt: note.createdAt,
                          updatedAt: DateTime.now(),
                          songs: [...note.songs, picked],
                        );
                        ref.read(notesProvider.notifier).upsert(updated);
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.library_add),
                    label: const Text('Insertar de biblioteca'),
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
    required this.readOnly,
    required this.onEditSong,
    required this.onCopy,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSaveToLibrary,
  });

  final Song song;
  final int semitones;
  final void Function(int delta) onTranspose;
  final VoidCallback onReset;
  final VoidCallback onApplyPermanently;
  final bool preferSharps;
  final bool readOnly;
  final VoidCallback onEditSong;
  final VoidCallback onCopy;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onSaveToLibrary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!readOnly) Row(
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
                      case 'save_library':
                        onSaveToLibrary();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'copy', child: Text('Copiar')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(value: 'save_library', child: Text('Guardar en biblioteca')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _displayTitleWithKey(song.title, song.originalKey, semitones, preferSharps: preferSharps),
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

String _displayTitleWithKey(String title, String? originalKey, int semitones, {required bool preferSharps}) {
  // Si no hay tono definido, intenta detectar uno entre paréntesis ya existente.
  String baseTitle = title;
  String? key = originalKey;
  final match = RegExp(r"^(.*)\(([^)]+)\)\s*$").firstMatch(title);
  if (match != null) {
    baseTitle = match.group(1)!.trim();
    key ??= match.group(2)!.trim();
  }
  if (key == null || key.isEmpty) return baseTitle;
  final transposed = transposeKey(key, semitones, preferSharps: preferSharps);
  return baseTitle.isEmpty ? transposed : baseTitle + ' (' + transposed + ')';
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
  const _SongEditorSheet({required this.note, required this.song, this.onOriginalKeyChanged});
  final Note note;
  final Song song;
  final VoidCallback? onOriginalKeyChanged;

  @override
  ConsumerState<_SongEditorSheet> createState() => _SongEditorSheetState();
}

class _SongEditorSheetState extends ConsumerState<_SongEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _keyCtrl;
  late List<Block> _blocks;
  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.song.title);
    _keyCtrl = TextEditingController(text: widget.song.originalKey ?? '');
    _blocks = widget.song.blocks
        .map((b) => Block(id: b.id, type: b.type, content: b.content))
        .toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _save(Note note, Song song, List<Block> blocks, String title) {
    final updatedSong = Song(
      id: song.id,
      title: title,
      blocks: blocks,
      originalKey: _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
      tags: song.tags,
      author: song.author,
      isFavorite: song.isFavorite,
    );
    // Si cambia el tono original, reseteamos transposición de vista para esta canción
    final prevKey = song.originalKey?.trim();
    final newKey = _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim();
    if (prevKey != newKey) {
      widget.onOriginalKeyChanged?.call();
    }
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
                TextField(
                  controller: _keyCtrl,
                  decoration: const InputDecoration(labelText: 'Tono (ej. D, Bb, F#)'),
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


class _LibraryPickerSheet extends ConsumerWidget {
  const _LibraryPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(libraryProvider);
    final query = ref.watch(_libPickerSearchProvider);
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? songs
        : songs.where((s) => s.title.toLowerCase().contains(q) || (s.tags.join(' ').toLowerCase().contains(q))).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) {
        return Scaffold(
          appBar: AppBar(
            title: SizedBox(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar en biblioteca',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => ref.read(_libPickerSearchProvider.notifier).state = '',
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (v) => ref.read(_libPickerSearchProvider.notifier).state = v,
              ),
            ),
          ),
          body: ListView.builder(
            controller: controller,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final s = filtered[index];
              return ListTile(
                title: Text(s.title),
                subtitle: Text(s.originalKey ?? ''),
                onTap: () {
                  // devolver la canción seleccionada
                  Navigator.pop(context, s);
                },
              );
            },
          ),
        );
      },
    );
  }
}

final _libPickerSearchProvider = StateProvider<String>((ref) => '');

class _EmptyNotePlaceholder extends StatelessWidget {
  const _EmptyNotePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
            const SizedBox(height: 12),
            Text(
              'Tu nota está vacía',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tocá el botón + para añadir una canción o insertar desde la biblioteca.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
