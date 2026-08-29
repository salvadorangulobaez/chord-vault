import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/app_providers.dart';
import '../models/note.dart';
import '../services/storage/hive_service.dart';
import '../services/io/text_format.dart';
import '../services/io/note_file.dart';
import '../utils/title_utils.dart';
import 'note_editor_screen.dart';
import 'library_screen.dart';
import 'help_screen.dart';

Future<void> _importNoteFromFile(BuildContext context, WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final file = File(path);
      final jsonStr = await file.readAsString();
      final importedNotes = NoteFile.importFromJson(jsonStr);
      
      for (final note in importedNotes) {
        ref.read(notesProvider.notifier).upsert(note);
      }
      
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importadas ${importedNotes.length} notas.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar archivo: $e')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir archivo: $e')),
      );
    }
  }
}


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
        title: const Text('Mis Notas'),
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
              tooltip: 'Ayuda',
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download),
              tooltip: 'Importar',
              onSelected: (val) async {
                if (val == 'file') {
                  await _importNoteFromFile(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'file', child: Text('Importar desde archivo (.cvnote)')),
              ],
            ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar notas y canciones...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => ref.read(_searchQueryProvider.notifier).state = '',
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          query.isNotEmpty ? 'No hay resultados' : 'No hay notas',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          query.isNotEmpty ? 'Prueba con otra búsqueda' : 'Toca el botón + para crear tu primera nota',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : viewAsGrid
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final note = sorted[index];
                  final titles = note.songs.map((s) => displayTitleWithKey(s.title, s.originalKey, 0)).toList();
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final note = sorted[index];
                final expanded = ref.watch(_expandedNotesProvider).contains(note.id);
                final songTitles = note.songs.map((s) => displayTitleWithKey(s.title, s.originalKey, 0)).toList();
                final selected = selectedSet.contains(note.id);
                return GestureDetector(
                  onLongPress: () {
                    final set = {...ref.read(_homeSelectedSetProvider)};
                    set.add(note.id);
                    ref.read(_homeSelectedSetProvider.notifier).state = set;
                    ref.read(_homeSelectingProvider.notifier).state = true;
                  },
                  child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      title: Text(note.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: expanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final t in songTitles)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• ' + t,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : null,
                      trailing: selecting
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: expanded ? 'Contraer' : 'Expandir',
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
                  ],
                ),
                ),
                );
              },
            ),
          ),
        ],
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
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      enabled: selectedSet.isNotEmpty,
                      icon: const Icon(Icons.share),
                      tooltip: 'Compartir / Exportar',
                      onSelected: (val) async {
                        final toExport = notes.where((n) => selectedSet.contains(n.id)).toList();
                        if (val == 'text') {
                          final text = TextFormat.exportNotes(toExport, forSharing: false);
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${toExport.length} nota(s) copiadas al portapapeles')),
                            );
                          }
                        } else if (val == 'share_text') {
                          final text = TextFormat.exportNotes(toExport, forSharing: true);
                          await Share.share(text);
                          ref.read(_homeSelectingProvider.notifier).state = false;
                          ref.read(_homeSelectedSetProvider.notifier).state = <String>{};
                        } else if (val == 'file') {
                          try {
                            final jsonStr = NoteFile.exportToJson(toExport);
                            final dir = await getTemporaryDirectory();
                            final file = File('${dir.path}/exportacion_notas.cvnote');
                            await file.writeAsString(jsonStr);
                            
                            if (context.mounted) {
                              final box = context.findRenderObject() as RenderBox?;
                              if (box != null) {
                                await Share.shareXFiles(
                                  [XFile(file.path)],
                                  text: 'Exportación de ChordVault (${toExport.length} notas)',
                                  sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
                                );
                              } else {
                                await Share.shareXFiles(
                                  [XFile(file.path)],
                                  text: 'Exportación de ChordVault (${toExport.length} notas)',
                                );
                              }
                              
                              ref.read(_homeSelectingProvider.notifier).state = false;
                              ref.read(_homeSelectedSetProvider.notifier).state = <String>{};
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al exportar: $e')),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'text', child: Text('Copiar como texto')),
                        PopupMenuItem(value: 'share_text', child: Text('Compartir como texto')),
                        PopupMenuItem(value: 'file', child: Text('Exportar como archivo (.cvnote)')),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: selecting
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final ctrl = TextEditingController();
                final title = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Nueva Nota'),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Título de la nota'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Crear')),
                    ],
                  ),
                );
                if (title != null && title.trim().isNotEmpty) {
                  final id = HiveService.newId();
                  final note = Note(
                    id: id,
                    title: title.trim(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  ref.read(notesProvider.notifier).upsert(note);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(noteId: id),
                      ),
                    );
                  }
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

final _viewModeProvider = StateProvider<bool>((ref) => true);
final _searchQueryProvider = StateProvider<String>((ref) => '');
final _expandedNotesProvider = StateProvider<Set<String>>((ref) => <String>{});
final _homeSelectingProvider = StateProvider<bool>((ref) => false);
final _homeSelectedSetProvider = StateProvider<Set<String>>((ref) => <String>{});


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
          case 'share':
            final text = TextFormat.exportNote(note, forSharing: true);
            await Share.share(text);
            break;
          case 'export_text':
            final text = TextFormat.exportNote(note, forSharing: false);
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota copiada como texto')));
            }
            break;
          case 'export_file':
            try {
              final jsonStr = NoteFile.exportToJson([note]);
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/nota_${note.title.replaceAll(' ', '_')}.cvnote');
              await file.writeAsString(jsonStr);
              if (context.mounted) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'Nota: ${note.title}',
                    sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
                  );
                } else {
                  await Share.shareXFiles([XFile(file.path)], text: 'Nota: ${note.title}');
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
              }
            }
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'share', child: Text('Compartir como texto')),
        PopupMenuItem(value: 'export_text', child: Text('Copiar como texto')),
        PopupMenuItem(value: 'export_file', child: Text('Exportar como archivo (.cvnote)')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'rename', child: Text('Renombrar')), 
        PopupMenuItem(value: 'duplicate', child: Text('Duplicar')), 
        PopupMenuItem(value: 'delete', child: Text('Eliminar')), 
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}


