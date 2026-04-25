import '../../models/song.dart';
import '../../models/block.dart';
import '../chords/parser.dart';

class TextFormat {
  // Exporta una canción a texto plano
  static String exportSong(Song song) {
    final buffer = StringBuffer();
    final title = song.originalKey == null || song.originalKey!.isEmpty
        ? song.title
        : song.title.split(RegExp(r"\s*\(.*\)\s*$")).first.trim() + ' (' + song.originalKey! + ')';
    buffer.writeln(title);
    for (int i = 0; i < song.blocks.length; i++) {
      final b = song.blocks[i];
      if (b.type == BlockType.text) {
        buffer.writeln(b.content.toUpperCase());
      } else if (b.type == BlockType.note) {
        buffer.writeln('// ${b.content}');
      } else {
        buffer.writeln(b.content);
      }
    }
    return buffer.toString().trimRight();
  }

  // Exporta una lista de canciones separadas por ---
  static String exportSongs(List<Song> songs) => songs.map(exportSong).join('\n\n---\n\n');

  /// Convierte bloques de vuelta a texto editable (para el editor unificado).
  /// Es la operación inversa de _parseSingleSong.
  static String blocksToText(List<Block> blocks) {
    final buffer = StringBuffer();
    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      switch (b.type) {
        case BlockType.text:
          buffer.writeln(b.content.toUpperCase());
        case BlockType.chords:
          buffer.writeln(b.content);
        case BlockType.note:
          buffer.writeln('// ${b.content}');
      }
    }
    return buffer.toString().trimRight();
  }

  // Parseo de texto -> lista de canciones (una o varias)
  static List<Song> parseSongs(String text, {String Function()? idGen}) {
    final id = idGen ?? (() => DateTime.now().microsecondsSinceEpoch.toString());
    final parts = _splitBySeparator(text);
    return parts.map((chunk) => _parseSingleSong(chunk.trim(), id())).whereType<Song>().toList();
  }

  static List<String> _splitBySeparator(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final List<List<String>> chunks = [];
    List<String> current = [];
    int blankCount = 0;
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim() == '---' || blankCount >= 2) {
        if (current.isNotEmpty) chunks.add(current);
        current = [];
        blankCount = 0;
        if (line.trim() == '---') continue;
      }
      if (line.isEmpty) {
        blankCount++;
      } else {
        blankCount = 0;
      }
      current.add(line);
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks.map((c) => c.join('\n')).toList();
  }

  /// Parsea un bloque de texto de una sola canción a un objeto Song.
  /// Público para que el editor unificado pueda usarlo directamente.
  static Song? parseSingleSong(String chunk, String newId) {
    return _parseSingleSong(chunk, newId);
  }

  static Song? _parseSingleSong(String chunk, String newId) {
    if (chunk.trim().isEmpty) return null;
    final lines = chunk.split('\n');
    if (lines.isEmpty) return null;
    final titleLine = lines.first.trim();
    final t = _parseTitle(titleLine);
    String title = t.$1;
    String? key = t.$2;

    final List<Block> blocks = [];
    StringBuffer? currentChords;
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        if (currentChords != null) {
          blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.chords, content: currentChords.toString().trimRight()));
          currentChords = null;
        }
        continue;
      }
      if (_isSectionHeader(line)) {
        if (currentChords != null) {
          blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.chords, content: currentChords.toString().trimRight()));
          currentChords = null;
        }
        blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.text, content: line.trim().toUpperCase()));
        continue;
      }
      if (_isNoteLine(line)) {
        if (currentChords != null) {
          blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.chords, content: currentChords.toString().trimRight()));
          currentChords = null;
        }
        blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.note, content: line.replaceFirst(RegExp(r'^(NOTE:|//)\s*'), '').trim()));
        continue;
      }
      if (_looksLikeChordLine(line)) {
        currentChords ??= StringBuffer();
        currentChords.writeln(line.trimRight());
      } else {
        if (currentChords != null) {
          blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.chords, content: currentChords.toString().trimRight()));
          currentChords = null;
        }
        blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.text, content: line.trim()));
      }
    }
    if (currentChords != null) {
      blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.chords, content: currentChords.toString().trimRight()));
    }

    return Song(id: newId, title: title, blocks: blocks, originalKey: key);
  }

  // Returns (title, key?)
  static (String, String?) _parseTitle(String line) {
    final m = RegExp(r'^(.+?)\s*\(([^)]+)\)\s*$').firstMatch(line);
    if (m != null) {
      return (m.group(1)!.trim(), m.group(2)!.trim());
    }
    return (line.trim(), null);
  }

  static bool _isSectionHeader(String line) {
    final l = line.trim();
    if (l.isEmpty) return false;
    final isUpper = l == l.toUpperCase();
    return isUpper && RegExp(
      r'^(INTRO|ESTROFA|CORO|PUENTE|INTERLUDIO|PRE-CORO|PRECORO|OUTRO|FINAL|VERSO|BRIDGE|CHORUS|PRE-CHORUS|INTERLUDE|SOLO|INSTRUMENTAL|ENDING|TAG|VAMP)(?:\b|\s|\(|$).*'
    ).hasMatch(l);
  }

  /// Usa el parser robusto para determinar si una línea es de acordes.
  static bool _looksLikeChordLine(String line) {
    final tokens = parseLineToTokens(line.trim());
    if (tokens.isEmpty) return false;
    int chordCount = 0;
    for (final t in tokens) {
      if (t.isChord) chordCount++;
    }
    return chordCount >= (tokens.length / 2);
  }

  static bool _isNoteLine(String line) {
    final l = line.trimLeft();
    return l.startsWith('NOTE:') || l.startsWith('//');
  }
}
