import 'package:hive/hive.dart';

import 'song.dart';

class Note {
  Note({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.songs = const [],
  });

  final String id;
  String title;
  DateTime createdAt;
  DateTime updatedAt;
  List<Song> songs;
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 12;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[2] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      songs: (fields[4] as List).cast<Song>(),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.updatedAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.songs);
  }
}


