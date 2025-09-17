import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../models/block.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../services/chords/transpose.dart';
import '../services/chords/parser.dart';
import '../services/storage/hive_service.dart';
import '../services/clipboard/song_clipboard.dart';
import 'note_editor_screen.dart';

class SongPreviewScreen extends ConsumerStatefulWidget {
  final String songId;

  const SongPreviewScreen({
    super.key,
    required this.songId,
  });

  @override
  ConsumerState<SongPreviewScreen> createState() => _SongPreviewScreenState();
}

class _SongPreviewScreenState extends ConsumerState<SongPreviewScreen> {
  int _transposeBy = 0;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final song = library.firstWhere(
      (s) => s.id == widget.songId,
      orElse: () => throw Exception('Song not found'),
    );

    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(song.title),
        actions: [
          // Controles de transposición
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _transposeBy--;
                  });
                },
                icon: const Icon(Icons.remove),
                tooltip: 'Bajar semitono',
              ),
              Text(
                _transposeBy == 0
                    ? 'Original'
                    : _transposeBy > 0
                        ? '+$_transposeBy'
                        : '$_transposeBy',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _transposeBy++;
                  });
                },
                icon: const Icon(Icons.add),
                tooltip: 'Subir semitono',
              ),
              if (_transposeBy != 0)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _transposeBy = 0;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Resetear',
                ),
            ],
          ),
          // Menú de acciones
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'copy':
                  await _copySong(song);
                  break;
                case 'insert':
                  await _insertToNote(song);
                  break;
                case 'edit':
                  await _editSong(song);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copiar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'insert',
                child: Row(
                  children: [
                    Icon(Icons.add_to_queue),
                    SizedBox(width: 8),
                    Text('Insertar en nota'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con tono transponible
            if (song.originalKey?.isNotEmpty == true) ...[
              Text(
                _getTransposedTitle(song, _transposeBy, settings.preferSharps),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Bloques de la canción
            ...song.blocks.map((block) => _buildBlock(block, _transposeBy, settings.preferSharps)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(Block block, int transposeBy, bool preferSharps) {
    switch (block.type) {
      case BlockType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      
      case BlockType.chords:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _transposeChordBlock(block.content, transposeBy, preferSharps),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        );
      
      case BlockType.note:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              block.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
    }
  }

  String _getTransposedTitle(Song song, int transposeBy, bool preferSharps) {
    if (song.originalKey?.isEmpty != false) return song.title;
    
    final transposedKey = transposeKey(song.originalKey!, transposeBy, preferSharps: preferSharps);
    return '${song.title} ($transposedKey)';
  }

  String _transposeChordBlock(String content, int transposeBy, bool preferSharps) {
    if (transposeBy == 0) return content;
    
    final lines = content.split('\n');
    final transposedLines = lines.map((line) {
      final tokens = parseLineToTokens(line);
      final transposedTokens = tokens.map((token) {
        if (token.isChord) {
          return transposeToken(token.raw, transposeBy, TransposeOptions(preferSharps: preferSharps));
        }
        return token.raw;
      }).toList();
      return transposedTokens.join(' ');
    }).toList();
    
    return transposedLines.join('\n');
  }

  Future<void> _copySong(Song song) async {
    try {
      await copySongToClipboard(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canción copiada al portapapeles')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al copiar: $e')),
        );
      }
    }
  }

  Future<void> _insertToNote(Song song) async {
    final notes = ref.read(notesProvider);
    
    final result = await showModalBottomSheet<Note?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                      'Insertar en nota',
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
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Nueva nota
                    ListTile(
                      leading: const Icon(Icons.add_circle, color: Colors.green),
                      title: const Text('Nueva nota'),
                      subtitle: const Text('Crear una nueva nota con esta canción'),
                      onTap: () => Navigator.pop(context, null),
                    ),
                    const Divider(),
                    // Notas existentes
                    ...notes.map((note) => ListTile(
                      leading: const Icon(Icons.note),
                      title: Text(note.title),
                      subtitle: Text('${note.songs.length} canción(es)'),
                      onTap: () => Navigator.pop(context, note),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null || result == null) {
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
            songs: [song],
          );
          ref.read(notesProvider.notifier).upsert(newNote);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Canción agregada a nueva nota "$newNoteTitle"')),
            );
            
            // Navegar a la nueva nota
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NoteEditorScreen(noteId: newNote.id),
              ),
            );
          }
        }
      } else {
        // Agregar a nota existente
        final updatedSongs = [...result.songs, song];
        final updatedNote = Note(
          id: result.id,
          title: result.title,
          createdAt: result.createdAt,
          updatedAt: DateTime.now(),
          songs: updatedSongs,
        );
        ref.read(notesProvider.notifier).upsert(updatedNote);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Canción agregada a "${result.title}"')),
          );
          
          // Navegar a la nota existente
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditorScreen(noteId: result.id),
            ),
          );
        }
      }
    }
  }

  Future<void> _editSong(Song song) async {
    // Navegar a la biblioteca en modo edición
    Navigator.pop(context); // Volver a biblioteca
    // TODO: Implementar edición directa desde biblioteca
    // Por ahora, mostrar mensaje
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usa el menú de 3 puntos en la biblioteca para editar')),
      );
    }
  }
}
