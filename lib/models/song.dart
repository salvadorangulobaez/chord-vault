import 'package:hive/hive.dart';

import 'block.dart';

class Song {
  Song({
    required this.id,
    required this.title,
    required this.blocks,
    this.originalKey,
    this.tags = const [],
    this.author,
    this.isFavorite = false,
  });

  final String id;
  String title;
  final List<Block> blocks;
  final String? originalKey; // e.g., "D", "Bb"
  final List<String> tags;
  final String? author;
  bool isFavorite;
}

class SongAdapter extends TypeAdapter<Song> {
  @override
  final int typeId = 11;

  @override
  Song read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Song(
      id: fields[0] as String,
      title: fields[1] as String,
      blocks: (fields[2] as List).cast<Block>(),
      originalKey: fields[3] as String?,
      tags: (fields[4] as List?)?.cast<String>() ?? const [],
      author: fields[5] as String?,
      isFavorite: (fields[6] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.blocks)
      ..writeByte(3)
      ..write(obj.originalKey)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.author)
      ..writeByte(6)
      ..write(obj.isFavorite);
  }
}


