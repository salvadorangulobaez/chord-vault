// ignore_for_file: unawaited_futures
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/app_providers.dart';
import '../services/io/library_file.dart';
import '../services/io/share_export_service.dart';
import '../services/io/text_format.dart';
import 'song_preview_screen.dart';
import 'widgets/song_text_editor.dart';
import 'widgets/insert_to_note_dialog.dart';

Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['chordvault'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    bool dialogOpen = false;
    if (context.mounted) {
      dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final file = File(path);
      final jsonStr = await file.readAsString();
      final toImport = LibraryFile.importFromJson(jsonStr);
      
      final existing = ref.read(libraryProvider);
      final nonDuplicates = LibraryFile.filterDuplicates(toImport, existing);
      
      for (final song in nonDuplicates) {
        ref.read(libraryProvider.notifier).upsert(song);
      }
      
      if (context.mounted && dialogOpen) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        dialogOpen = false;
        final duplicates = toImport.length - nonDuplicates.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importadas ${nonDuplicates.length} canciones.' +
              (duplicates > 0 ? ' ($duplicates duplicadas omitidas)' : '')
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted && dialogOpen) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        dialogOpen = false;
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

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Timer? _debounce;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(_libSearchProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(_libSearchProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final search = ref.watch(_libSearchProvider);
    final sort = ref.watch(_libSortProvider);
    final selecting = ref.watch(_libSelectingProvider);
    final selectedSet = ref.watch(_libSelectedSetProvider);

    // Filtrar y ordenar (título, autor, tags, contenido bloques)
    final qLower = search.toLowerCase();
    var filtered = search.isEmpty
        ? library.toList()
        : library.where((s) {
            if (s.title.toLowerCase().contains(qLower)) return true;
            if ((s.author ?? '').toLowerCase().contains(qLower)) return true;
            if (s.tags.any((t) => t.toLowerCase().contains(qLower))) return true;
            if (s.blocks.any((b) => b.content.toLowerCase().contains(qLower))) return true;
            return false;
          }).toList();
    switch (sort) {
      case LibrarySort.alphaAsc:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.alphaDesc:
        filtered.sort((a, b) => b.title.compareTo(a.title));
      case LibrarySort.updatedDesc:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case LibrarySort.createdDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Scaffold(
      appBar: AppBar(
        title: selecting 
            ? Text('${selectedSet.length} seleccionada(s)')
            : const Text('Biblioteca'),
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
                    builder: (_) => SongTextEditor(
                      title: 'Nueva en biblioteca',
                      onSave: (song) {
                        ref.read(libraryProvider.notifier).upsert(song);
                      },
                    ),
                  ),
                  icon: const Icon(Icons.add),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.library_add),
                  tooltip: 'Añadir a biblioteca',
                  onSelected: (val) async {
                    if (val == 'text') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _ImportSongsSheet(),
                      );
                    } else if (val == 'file') {
                      await _importFromFile(context, ref);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'text', child: Text('Importar desde texto')),
                    PopupMenuItem(value: 'file', child: Text('Importar desde archivo (.chordvault)')),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          // Campo de búsqueda - siempre visible
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar canciones...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _debounce?.cancel();
                          ref.read(_libSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onSearchChanged,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          // Lista de canciones
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          search.isNotEmpty ? 'No hay resultados' : 'No hay canciones',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          search.isNotEmpty ? 'Prueba con otra búsqueda' : 'Añade o importa tu primera canción',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final s = filtered[index];
                final selected = selectedSet.contains(s.id);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                  onLongPress: selecting
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
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
                    title: Text(s.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    trailing: selecting
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (v) async {
                              switch (v) {
                                case 'edit':
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => SongTextEditor(
                                      initialSong: s,
                                      title: 'Editar en biblioteca',
                                      onSave: (updated) {
                                        ref.read(libraryProvider.notifier).upsert(updated);
                                      },
                                    ),
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
                                    final deleted = s;
                                    ref.read(libraryProvider.notifier).delete(s.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('"${deleted.title}" eliminada'),
                                          action: SnackBarAction(
                                            label: 'Deshacer',
                                            onPressed: () => ref.read(libraryProvider.notifier).upsert(deleted),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                            ],
                          ),
                  ),
                ),
                );
              },
            ),
          ),
        ],
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
                            await insertSongsToNote(context, ref, toInsert);
                            // Exit selection mode
                            ref.read(_libSelectingProvider.notifier).state = false;
                            ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                          },
                    icon: const Icon(Icons.add_to_queue),
                    tooltip: 'Insertar en nota',
                  ),
                  IconButton(
                    onPressed: selectedSet.isEmpty
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Confirmar eliminación'),
                                content: Text('¿Eliminar ${selectedSet.length} canción(es) seleccionada(s) de la biblioteca?'),
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
                              final deletedSongs = library.where((s) => selectedSet.contains(s.id)).toList();
                              for (final songId in selectedSet) {
                                ref.read(libraryProvider.notifier).delete(songId);
                              }
                              ref.read(_libSelectingProvider.notifier).state = false;
                              ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${deletedSongs.length} canción(es) eliminada(s)'),
                                    action: SnackBarAction(
                                      label: 'Deshacer',
                                      onPressed: () {
                                        for (final ds in deletedSongs) {
                                          ref.read(libraryProvider.notifier).upsert(ds);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.delete),
                    tooltip: 'Eliminar seleccionadas',
                  ),
                  PopupMenuButton<String>(
                    enabled: selectedSet.isNotEmpty,
                    icon: const Icon(Icons.share),
                    tooltip: 'Compartir / Exportar',
                    onSelected: (val) async {
                      final toExport = library.where((s) => selectedSet.contains(s.id)).toList();
                      try {
                        if (val == 'text') {
                          await ShareExportService.copySongsAsText(toExport);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${toExport.length} canción(es) copiadas al portapapeles')),
                            );
                          }
                        } else if (val == 'share_text') {
                          await ShareExportService.shareSongsAsText(toExport);
                          ref.read(_libSelectingProvider.notifier).state = false;
                          ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                        } else if (val == 'file') {
                          if (context.mounted) {
                            await ShareExportService.exportAndShareSongs(toExport, context);
                            ref.read(_libSelectingProvider.notifier).state = false;
                            ref.read(_libSelectedSetProvider.notifier).state = <String>{};
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al exportar: $e')),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'text', child: Text('Copiar como texto')),
                      PopupMenuItem(value: 'share_text', child: Text('Compartir como texto')),
                      PopupMenuItem(value: 'file', child: Text('Exportar como archivo (.chordvault)')),
                    ],
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

// _LibrarySongEditor removed — replaced by SongTextEditor widget

class _ImportSongsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ImportSongsSheet> createState() => _ImportSongsSheetState();
}

class _ImportSongsSheetState extends ConsumerState<_ImportSongsSheet> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // AppBar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Importar canciones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          hintText: 'Pega aquí el texto de las canciones...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final text = await Clipboard.getData(Clipboard.kTextPlain);
                              if (text?.text?.isNotEmpty == true) {
                                _textController.text = text!.text!;
                              }
                            },
                            icon: const Icon(Icons.content_paste),
                            label: const Text('Pegar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _textController.text.trim().isEmpty
                                ? null
                                : () async {
                                    try {
                                      final songs = TextFormat.parseSongs(_textController.text);
                                      final existingSongs = ref.read(libraryProvider);
                                      int added = 0;
                                      int skipped = 0;

                                      final nonDuplicates = LibraryFile.filterDuplicates(songs, existingSongs);
                                      skipped = songs.length - nonDuplicates.length;
                                      for (final s in nonDuplicates) {
                                        ref.read(libraryProvider.notifier).upsert(s);
                                      }
                                      added = nonDuplicates.length;

                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('$added canción(es) importada(s), $skipped omitida(s) (ya existían exactas)'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error al importar: $e')),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.upload),
                            label: const Text('Importar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
