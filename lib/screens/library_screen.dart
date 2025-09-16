import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/song.dart';
import '../models/block.dart';
import '../services/storage/hive_service.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(libraryProvider);
    final query = ref.watch(_libSearchProvider);
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? songs
        : songs.where((s) => s.title.toLowerCase().contains(q) || (s.tags.join(' ').toLowerCase().contains(q))).toList();
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
                      onPressed: () => ref.read(_libSearchProvider.notifier).state = '',
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (v) => ref.read(_libSearchProvider.notifier).state = v,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nueva canción',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final song = Song(
                id: HiveService.newId(),
                title: 'Nueva de biblioteca',
                blocks: [Block(id: HiveService.newId(), type: BlockType.chords, content: '')],
              );
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _LibrarySongEditor(song: song, isNew: true),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final s = filtered[index];
          return ListTile(
            title: Text(s.title),
            subtitle: Text(s.originalKey ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _LibrarySongEditor(song: s, isNew: false),
              );
            },
          );
        },
      ),
    );
  }
}

final _libSearchProvider = StateProvider<String>((ref) => '');

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
      isFavorite: widget.song.isFavorite,
    );
    ref.read(libraryProvider.notifier).upsert(updated);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Scaffold(
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
              padding: const EdgeInsets.all(12),
              children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),            
                const SizedBox(height: 8),
                TextField(controller: _key, decoration: const InputDecoration(labelText: 'Tono (opcional)')),
                const SizedBox(height: 8),
                for (int i = 0; i < _blocks.length; i++) _blockEditor(i),
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
          ),
        );
      },
    );
  }

  Widget _blockEditor(int index) {
    final b = _blocks[index];
    return Card(
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
