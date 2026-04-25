import 'package:test/test.dart';
import 'package:cancionero/services/chords/parser.dart';
import 'package:cancionero/services/chords/transpose.dart';

void main() {
  group('Parser - _looksLikeChordToken via parseLineToTokens', () {
    bool isChord(String token) {
      final tokens = parseLineToTokens(token);
      return tokens.isNotEmpty && tokens.first.isChord;
    }

    // ===== VALID CHORDS =====
    test('basic notes', () {
      for (final n in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
        expect(isChord(n), isTrue, reason: '$n should be a chord');
      }
    });

    test('minor chords', () {
      expect(isChord('Am'), isTrue);
      expect(isChord('F#m'), isTrue);
      expect(isChord('Bbm'), isTrue);
    });

    test('seventh chords', () {
      expect(isChord('A7'), isTrue);
      expect(isChord('Am7'), isTrue);
      expect(isChord('Cmaj7'), isTrue);
      expect(isChord('Bbmaj7'), isTrue);
    });

    test('sus chords', () {
      expect(isChord('Dsus4'), isTrue);
      expect(isChord('Asus2'), isTrue);
      expect(isChord('Gsus'), isTrue);
    });

    test('add chords', () {
      expect(isChord('Cadd9'), isTrue);
      expect(isChord('Gadd2'), isTrue);
    });

    test('diminished and augmented', () {
      expect(isChord('Bdim'), isTrue);
      expect(isChord('Caug'), isTrue);
      expect(isChord('F#dim'), isTrue);
    });

    test('altered extensions', () {
      expect(isChord('A7b5'), isTrue);
      expect(isChord('C#5b'), isTrue);
    });

    test('slash chords', () {
      expect(isChord('E/G#'), isTrue);
      expect(isChord('Am/C'), isTrue);
      expect(isChord('D/F#'), isTrue);
    });

    test('chords with accidentals', () {
      expect(isChord('C#'), isTrue);
      expect(isChord('Db'), isTrue);
      expect(isChord('F#'), isTrue);
      expect(isChord('Gb'), isTrue);
      expect(isChord('Bb'), isTrue);
    });

    test('parenthesized chords', () {
      expect(isChord('(Am)'), isTrue);
      expect(isChord('(E/G#)'), isTrue);
    });

    test('dash-separated chords', () {
      expect(isChord('Am-G'), isTrue);
      expect(isChord('F#5b-F'), isTrue);
    });

    test('parenthesized dash chords', () {
      expect(isChord('(A/E-D)'), isTrue);
    });

    // ===== NOT CHORDS =====
    test('words starting with A-G are NOT chords', () {
      expect(isChord('Amor'), isFalse);
      expect(isChord('Dios'), isFalse);
      expect(isChord('Gloria'), isFalse);
      expect(isChord('Cristo'), isFalse);
      expect(isChord('Fiel'), isFalse);
      expect(isChord('Grande'), isFalse);
      expect(isChord('Bueno'), isFalse);
    });

    test('section headers are NOT chords', () {
      expect(isChord('ESTROFA'), isFalse);
      expect(isChord('CORO'), isFalse);
      expect(isChord('INTRO'), isFalse);
      expect(isChord('PUENTE'), isFalse);
    });

    test('numbers and symbols are NOT chords', () {
      expect(isChord('x2'), isFalse);
      expect(isChord('x4'), isFalse);
      expect(isChord('123'), isFalse);
    });

    test('empty string is NOT a chord', () {
      expect(isChord(''), isFalse);
    });
  });

  group('Transposition', () {
    const sharps = TransposeOptions(preferSharps: true);
    const flats = TransposeOptions(preferSharps: false);

    test('basic transposition +2 semitones', () {
      expect(transposeToken('A', 2, sharps), 'B');
      expect(transposeToken('C', 2, sharps), 'D');
      expect(transposeToken('D', 2, sharps), 'E');
      expect(transposeToken('G', 2, sharps), 'A');
    });

    test('transposition with sharps preference', () {
      expect(transposeToken('A', 1, sharps), 'A#');
      expect(transposeToken('C', 1, sharps), 'C#');
    });

    test('transposition with flats preference', () {
      expect(transposeToken('A', 1, flats), 'Bb');
      expect(transposeToken('C', 1, flats), 'Db');
    });

    test('minor chord transposition', () {
      expect(transposeToken('Am', 2, sharps), 'Bm');
      expect(transposeToken('F#m', 2, sharps), 'G#m');
    });

    test('seventh chord transposition', () {
      expect(transposeToken('Am7', 2, sharps), 'Bm7');
      expect(transposeToken('Cmaj7', 2, sharps), 'Dmaj7');
      expect(transposeToken('Bbmaj7', 2, sharps), 'Cmaj7');
    });

    test('sus chord transposition', () {
      expect(transposeToken('Dsus4', 2, sharps), 'Esus4');
      expect(transposeToken('Asus2', 2, sharps), 'Bsus2');
    });

    test('slash chord transposition', () {
      expect(transposeToken('E/G#', 2, sharps), 'F#/A#');
      expect(transposeToken('Am/C', 2, sharps), 'Bm/D');
      expect(transposeToken('D/F#', 2, sharps), 'E/G#');
    });

    test('dash-separated chord transposition', () {
      expect(transposeToken('Am-G', 2, sharps), 'Bm-A');
      expect(transposeToken('F#5b-F', 2, sharps), 'G#5b-G');
    });

    test('parenthesized chord transposition', () {
      expect(transposeToken('(Am)', 2, sharps), '(Bm)');
      expect(transposeToken('(E/G#)', 2, sharps), '(F#/A#)');
    });

    test('BUG FIX: (A/E-D) transposition', () {
      // This was the reported bug
      expect(transposeToken('(A/E-D)', 2, sharps), '(B/F#-E)');
      expect(transposeToken('(A/E-D)', -2, sharps), '(G/D-C)');
      expect(transposeToken('(A/E-D)', 1, flats), '(Bb/F-Eb)');
    });

    test('transposition of non-chord returns original', () {
      expect(transposeToken('Amor', 2, sharps), 'Amor');
      expect(transposeToken('x2', 2, sharps), 'x2');
    });

    test('zero transposition returns same', () {
      expect(transposeToken('Am7', 0, sharps), 'Am7');
      expect(transposeToken('E/G#', 0, sharps), 'E/G#');
    });

    test('full octave transposition returns same note', () {
      expect(transposeToken('Am', 12, sharps), 'Am');
      expect(transposeToken('E/G#', 12, sharps), 'E/G#');
    });

    test('negative transposition', () {
      expect(transposeToken('D', -2, sharps), 'C');
      expect(transposeToken('Am', -3, sharps), 'F#m');
    });
  });

  group('transposeKey', () {
    test('major keys', () {
      expect(transposeKey('D', 2, preferSharps: true), 'E');
      expect(transposeKey('G', -2, preferSharps: true), 'F');
    });

    test('minor keys', () {
      expect(transposeKey('Am', 2, preferSharps: true), 'Bm');
      expect(transposeKey('F#m', 3, preferSharps: true), 'Am');
    });
  });

  group('parseLineToTokens', () {
    test('chord line parsed correctly', () {
      final tokens = parseLineToTokens('D A Bm G');
      expect(tokens.length, 4);
      expect(tokens.every((t) => t.isChord), isTrue);
    });

    test('text line parsed as non-chords', () {
      final tokens = parseLineToTokens('ESTROFA');
      expect(tokens.length, 1);
      expect(tokens.first.isChord, isFalse);
    });

    test('mixed line preserves whitespace split', () {
      final tokens = parseLineToTokens('E/G# A B');
      expect(tokens.length, 3);
      expect(tokens[0].isChord, isTrue);
      expect(tokens[0].raw, 'E/G#');
    });

    test('handles multiple spaces', () {
      final tokens = parseLineToTokens('D   A   Bm   G');
      expect(tokens.length, 4);
      expect(tokens.every((t) => t.isChord), isTrue);
    });

    test('complex line with parenthesized dash chord', () {
      final tokens = parseLineToTokens('(A/E-D) Bbmaj7');
      expect(tokens.length, 2);
      expect(tokens[0].isChord, isTrue);
      expect(tokens[0].raw, '(A/E-D)');
      expect(tokens[1].isChord, isTrue);
      expect(tokens[1].raw, 'Bbmaj7');
    });
  });
}
