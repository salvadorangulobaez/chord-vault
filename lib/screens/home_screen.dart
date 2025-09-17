import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/note.dart';
import '../services/storage/hive_service.dart';
import '../services/chords/transpose.dart';
import 'note_editor_screen.dart';
import 'library_screen.dart';
import 'help_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final viewAsGrid = ref.watch(_viewModeProvider); // false=list, true=grid
    final query = ref.watch(_searchQueryProvider);
    final selecting = ref.watch(_homeSelectingProvider);
    final selectedSet = ref.watch(_homeSelectedSetProvider);
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? notes
        : notes.where((n) {
            if (n.title.toLowerCase().contains(q)) return true;
            for (final s in n.songs) {
              if (s.title.toLowerCase().contains(q)) return true;
            }
            return false;
          }).toList();
    final sorted = [...filtered]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar notas y canciones',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => ref.read(_searchQueryProvider.notifier).state = '',
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
          ),
        ),
        actions: [
          if (selecting)
            IconButton(
              tooltip: 'Salir selección',
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(_homeSelectingProvider.notifier).state = false;
                ref.read(_homeSelectedSetProvider.notifier).state = <String>{};
              },
            )
          else ...[
            IconButton(
              tooltip: 'Biblioteca',
              icon: const Icon(Icons.library_music),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()));
              },
            ),
            IconButton(
              tooltip: viewAsGrid ? 'Vista lista' : 'Vista mosaicos',
              icon: Icon(viewAsGrid ? Icons.view_list : Icons.grid_view),
              onPressed: () => ref.read(_viewModeProvider.notifier).state = !viewAsGrid,
            ),
          ],
        ],
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_add,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay notas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toca el botón + para crear tu primera nota',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : viewAsGrid
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final note = sorted[index];
                  final titles = note.songs.map((s) => _displayTitleWithKey(s.title, s.originalKey, 0)).toList();
                  final selected = selectedSet.contains(note.id);
                  return GestureDetector(
                    onLongPress: () {
                      final set = {...ref.read(_homeSelectedSetProvider)};
                      set.add(note.id);
                      ref.read(_homeSelectedSetProvider.notifier).state = set;
                      ref.read(_homeSelectingProvider.notifier).state = true;
                    },
                    onTap: selecting
                        ? () {
                            final set = {...ref.read(_homeSelectedSetProvider)};
                            if (selected) {
                              set.remove(note.id);
                            } else {
                              set.add(note.id);
                            }
                            ref.read(_homeSelectedSetProvider.notifier).state = set;
                          }
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NoteEditorScreen(noteId: note.id),
                              ),
                            );
                          },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (selecting)
                                  Checkbox(
                                    value: selected,
                                    onChanged: (v) {
                                      final set = {...ref.read(_homeSelectedSetProvider)};
                                      if (v == true) {
                                        set.add(note.id);
                                      } else {
                                        set.remove(note.id);
                                      }
                                      ref.read(_homeSelectedSetProvider.notifier).state = set;
                                    },
                                  ),
                                Expanded(
                                  child: Text(note.title, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                if (!selecting) _NoteMenu(note: note),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (final t in titles.take(3))
                              Text(
                                '• ' + t,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
              : ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final note = sorted[index];
                final expanded = ref.watch(_expandedNotesProvider).contains(note.id);
                final songTitles = note.songs.map((s) => _displayTitleWithKey(s.title, s.originalKey, 0)).toList();
                final selected = selectedSet.contains(note.id);
                return GestureDetector(
                  onLongPress: () {
                    final set = {...ref.read(_homeSelectedSetProvider)};
                    set.add(note.id);
                    ref.read(_homeSelectedSetProvider.notifier).state = set;
                    ref.read(_homeSelectingProvider.notifier).state = true;
                  },
                  child: Column(
                  children: [
                    ListTile(
                      leading: selecting
                          ? Checkbox(
                              value: selected,
                              onChanged: (v) {
                                final set = {...ref.read(_homeSelectedSetProvider)};
                                if (v == true) {
                                  set.add(note.id);
                                } else {
                                  set.remove(note.id);
                                }
                                ref.read(_homeSelectedSetProvider.notifier).state = set;
                              },
                            )
                          : null,
                      title: Text(note.title),
                      subtitle: expanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final t in songTitles)
                                  Text(
                                    '• ' + t,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            )
                          : null,
                      trailing: selecting
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: expanded ? 'Contraer' : 'Descontraer',
                                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    final set = {...ref.read(_expandedNotesProvider)};
                                    if (expanded) {
                                      set.remove(note.id);
                                    } else {
                                      set.add(note.id);
                                    }
                                    ref.read(_expandedNotesProvider.notifier).state = set;
                                  },
                                ),
                                _NoteMenu(note: note),
                              ],
                            ),
                      onTap: selecting
                          ? () {
                              final set = {...ref.read(_homeSelectedSetProvider)};
                              if (selected) {
                                set.remove(note.id);
                              } else {
                                set.add(note.id);
                              }
                              ref.read(_homeSelectedSetProvider.notifier).state = set;
                            }
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoteEditorScreen(noteId: note.id),
                                ),
                              );
                            },
                    ),
                    const Divider(height: 0),
                  ],
                ),
                );
              },
            ),
      bottomNavigationBar: selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: selectedSet.isEmpty
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Eliminar notas'),
                                  content: Text('¿Eliminar ${selectedSet.length} nota(s) seleccionada(s)?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                for (final id in selectedSet) {
                                  ref.read(notesProvider.notifier).delete(id);
                                }
                                ref.read(_homeSelectingProvider.notifier).state = false;
                                ref.read(_homeSelectedSetProvider.notifier).state = <String>{};
                              }
                            },
                      icon: const Icon(Icons.delete),
                      label: const Text('Eliminar seleccionadas'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: selecting
          ? null
          : Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 24,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'help-fab',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
                    },
                    child: const Icon(Icons.help_outline),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'add-fab',
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
                ),
              ],
            ),
    );
  }
}

final _viewModeProvider = StateProvider<bool>((ref) => true);
final _searchQueryProvider = StateProvider<String>((ref) => '');
final _expandedNotesProvider = StateProvider<Set<String>>((ref) => <String>{});
final _homeSelectingProvider = StateProvider<bool>((ref) => false);
final _homeSelectedSetProvider = StateProvider<Set<String>>((ref) => <String>{});

String _displayTitleWithKey(String title, String? originalKey, int semitones, {bool preferSharps = true}) {
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

class _NoteMenu extends ConsumerWidget {
  const _NoteMenu({required this.note});
  final Note note;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'rename':
            final ctrl = TextEditingController(text: note.title);
            final newName = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Renombrar nota'),
                content: TextField(controller: ctrl, autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Guardar')),
                ],
              ),
            );
            if (newName != null && newName.trim().isNotEmpty) {
              final updated = Note(
                id: note.id,
                title: newName.trim(),
                createdAt: note.createdAt,
                updatedAt: DateTime.now(),
                songs: note.songs,
              );
              ref.read(notesProvider.notifier).upsert(updated);
            }
            break;
          case 'duplicate':
            final copy = Note(
              id: HiveService.newId(),
              title: note.title + ' (copia)',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              songs: note.songs,
            );
            ref.read(notesProvider.notifier).upsert(copy);
            break;
          case 'delete':
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Eliminar nota'),
                content: Text('¿Eliminar "' + note.title + '"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                ],
              ),
            );
            if (confirm == true) {
              ref.read(notesProvider.notifier).delete(note.id);
            }
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'rename', child: Text('Renombrar')), 
        PopupMenuItem(value: 'duplicate', child: Text('Duplicar')), 
        PopupMenuItem(value: 'delete', child: Text('Eliminar')), 
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}


