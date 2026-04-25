import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_providers.dart';
import '../models/note.dart';
import '../models/song.dart';
import '../models/block.dart';
import '../services/chords/parser.dart';
import '../services/chords/transpose.dart';
import '../services/storage/hive_service.dart';
import '../services/clipboard/song_clipboard.dart';
import '../services/io/text_format.dart';
import '../utils/title_utils.dart';
import 'widgets/song_text_editor.dart';

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
        title: settings.readOnlyMode
            ? Text(
                note.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16, // Tamaño más pequeño en modo lectura
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )
            : TextFormField(
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
          // Controles de tamaño de fuente (solo en modo lectura)
          if (settings.readOnlyMode) ...[
            IconButton(
              onPressed: settings.fontScale > 0.8
                  ? () {
                      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(
                        fontScale: (settings.fontScale - 0.1).clamp(0.8, 2.0),
                      ));
                    }
                  : null,
              icon: const Icon(Icons.text_decrease),
              tooltip: 'Reducir fuente',
            ),
            Text(
              '${(settings.fontScale * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IconButton(
              onPressed: settings.fontScale < 2.0
                  ? () {
                      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(
                        fontScale: (settings.fontScale + 0.1).clamp(0.8, 2.0),
                      ));
                    }
                  : null,
              icon: const Icon(Icons.text_increase),
              tooltip: 'Aumentar fuente',
            ),
          ],
          IconButton(
            tooltip: settings.readOnlyMode ? 'Modo edición' : 'Modo lectura',
            icon: Icon(settings.readOnlyMode ? Icons.edit : Icons.visibility),
            onPressed: () {
              final s = ref.read(settingsProvider);
              ref.read(settingsProvider.notifier).updateSettings(s.copyWith(readOnlyMode: !s.readOnlyMode));
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
                    color: Colors.grey.withValues(alpha: 0.2),
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
                  builder: (_) => SongTextEditor(
                    initialSong: song,
                    title: 'Editar canción',
                    onSave: (updatedSong) {
                      // Si cambia el tono original, reseteamos transposición
                      if (song.originalKey != updatedSong.originalKey) {
                        _transposeBySong[song.id] = 0;
                      }
                      final updatedNote = Note(
                        id: note.id,
                        title: note.title,
                        createdAt: note.createdAt,
                        updatedAt: DateTime.now(),
                        songs: [
                          for (final s in note.songs)
                            if (s.id == song.id) updatedSong else s
                        ],
                      );
                      ref.read(notesProvider.notifier).upsert(updatedNote);
                    },
                  ),
                );
                setState(() {});
              },
              onCopy: () async {
                await copySongToClipboard(song);
                ref.read(clipboardSongAvailableProvider.notifier).state = true;
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción copiada')));
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
              fontScale: settings.fontScale,
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
                    heroTag: 'fab-import-text',
                    onPressed: () async {
                      final text = await showDialog<String>(
                        context: context,
                        builder: (_) {
                          final ctrl = TextEditingController();
                          return AlertDialog(
                            title: const Text('Pegar canciones'),
                            content: TextField(controller: ctrl, maxLines: 10),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                              TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Importar')),
                            ],
                          );
                        },
                      );
                      if (text != null && text.trim().isNotEmpty) {
                        final parsed = TextFormat.parseSongs(text, idGen: () => HiveService.newId());
                        if (parsed.isNotEmpty) {
                          final updated = Note(
                            id: note.id,
                            title: note.title,
                            createdAt: note.createdAt,
                            updatedAt: DateTime.now(),
                            songs: [...note.songs, ...parsed],
                          );
                          ref.read(notesProvider.notifier).upsert(updated);
                          setState(() {});
                        }
                      }
                      setState(() => _fabMenuOpen = false);
                    },
                    icon: const Icon(Icons.input),
                    label: const Text('Importar texto'),
                  ),
                  const SizedBox(height: 8),
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
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SongTextEditor(
                          title: 'Nueva canción',
                          onSave: (song) {
                            final updated = Note(
                              id: note.id,
                              title: note.title,
                              createdAt: note.createdAt,
                              updatedAt: DateTime.now(),
                              songs: [...note.songs, song],
                            );
                            ref.read(notesProvider.notifier).upsert(updated);
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
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Portapapeles sin canción válida')));
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
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canción pegada')));
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
    required this.fontScale,
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
  final double fontScale;

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
                      case 'export_text':
                        final text = TextFormat.exportSong(song);
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Canción copiada como texto')),
                          );
                        }
                        break;
                      case 'share':
                        final text = TextFormat.exportSong(song);
                        await Share.share(text);
                        break;
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
                    PopupMenuItem(value: 'export_text', child: Text('Copiar como texto')),
                    PopupMenuItem(value: 'share', child: Text('Compartir')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'copy', child: Text('Copiar (interno)')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                    PopupMenuItem(value: 'save_library', child: Text('Guardar en biblioteca')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              displayTitleWithKey(song.title, song.originalKey, semitones, preferSharps: preferSharps),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ((Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) + 1) * fontScale,
                  ),
            ),
            const SizedBox(height: 8),
            for (final block in song.blocks) ...[
              if (block.type == BlockType.text)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    block.content.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
                    ),
                  ),
                )
              else if (block.type == BlockType.note)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 14 * fontScale,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          block.content,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * fontScale,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _ChordBlockView(
                  content: block.content,
                  semitones: semitones,
                  preferSharps: preferSharps,
                  fontScale: fontScale,
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
    required this.fontScale,
  });

  final String content;
  final int semitones;
  final bool preferSharps;
  final double fontScale;

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
              style: TextStyle(fontFamily: 'monospace', fontSize: 13 * fontScale),
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

// _SongEditorSheet removed — replaced by SongTextEditor widget


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
            Icon(Icons.library_music, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)),
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
