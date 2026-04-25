import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';
import '../models/block.dart';
import '../providers/app_providers.dart';
import '../services/chords/transpose.dart';
import '../services/chords/parser.dart';
import '../services/clipboard/song_clipboard.dart';
import '../services/io/text_format.dart';
import 'widgets/song_text_editor.dart';
import 'widgets/insert_to_note_dialog.dart';

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
          // Menú de acciones
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'export_text':
                  final text = TextFormat.exportSong(song);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Canción copiada como texto')),
                  );
                  break;
                case 'share':
                  final text = TextFormat.exportSong(song);
                  await Share.share(text);
                  break;
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
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export_text',
                child: Row(
                  children: [
                    Icon(Icons.content_copy),
                    SizedBox(width: 8),
                    Text('Copiar como texto'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Compartir'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copiar (interno)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'insert',
                child: Row(
                  children: [
                    Icon(Icons.add_to_queue),
                    SizedBox(width: 8),
                    Text('Insertar en nota'),
                  ],
                ),
              ),
              PopupMenuItem(
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
      body: Column(
        children: [
          // Barra de controles (transposición + fuente) — fuera del AppBar para evitar overflow
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Transposición
                IconButton(
                  onPressed: () => setState(() => _transposeBy--),
                  icon: const Icon(Icons.remove, size: 20),
                  tooltip: 'Bajar semitono',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                  onPressed: () => setState(() => _transposeBy++),
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Subir semitono',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                if (_transposeBy != 0)
                  IconButton(
                    onPressed: () => setState(() => _transposeBy = 0),
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Resetear',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                const Spacer(),
                // Controles de fuente
                IconButton(
                  onPressed: settings.fontScale > 0.8
                      ? () {
                          ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(
                            fontScale: (settings.fontScale - 0.1).clamp(0.8, 2.0),
                          ));
                        }
                      : null,
                  icon: const Icon(Icons.text_decrease, size: 20),
                  tooltip: 'Reducir fuente',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                  icon: const Icon(Icons.text_increase, size: 20),
                  tooltip: 'Aumentar fuente',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          // Contenido de la canción
          Expanded(
            child: SingleChildScrollView(
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
                        fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) * settings.fontScale,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bloques de la canción
                  ...song.blocks.map((block) => _buildBlock(block, _transposeBy, settings.preferSharps)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(Block block, int transposeBy, bool preferSharps) {
    final settings = ref.watch(settingsProvider);
    final fontScale = settings.fontScale;

    switch (block.type) {
      case BlockType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) * fontScale,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _transposeChordBlock(block.content, transposeBy, preferSharps),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
                fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * fontScale,
              ),
            ),
          ),
        );

      case BlockType.note:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canción copiada al portapapeles')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al copiar: $e')),
      );
    }
  }

  Future<void> _insertToNote(Song song) async {
    await insertSongsToNote(context, ref, [song]);
  }

  Future<void> _editSong(Song song) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SongTextEditor(
        initialSong: song,
        title: 'Editar en biblioteca',
        onSave: (updated) {
          ref.read(libraryProvider.notifier).upsert(updated);
        },
      ),
    );
    if (mounted) setState(() {});
  }
}
