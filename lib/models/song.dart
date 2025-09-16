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
    DateTime? createdAt,
    DateTime? updatedAt,
  });

  final String id;
  String title;
  final List<Block> blocks;
  final String? originalKey; // e.g., "D", "Bb"
  final List<String> tags;
  final String? author;
  bool isFavorite;
  DateTime get createdAt => _createdAt ?? DateTime.now();
  DateTime? _createdAt;
  DateTime get updatedAt => _updatedAt ?? _createdAt ?? DateTime.now();
  DateTime? _updatedAt;
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
    final song = Song(
      id: fields[0] as String,
      title: fields[1] as String,
      blocks: (fields[2] as List).cast<Block>(),
      originalKey: fields[3] as String?,
      tags: (fields[4] as List?)?.cast<String>() ?? const [],
      author: fields[5] as String?,
      isFavorite: (fields[6] as bool?) ?? false,
    );
    if (fields.containsKey(7)) {
      song._createdAt = DateTime.fromMillisecondsSinceEpoch(fields[7] as int);
    }
    if (fields.containsKey(8)) {
      song._updatedAt = DateTime.fromMillisecondsSinceEpoch(fields[8] as int);
    }
    return song;
  }

  @override
  void write(BinaryWriter writer, Song obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.isFavorite)
      ..writeByte(7)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(8)
      ..write(DateTime.now().millisecondsSinceEpoch);
  }
}


