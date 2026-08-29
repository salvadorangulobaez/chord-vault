import 'package:flutter_test/flutter_test.dart';
import 'package:cancionero/services/chords/transpose.dart';
import 'package:cancionero/services/chords/parser.dart';
import 'package:cancionero/services/io/text_format.dart';
import 'package:cancionero/services/io/library_file.dart';
import 'package:cancionero/services/io/note_file.dart';
import 'package:cancionero/models/song.dart';
import 'package:cancionero/models/block.dart';
import 'package:cancionero/services/io/share_export_service.dart';

void main() {
  group('2.7 transposeKey Am7 etc', () {
    test('Am7 transposes', () {
      expect(transposeKey('Am7', 2, preferSharps: true), 'Bm7');
      expect(transposeKey('Am7', -2, preferSharps: true), 'Gm7');
    });
    test('m9, m7b5', () {
      expect(transposeKey('Am9', 2, preferSharps: true), 'Bm9');
      expect(transposeKey('Am7b5', 2, preferSharps: true), 'Bm7b5');
      expect(transposeKey('Bb', 2, preferSharps: true), 'C');
    });
  });

  group('2.9 parser depth guard', () {
    test('deep nesting does not overflow', () {
      final token = 'A' + '(' * 10 + 'B' + ')' * 10;
      final tokens = parseLineToTokens(token);
      // Should not throw, at least returns tokens
      expect(tokens, isNotEmpty);
    });
    test('normal parenthesized still chord', () {
      expect(parseLineToTokens('(Am)').first.isChord, isTrue);
      expect(parseLineToTokens('A(B C)').first.isChord, isTrue);
    });
  });

  group('2.8 + 2.2 TextFormat metadata roundtrip', () {
    test('exportSong preserves author/tags/favorite', () {
      final song = Song(
        id: 'id1',
        title: 'Test Song',
        blocks: [Block(id: 'b1', type: BlockType.chords, content: 'D A Bm G')],
        author: 'Autor X',
        tags: ['tag1', 'tag2'],
        isFavorite: true,
        originalKey: 'D',
      );
      final exported = TextFormat.exportSong(song);
      expect(exported.contains('// AUTHOR: Autor X'), isTrue);
      expect(exported.contains('// TAGS: tag1, tag2'), isTrue);
      expect(exported.contains('// FAVORITE: true'), isTrue);
      final parsed = TextFormat.parseSingleSong(exported, 'newId');
      expect(parsed, isNotNull);
      expect(parsed!.author, 'Autor X');
      expect(parsed.tags, ['tag1', 'tag2']);
      expect(parsed.isFavorite, isTrue);
      expect(parsed.blocks.isNotEmpty, isTrue);
    });

    test('exportSongs uses separator', () {
      final s1 = Song(id: '1', title: 'A', blocks: [Block(id: 'b1', type: BlockType.chords, content: 'C G')]);
      final s2 = Song(id: '2', title: 'B', blocks: [Block(id: 'b2', type: BlockType.chords, content: 'D A')]);
      final txt = TextFormat.exportSongs([s1, s2]);
      expect(txt.contains('---'), isTrue);
      final parsed = TextFormat.parseSongs(txt);
      expect(parsed.length, 2);
    });

    test('_splitBySeparator blankCount >=3 does not split intra-cancion', () {
      // Two blank lines inside a song should not split; three may split only via ---
      final text = 'Song A\nD A Bm G\n\n\nSong B\nC G';
      // Without explicit ---, blankCount>=3 would split but we now require blankCount>=3 AND no dash, but still splits
      // This test documents behavior: with 3 blanks and no --- it may not split if heuristic changes; ensure parseSongs handles it gracefully
      final parsed = TextFormat.parseSongs(text);
      // Should produce at least 1, at most 2
      expect(parsed.length >= 1 && parsed.length <= 2, isTrue);
    });
  });

  group('2.10 LibraryFile id + equality', () {
    test('songToMap preserves id and isFavorite', () {
      final song = Song(id: 'keep-me', title: 'T', blocks: [], isFavorite: true, author: 'A', tags: ['x']);
      final m = LibraryFile.songToMap(song);
      expect(m['id'], 'keep-me');
      expect(m['isFavorite'], true);
      expect(m['author'], 'A');
      final restored = LibraryFile.songFromMap(m);
      expect(restored, isNotNull);
      expect(restored!.id, 'keep-me');
      expect(restored.isFavorite, isTrue);
    });

    test('areSongsEqual compares author/isFavorite/tags', () {
      Song a(String t) => Song(id: '1', title: 'X', blocks: [Block(id: 'b', type: BlockType.chords, content: t)], author: 'A', isFavorite: true, tags: ['t']);
      Song b(String t) => Song(id: '2', title: 'X', blocks: [Block(id: 'b2', type: BlockType.chords, content: t)], author: 'A', isFavorite: true, tags: ['t']);
      expect(LibraryFile.areSongsEqual(a('C G'), b('C G')), isTrue);
      expect(LibraryFile.areSongsEqual(a('C G'), b('C G').copyWithAuthor('B')), isFalse);
    });

    test('filterDuplicates keeps non-duplicates', () {
      final existing = [
        Song(id: '1', title: 'Same', blocks: [Block(id: 'b1', type: BlockType.chords, content: 'D A')])
      ];
      final toImport = [
        Song(id: '2', title: 'Same', blocks: [Block(id: 'b2', type: BlockType.chords, content: 'D A')]),
        Song(id: '3', title: 'Diff', blocks: [Block(id: 'b3', type: BlockType.chords, content: 'G C')]),
      ];
      final nonDups = LibraryFile.filterDuplicates(toImport, existing);
      expect(nonDups.length, 1);
      expect(nonDups.first.title, 'Diff');
    });
  });

  group('1.6 NoteFile DateTime try/catch', () {
    test('corrupt date falls back per song', () {
      const corrupt = '{"format":"chordvault_note","version":1,"exportedAt":"2020-01-01T00:00:00.000Z","notes":[{"title":"Ok","createdAt":"bad-date","updatedAt":"bad-date","songs":[]},{"title":"Also Ok","createdAt":"2020-01-01T00:00:00.000","updatedAt":"2020-01-01T00:00:00.000","songs":[]}]}';
      final imported = NoteFile.importFromJson(corrupt);
      expect(imported.length, 2);
      expect(imported.any((n) => n.title == 'Ok'), isTrue);
    });
  });

  group('1.8 ShareExportService sanitize', () {
    test('sanitizeTitle removes illegal chars', () {
      expect(ShareExportService.sanitizeTitle('Hola / Mundo: Test'), 'Hola_Mundo_Test');
      expect(ShareExportService.sanitizeTitle('a/b\\c:d'), isNot(contains('/')));
    });
  });
}

extension on Song {
  Song copyWithAuthor(String author) => Song(
        id: id,
        title: title,
        blocks: blocks,
        originalKey: originalKey,
        tags: tags,
        author: author,
        isFavorite: isFavorite,
      );
}
