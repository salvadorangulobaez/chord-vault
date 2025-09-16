import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/song.dart';
import '../../models/block.dart';
import '../storage/hive_service.dart';

Map<String, dynamic> _songToMap(Song song) {
  return {
    'type': 'cancionero_song',
    'version': 1,
    'song': {
      'title': song.title,
      'originalKey': song.originalKey,
      'tags': song.tags,
      'author': song.author,
      'isFavorite': song.isFavorite,
      'blocks': [
        for (final b in song.blocks)
          {
            'type': b.type.name,
            'content': b.content,
          }
      ],
    },
  };
}

Song? _songFromMap(Map<String, dynamic> map) {
  if (map['type'] != 'cancionero_song') return null;
  final s = map['song'] as Map<String, dynamic>?;
  if (s == null) return null;
  final List<dynamic> blocksRaw = (s['blocks'] as List<dynamic>? ?? []);
  return Song(
    id: HiveService.newId(),
    title: (s['title'] as String?) ?? 'Canción',
    originalKey: s['originalKey'] as String?,
    tags: (s['tags'] as List?)?.cast<String>() ?? const [],
    author: s['author'] as String?,
    isFavorite: (s['isFavorite'] as bool?) ?? false,
    blocks: [
      for (final br in blocksRaw)
        Block(
          id: HiveService.newId(),
          type: _blockTypeFromString(br['type'] as String? ?? 'text'),
          content: (br['content'] as String?) ?? '',
        )
    ],
  );
}

BlockType _blockTypeFromString(String v) {
  switch (v) {
    case 'chords':
      return BlockType.chords;
    case 'note':
      return BlockType.note;
    case 'text':
    default:
      return BlockType.text;
  }
}

String serializeSongToClipboardText(Song song) => jsonEncode(_songToMap(song));

Future<void> copySongToClipboard(Song song) async {
  final text = serializeSongToClipboardText(song);
  await Clipboard.setData(ClipboardData(text: text));
}

Future<Song?> pasteSongFromClipboard() async {
  final data = await Clipboard.getData('text/plain');
  final text = data?.text;
  if (text == null) return null;
  try {
    final map = jsonDecode(text) as Map<String, dynamic>;
    return _songFromMap(map);
  } catch (_) {
    return null;
  }
}


