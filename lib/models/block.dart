import 'package:hive/hive.dart';

/// Tipo de bloque dentro de una canción
enum BlockType {
  text,
  chords,
  note,
}

/// Bloque de contenido: texto o acordes
class Block {
  Block({
    required this.id,
    required this.type,
    required this.content,
  });

  final String id;
  final BlockType type;
  String content;
}

/// Adapter manual de Hive para Block
class BlockAdapter extends TypeAdapter<Block> {
  @override
  final int typeId = 10;

  @override
  Block read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Block(
      id: fields[0] as String,
      type: BlockType.values[(fields[1] as int)],
      content: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Block obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.index)
      ..writeByte(2)
      ..write(obj.content);
  }
}


