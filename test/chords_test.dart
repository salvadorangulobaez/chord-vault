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

    test('Acordes entre paréntesis se detectan como acordes', () {
      final tokens = parseLineToTokens('E A Bm D (C#m)');
      expect(tokens.length, 5);
      expect(tokens.every((t) => t.isChord), true);
      expect(tokens.last.raw, '(C#m)');
    });

    test('Acorde entre paréntesis seguido de guión se detecta como un token', () {
      final tokens = parseLineToTokens('E A Bm (C)-A');
      expect(tokens.length, 4);
      expect(tokens[3].raw, '(C)-A');
      expect(tokens[3].isChord, true);
    });

    test('Acorde con paréntesis al final se detecta como un token', () {
      final tokens = parseLineToTokens('E A Bm A(C)');
      expect(tokens.length, 4);
      expect(tokens[3].raw, 'A(C)');
      expect(tokens[3].isChord, true);
    });
  });

  group('Transpose', () {
    test('Subir 2 semitonos mantiene sufijos y slash', () {
      final out = transposeToken('G#m7b5/A', 2, const TransposeOptions(preferSharps: true));
      expect(out, 'A#m7b5/B');
    });

    test('Transposición de tono menor en título', () {
      // Usa la API de transposeKey a través de display helper
      final out = transposeKey('Am', 2, preferSharps: true);
      expect(out, 'Bm');
      final out2 = transposeKey('F#m', -1, preferSharps: false);
      expect(out2, 'Fm');
    });

    test('Subacordes con guiones se transponen todos', () {
      final out = transposeToken('F#5b-F', 2, const TransposeOptions(preferSharps: true));
      expect(out, 'G#5b-G');
      final out2 = transposeToken('A-Bbm7b5-E/B', -1, const TransposeOptions(preferSharps: false));
      // A(-1)->Ab, Bbm7b5(-1)->Am7b5, E/B(-1)->Eb/Bb
      expect(out2, 'Ab-Am7b5-Eb/Bb');
    });

    test('Acordes entre paréntesis se transponen correctamente', () {
      final out = transposeToken('(C#m)', 2, const TransposeOptions(preferSharps: true));
      expect(out, '(D#m)');
      final out2 = transposeToken('(Fm7)', -1, const TransposeOptions(preferSharps: false));
      expect(out2, '(Em7)');
    });

    test('Acorde entre paréntesis seguido de guión se transponen ambos', () {
      final out = transposeToken('(C)-A', 2, const TransposeOptions(preferSharps: true));
      expect(out, '(D)-B');
    });

    test('Acorde con paréntesis al final se transponen ambos', () {
      final out = transposeToken('A(C)', 2, const TransposeOptions(preferSharps: true));
      expect(out, 'B(D)');
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


