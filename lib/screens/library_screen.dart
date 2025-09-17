import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../providers/app_providers.dart';
import '../models/song.dart';
import '../models/note.dart';
import '../models/block.dart';
import '../services/storage/hive_service.dart';
import '../services/io/text_format.dart';
import 'note_editor_screen.dart';
import 'song_preview_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final search = ref.watch(_libSearchProvider);
    final sort = ref.watch(_libSortProvider);
    final selecting = ref.watch(_libSelectingProvider);
    final selectedSet = ref.watch(_libSelectedSetProvider);

    // Filtrar y ordenar
    var filtered = library.where((s) => s.title.toLowerCase().contains(search.toLowerCase())).toList();
    switch (sort) {
      case LibrarySort.alphaAsc:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.alphaDesc:
        filtered.sort((a, b) => b.title.compareTo(a.title));
      case LibrarySort.updatedDesc:
        filtered.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
      case LibrarySort.createdDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Scaffold(
      appBar: AppBar(
        title: selecting ? Text('${selectedSet.length} seleccionada(s)') : null,
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  ref.read(_libSelectingProvider.notifier).state = false;
                  ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                },
              )
            : null,
        actions: selecting
            ? []
            : [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar canciones...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => ref.read(_libSearchProvider.notifier).state = v,
                    ),
                  ),
                ),
                PopupMenuButton<LibrarySort>(
                  icon: const Icon(Icons.sort),
                  onSelected: (sort) => ref.read(_libSortProvider.notifier).state = sort,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: LibrarySort.alphaAsc, child: Text('A-Z')),
                    PopupMenuItem(value: LibrarySort.alphaDesc, child: Text('Z-A')),
                    PopupMenuItem(value: LibrarySort.updatedDesc, child: Text('Actualización')),
                    PopupMenuItem(value: LibrarySort.createdDesc, child: Text('Creación')),
                  ],
                ),
                IconButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _LibrarySongEditor(
                      song: Song(
                        id: HiveService.newId(),
                        title: '',
                        blocks: [],
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                      isNew: true,
                    ),
                  ),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  onPressed: () async {
                    final text = await Clipboard.getData(Clipboard.kTextPlain);
                    if (text?.text?.isNotEmpty == true && context.mounted) {
                      try {
                        final songs = parseSongsFromText(text!.text!);
                        for (final song in songs) {
                          ref.read(libraryProvider.notifier).upsert(song);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${songs.length} canción(es) importada(s)')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al importar: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.content_paste),
                ),
              ],
      ),
      body: filtered.isEmpty
          ? const Center(child: Text('No hay canciones en la biblioteca'))
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final s = filtered[index];
                final selected = selectedSet.contains(s.id);
                return InkWell(
                  onLongPress: selecting
                      ? null
                      : () {
                          ref.read(_libSelectingProvider.notifier).state = true;
                          final set = {...ref.read(_libSelectedSetProvider)};
                          set.add(s.id);
                          ref.read(_libSelectedSetProvider.notifier).state = set;
                        },
                  onTap: selecting
                      ? () {
                          final set = {...ref.read(_libSelectedSetProvider)};
                          set.contains(s.id) ? set.remove(s.id) : set.add(s.id);
                          ref.read(_libSelectedSetProvider.notifier).state = set;
                        }
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SongPreviewScreen(songId: s.id),
                            ),
                          );
                        },
                  child: ListTile(
                    title: Text(s.title),
                    subtitle: Text(s.originalKey ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    leading: selecting
                        ? Checkbox(
                            value: selected,
                            onChanged: (v) {
                              final set = {...ref.read(_libSelectedSetProvider)};
                              v == true ? set.add(s.id) : set.remove(s.id);
                              ref.read(_libSelectedSetProvider.notifier).state = set;
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    trailing: selecting
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) async {
                              switch (v) {
                                case 'edit':
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _LibrarySongEditor(song: s, isNew: false),
                                  );
                                case 'delete':
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Confirmar eliminación'),
                                      content: Text('¿Eliminar "${s.title}" de la biblioteca?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    ref.read(libraryProvider.notifier).delete(s.id);
                                  }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                            ],
                          ),
                  ),
                );
              },
            ),
      bottomNavigationBar: selecting
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: selectedSet.isEmpty
                        ? null
                        : () {
                            final allSelected = selectedSet.length == filtered.length;
                            if (allSelected) {
                              ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                            } else {
                              ref.read(_libSelectedSetProvider.notifier).state = filtered.map((s) => s.id).toSet();
                            }
                          },
                    icon: Icon(selectedSet.length == filtered.length ? Icons.deselect : Icons.select_all),
                    tooltip: selectedSet.length == filtered.length ? 'Deseleccionar' : 'Seleccionar todo',
                  ),
                  IconButton(
                    onPressed: selectedSet.isEmpty
                        ? null
                        : () async {
                            final toInsert = library.where((s) => selectedSet.contains(s.id)).toList();
                            final notes = ref.read(notesProvider);
                            
                            final result = await showModalBottomSheet<Note?>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => DraggableScrollableSheet(
                                expand: false,
                                initialChildSize: 0.7,
                                maxChildSize: 0.9,
                                minChildSize: 0.3,
                                builder: (_, controller) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Insertar canciones'),
                                    automaticallyImplyLeading: false,
                                    actions: [
                                      IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                  body: ListView(
                                    controller: controller,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.add, color: Colors.green),
                                        title: const Text('Nueva nota'),
                                        subtitle: const Text('Crear una nueva nota'),
                                        onTap: () => Navigator.pop(context, null), // null = nueva nota
                                      ),
                                      const Divider(),
                                      ...notes.map((note) => ListTile(
                                        title: Text(note.title),
                                        subtitle: Text('${note.songs.length} canciones'),
                                        onTap: () => Navigator.pop(context, note),
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            
                            // result puede ser null (nueva nota), una Note (nota existente), o null (cancelado)
                            if (result != null || result == null) {
                              // Si result es null, significa que se seleccionó "Nueva nota"
                              if (result == null) {
                                // Crear nueva nota
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
                                    songs: toInsert,
                                  );
                                  ref.read(notesProvider.notifier).upsert(newNote);
                                  
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${toInsert.length} canción(es) agregada(s) a nueva nota "$newNoteTitle"')),
                                    );
                                    
                                    // Navegar a la nueva nota
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NoteEditorScreen(noteId: newNote.id),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // Agregar a nota existente
                                final updatedSongs = [...result.songs, ...toInsert];
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
                                    SnackBar(content: Text('${toInsert.length} canción(es) agregada(s) a "${result.title}"')),
                                  );
                                  
                                  // Navegar a la nota existente
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteEditorScreen(noteId: result.id),
                                    ),
                                  );
                                }
                              }
                              
                              // Salir del modo selección
                              ref.read(_libSelectingProvider.notifier).state = false;
                              ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                            }
                          },
                    icon: const Icon(Icons.add_to_queue),
                    tooltip: 'Insertar en nota',
                  ),
                  IconButton(
                    onPressed: selectedSet.isEmpty
                        ? null
                        : () async {
                            final toExport = library.where((s) => selectedSet.contains(s.id)).toList();
                            final text = toExport.map(songToText).join('\n\n---\n\n');
                            await Clipboard.setData(ClipboardData(text: text));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${toExport.length} canción(es) exportada(s)')),
                              );
                            }
                          },
                    icon: const Icon(Icons.file_upload),
                    tooltip: 'Exportar seleccionados',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

final _libSearchProvider = StateProvider<String>((ref) => '');
enum LibrarySort { alphaAsc, alphaDesc, updatedDesc, createdDesc }
final _libSortProvider = StateProvider<LibrarySort>((ref) => LibrarySort.updatedDesc);
final _libSelectingProvider = StateProvider<bool>((ref) => false);
final _libSelectedSetProvider = StateProvider<Set<String>>((ref) => <String>{});

class _LibrarySongEditor extends ConsumerStatefulWidget {
  const _LibrarySongEditor({required this.song, required this.isNew});
  final Song song;
  final bool isNew;

  @override
  ConsumerState<_LibrarySongEditor> createState() => _LibrarySongEditorState();
}

class _LibrarySongEditorState extends ConsumerState<_LibrarySongEditor> {
  late TextEditingController _title;
  late TextEditingController _key;
  late List<Block> _blocks;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.song.title);
    _key = TextEditingController(text: widget.song.originalKey ?? '');
    _blocks = widget.song.blocks.map((b) => Block(id: b.id, type: b.type, content: b.content)).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _key.dispose();
    super.dispose();
  }

  void _save() {
    final updated = Song(
      id: widget.song.id,
      title: _title.text.trim().isEmpty ? 'Sin título' : _title.text.trim(),
      blocks: _blocks,
      originalKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
      tags: widget.song.tags,
      author: widget.song.author,
      favorite: widget.song.favorite,
      createdAt: widget.song.createdAt,
      updatedAt: DateTime.now(),
    );
    ref.read(libraryProvider.notifier).upsert(updated);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(widget.isNew ? 'Nueva en biblioteca' : 'Editar biblioteca'),
            actions: [
              TextButton(
                onPressed: () {
                  _save();
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
          body: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(12, 12, 12, MediaQuery.of(context).viewInsets.bottom + 24),
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),            
              const SizedBox(height: 8),
              TextField(controller: _key, decoration: const InputDecoration(labelText: 'Tono (opcional)')),
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
                itemBuilder: (context, index) => _blockEditor(index),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _blocks.add(Block(id: HiveService.newId(), type: BlockType.text, content: 'INTRO'));
                    });
                  },
                  icon: const Icon(Icons.label),
                  label: const Text('Agregar etiqueta'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _blocks.add(Block(id: HiveService.newId(), type: BlockType.chords, content: ''));
                    });
                  },
                  icon: const Icon(Icons.music_note),
                  label: const Text('Agregar acordes'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _blocks.add(Block(id: HiveService.newId(), type: BlockType.note, content: ''));
                    });
                  },
                  icon: const Icon(Icons.note_alt),
                  label: const Text('Agregar nota'),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _blockEditor(int index) {
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
                      setState(() {
                        _blocks[index] = Block(id: b.id, type: t, content: b.content);
                      });
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _blocks.removeAt(index)),
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
            TextField(
              controller: TextEditingController(text: b.content),
              maxLines: b.type == BlockType.chords ? null : 3,
              decoration: InputDecoration(
                labelText: b.type == BlockType.chords ? 'Acordes' : (b.type == BlockType.text ? 'Etiqueta' : 'Nota'),
              ),
              onChanged: (v) => _blocks[index] = Block(id: b.id, type: b.type, content: v),
            ),
          ],
        ),
      ),
    );
  }
}
