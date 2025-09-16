import '../../models/song.dart';
import '../../models/block.dart';

class TextFormat {
  // Exporta una canción a texto plano
  static String exportSong(Song song) {
    final buffer = StringBuffer();
    final title = song.originalKey == null || song.originalKey!.isEmpty
        ? song.title
        : song.title.split(RegExp(r"\s*\(.*\)\s*$")).first.trim() + ' (' + song.originalKey! + ')';
    buffer.writeln(title);
    for (final b in song.blocks) {
      if (b.type == BlockType.text) {
        buffer.writeln(b.content.toUpperCase());
      } else {
        buffer.writeln(b.content);
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }

  // Exporta una lista de canciones separadas por ---
  static String exportSongs(List<Song> songs) => songs.map(exportSong).join('\n\n---\n\n');

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
      if (_looksLikeChordLine(line)) {
        currentChords ??= StringBuffer();
        currentChords.writeln(line.trimRight());
      } else if (_isNoteLine(line)) {
        if (currentChords != null) {
          blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.chords, content: currentChords.toString().trimRight()));
          currentChords = null;
        }
        blocks.add(Block(id: newId + '-b' + blocks.length.toString(), type: BlockType.note, content: line.replaceFirst(RegExp(r'^(NOTE:|//)\s*'), '').trim()));
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
    return isUpper && RegExp(r'^(INTRO|ESTROFA|CORO|PUENTE|INTERLUDIO)(?:\b|\s|\().*').hasMatch(l);
  }

  static bool _looksLikeChordLine(String line) {
    final tokens = line.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return false;
    int chordish = 0;
    for (final t in tokens) {
      if (RegExp(r'^[A-G](?:#|b|♯|♭)?').hasMatch(t)) chordish++;
    }
    return chordish >= (tokens.length / 2);
  }

  static bool _isNoteLine(String line) {
    final l = line.trimLeft();
    return l.startsWith('NOTE:') || l.startsWith('//') || RegExp(r'^\(.*\)$').hasMatch(l);
  }
}


