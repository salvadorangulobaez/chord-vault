/// Transposición robusta de acordes.
/// Soporta:
/// - Notas con sostenidos/bemoles (incluyendo ♯/♭),
/// - Sufijos y modificadores (m, maj7, sus4, add9, dim, aug, b5, #11 ...),
/// - Bajo con slash E/G# conservando sufijos,
/// - Preferencia de notación con sostenidos o bemoles,
/// - Tokens complejos con '-' sin dividirlos.

class TransposeOptions {
  const TransposeOptions({this.preferSharps = true});
  final bool preferSharps;
}

const List<String> _chromaticSharps = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

const List<String> _chromaticFlats = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
];

// Normaliza ♯/♭ a #/b, y equivalentes enharmónicos Cb, B#, E#, Fb a índices
int? _noteToIndex(String raw) {
  String s = raw
      .replaceAll('♯', '#')
      .replaceAll('♭', 'b')
      .trim();
  switch (s) {
    case 'C':
      return 0;
    case 'B#':
      return 0;
    case 'C#':
    case 'Db':
      return 1;
    case 'D':
      return 2;
    case 'D#':
    case 'Eb':
      return 3;
    case 'E':
    case 'Fb':
      return 4;
    case 'F':
    case 'E#':
      return 5;
    case 'F#':
    case 'Gb':
      return 6;
    case 'G':
      return 7;
    case 'G#':
    case 'Ab':
      return 8;
    case 'A':
      return 9;
    case 'A#':
    case 'Bb':
      return 10;
    case 'B':
    case 'Cb':
      return 11;
  }
  return null;
}

String _indexToNote(int index, {required bool preferSharps}) {
  final i = (index % 12 + 12) % 12;
  return preferSharps ? _chromaticSharps[i] : _chromaticFlats[i];
}

class ChordTokenParsed {
  ChordTokenParsed({required this.root, required this.suffix, this.bass});
  final String root; // e.g. D, F#, Bb
  final String suffix; // e.g. m7b5, sus4, (omit3)
  final String? bass; // e.g. F#, A
}

final RegExp _rootStart = RegExp(r'^([A-G](?:#|b|♯|♭)?)');
final RegExp _slash = RegExp(r'/');

ChordTokenParsed? parseChordToken(String token) {
  final m = _rootStart.firstMatch(token);
  if (m == null) return null;
  String head = token.substring(0, m.group(0)!.length);
  String rest = token.substring(m.group(0)!.length);
  String? bass;
  if (_slash.hasMatch(rest)) {
    final parts = rest.split('/');
    rest = parts.first;
    final bassRaw = parts.sublist(1).join('/'); // por si hubiera múltiples '/'
    final bassMatch = _rootStart.firstMatch(bassRaw);
    if (bassMatch != null) {
      bass = bassRaw.substring(0, bassMatch.group(0)!.length);
      // mantener cualquier sufijo raro después del bajo como parte del sufijo total
      final remaining = bassRaw.substring(bassMatch.group(0)!.length);
      if (remaining.isNotEmpty) {
        rest += '/' + remaining;
      }
    } else {
      // slash sin nota válida => tratar todo como sufijo
      rest = '/' + bassRaw + rest;
    }
  }
  return ChordTokenParsed(root: head, suffix: rest, bass: bass);
}

String transposeToken(String token, int semitones, TransposeOptions options) {
  // Si el token contiene subacordes unidos con '-', transponer cada parte.
  if (token.contains('-')) {
    final parts = token.split('-');
    final transposed = parts.map((p) {
      final single = _transposeSingleToken(p, semitones, options);
      return single;
    }).toList();
    return transposed.join('-');
  }
  return _transposeSingleToken(token, semitones, options);
}

String _transposeSingleToken(String token, int semitones, TransposeOptions options) {
  final parsed = parseChordToken(token);
  if (parsed == null) return token;
  final rootIdx = _noteToIndex(parsed.root);
  if (rootIdx == null) return token;
  final newRoot = _indexToNote(rootIdx + semitones, preferSharps: options.preferSharps);
  String? newBass;
  if (parsed.bass != null) {
    final bassIdx = _noteToIndex(parsed.bass!);
    if (bassIdx != null) {
      newBass = _indexToNote(bassIdx + semitones, preferSharps: options.preferSharps);
    }
  }
  return newBass == null ? '$newRoot${parsed.suffix}' : '$newRoot${parsed.suffix}/$newBass';
}


