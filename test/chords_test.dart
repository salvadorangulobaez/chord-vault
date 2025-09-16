import 'package:flutter_test/flutter_test.dart';
import 'package:cancionero/services/chords/parser.dart';
import 'package:cancionero/services/chords/transpose.dart';

void main() {
  group('Parser', () {
    test('Tokenización simple separada por espacios', () {
      final tokens = parseLineToTokens('D A Bm G');
      expect(tokens.length, 4);
      expect(tokens.every((t) => t.isChord), true);
    });

    test('No dividir tokens con guión interno', () {
      final tokens = parseLineToTokens('F#5b-F');
      expect(tokens.length, 1);
      expect(tokens.first.raw, 'F#5b-F');
      expect(tokens.first.isChord, true);
    });

    test('Detecta slash bass', () {
      final tokens = parseLineToTokens('E/G# A');
      expect(tokens.first.isChord, true);
      expect(tokens.first.raw, 'E/G#');
    });

    test('Etiqueta en mayúsculas como texto', () {
      final tokens = parseLineToTokens('INTRO D A');
      expect(tokens.first.isChord, false);
    });
  });

  group('Transpose', () {
    test('Subir 2 semitonos mantiene sufijos y slash', () {
      final out = transposeToken('G#m7b5/A', 2, const TransposeOptions(preferSharps: true));
      expect(out, 'A#m7b5/B');
    });

    test('Preferencia de bemoles', () {
      final out = transposeToken('F#', 1, const TransposeOptions(preferSharps: false));
      expect(out, 'G');
      final out2 = transposeToken('G#', 1, const TransposeOptions(preferSharps: false));
      expect(out2, 'Ab');
    });

    test('Enharmónicos especiales Cb/B, B#/C, E#/F, Fb/E', () {
      expect(transposeToken('Cb', 1, const TransposeOptions(preferSharps: true)), 'C');
      expect(transposeToken('B#', 0, const TransposeOptions(preferSharps: true)), 'C');
      expect(transposeToken('E#', 0, const TransposeOptions(preferSharps: true)), 'F');
      expect(transposeToken('Fb', 0, const TransposeOptions(preferSharps: true)), 'E');
    });
  });
}


