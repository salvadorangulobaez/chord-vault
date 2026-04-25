import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../models/block.dart';
import '../../services/io/text_format.dart';
import '../../services/storage/hive_service.dart';

/// Editor unificado de canciones.
///
/// Permite al usuario escribir/pegar una canción en formato texto natural
/// y la convierte automáticamente a bloques al guardar.
///
/// Formato de texto:
/// ```
/// INTRO
/// D
///
/// ESTROFA
/// D A Bm G
///
/// // comentario
///
/// CORO
/// D A Bm G
/// ```
class SongTextEditor extends StatefulWidget {
  const SongTextEditor({
    super.key,
    this.initialSong,
    required this.onSave,
    this.title = 'Editar canción',
  });

  /// Si es null, es una canción nueva. Si tiene valor, se carga para edición.
  final Song? initialSong;

  /// Callback al guardar. Recibe la canción con bloques parseados.
  final Function(Song song) onSave;

  /// Título del sheet
  final String title;

  @override
  State<SongTextEditor> createState() => _SongTextEditorState();
}

class _SongTextEditorState extends State<SongTextEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _textCtrl;
  bool _showAdvanced = false;

  // Para vista avanzada
  late List<Block> _blocks;
  final Map<String, TextEditingController> _blockControllers = {};

  @override
  void initState() {
    super.initState();
    final song = widget.initialSong;
    _titleCtrl = TextEditingController(text: song?.title ?? '');
    _keyCtrl = TextEditingController(text: song?.originalKey ?? '');

    if (song != null && song.blocks.isNotEmpty) {
      _textCtrl = TextEditingController(
        text: TextFormat.blocksToText(song.blocks),
      );
      _blocks = song.blocks
          .map((b) => Block(id: b.id, type: b.type, content: b.content))
          .toList();
    } else {
      _textCtrl = TextEditingController();
      _blocks = [];
    }

    _initBlockControllers();
  }

  void _initBlockControllers() {
    _blockControllers.clear();
    for (final b in _blocks) {
      _blockControllers[b.id] = TextEditingController(text: b.content);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _keyCtrl.dispose();
    _textCtrl.dispose();
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Song? _previewSongFromText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return null;

    final title = _titleCtrl.text.trim().isEmpty
        ? 'Vista previa'
        : _titleCtrl.text.trim();
    final key = _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim();

    final parsed = TextFormat.parseSingleSong(
      '$title${key != null ? ' ($key)' : ''}\n$text',
      'preview',
    );
    return parsed;
  }

  void _save() {
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Sin título'
        : _titleCtrl.text.trim();
    final key = _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim();

    List<Block> blocks;
    if (_showAdvanced) {
      // Usar bloques de la vista avanzada
      blocks = _blocks;
    } else {
      // Parsear desde texto
      final text = _textCtrl.text.trim();
      if (text.isEmpty) {
        blocks = [];
      } else {
        // Usar un título placeholder para parsear, luego extraemos solo los bloques
        final dummyId = widget.initialSong?.id ?? HiveService.newId();
        final parsed = TextFormat.parseSingleSong(
          '$title${key != null ? " ($key)" : ""}\n$text',
          dummyId,
        );
        blocks = parsed?.blocks ?? [];
      }
    }

    final song = Song(
      id: widget.initialSong?.id ?? HiveService.newId(),
      title: title,
      blocks: blocks,
      originalKey: key,
      tags: widget.initialSong?.tags ?? const [],
      author: widget.initialSong?.author,
      isFavorite: widget.initialSong?.isFavorite ?? false,
    );

    widget.onSave(song);
    Navigator.pop(context);
  }

  void _toggleAdvanced() {
    if (!_showAdvanced) {
      // Parsear texto a bloques para la vista avanzada
      final text = _textCtrl.text.trim();
      if (text.isNotEmpty) {
        final dummyId = widget.initialSong?.id ?? HiveService.newId();
        final title = _titleCtrl.text.trim().isEmpty ? 'temp' : _titleCtrl.text.trim();
        final key = _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim();
        final parsed = TextFormat.parseSingleSong(
          '$title${key != null ? " ($key)" : ""}\n$text',
          dummyId,
        );
        _blocks = parsed?.blocks ?? [];
      } else {
        _blocks = [];
      }
      // Dispose old controllers and create new ones
      for (final c in _blockControllers.values) {
        c.dispose();
      }
      _initBlockControllers();
    } else {
      // Convertir bloques de vuelta a texto
      _textCtrl.text = TextFormat.blocksToText(_blocks);
    }
    setState(() => _showAdvanced = !_showAdvanced);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Guardar'),
              ),
            ],
          ),
          body: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              // Título
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título de la canción',
                  hintText: 'Ej: Glorioso Día',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Tono
              TextField(
                controller: _keyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tono (opcional)',
                  hintText: 'Ej: D, Bb, F#m',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Toggle vista
              Row(
                children: [
                  Text(
                    _showAdvanced ? 'Vista avanzada (bloques)' : 'Editor de texto',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleAdvanced,
                    icon: Icon(_showAdvanced ? Icons.text_fields : Icons.view_agenda),
                    label: Text(_showAdvanced ? 'Vista texto' : 'Vista avanzada'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_showAdvanced)
                _buildAdvancedEditor()
              else
                _buildTextEditor(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Escribí o pegá la canción. Las etiquetas en MAYÚSCULAS '
            '(INTRO, ESTROFA, CORO...) se detectan automáticamente. '
            'Comentarios con // al inicio de la línea.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Área de texto principal
        TextField(
          controller: _textCtrl,
          maxLines: null,
          minLines: 12,
          decoration: InputDecoration(
            hintText: 'INTRO\nD\n\nESTROFA\nD A Bm G\n\nCORO\nD A Bm G',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          'Vista previa',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _buildLivePreview(),
      ],
    );
  }

  Widget _buildLivePreview() {
    final preview = _previewSongFromText();

    if (preview == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Escribí texto para ver la vista previa.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.originalKey == null || preview.originalKey!.isEmpty
                ? preview.title
                : '${preview.title} (${preview.originalKey})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (preview.blocks.isEmpty)
            Text(
              'No se detectaron bloques todavía.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final block in preview.blocks) ...[
              if (block.type == BlockType.text)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    block.content.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                )
              else if (block.type == BlockType.chords)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    block.content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          block.content,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
        ],
      ),
    );
  }

  Widget _buildAdvancedEditor() {
    return Column(
      children: [
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
            final ctrl = _blockControllers[b.id]!;
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
                            DropdownMenuItem(value: BlockType.note, child: Text('Comentario')),
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
                            _blockControllers[b.id]?.dispose();
                            _blockControllers.remove(b.id);
                            _blocks.removeAt(index);
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete, size: 20),
                        ),
                      ],
                    ),
                    TextField(
                      controller: ctrl,
                      maxLines: b.type == BlockType.chords ? null : 1,
                      decoration: InputDecoration(
                        hintText: b.type == BlockType.chords
                            ? 'D A Bm G'
                            : b.type == BlockType.text
                                ? 'ESTROFA'
                                : 'Comentario...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: b.type == BlockType.chords
                          ? const TextStyle(fontFamily: 'monospace', fontSize: 14)
                          : null,
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
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                final id = HiveService.newId();
                final block = Block(id: id, type: BlockType.text, content: '');
                _blocks.add(block);
                _blockControllers[id] = TextEditingController();
                setState(() {});
              },
              icon: const Icon(Icons.label, size: 18),
              label: const Text('Etiqueta'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final id = HiveService.newId();
                final block = Block(id: id, type: BlockType.chords, content: '');
                _blocks.add(block);
                _blockControllers[id] = TextEditingController();
                setState(() {});
              },
              icon: const Icon(Icons.music_note, size: 18),
              label: const Text('Acordes'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final id = HiveService.newId();
                final block = Block(id: id, type: BlockType.note, content: '');
                _blocks.add(block);
                _blockControllers[id] = TextEditingController();
                setState(() {});
              },
              icon: const Icon(Icons.comment, size: 18),
              label: const Text('Comentario'),
            ),
          ],
        ),
      ],
    );
  }
}
