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

List<String> chromaticScale({required bool preferSharps}) =>
    List<String>.from(preferSharps ? _chromaticSharps : _chromaticFlats);

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

/// Transpone una nota raíz (sin sufijos) según semitonos y preferencia de notación.
String? transposeRootNote(String note, int semitones, {required bool preferSharps}) {
  final idx = _noteToIndex(note);
  if (idx == null) return null;
  return _indexToNote(idx + semitones, preferSharps: preferSharps);
}

final RegExp _minorKeyRegex = RegExp(r'^([A-G](?:#|b|♯|♭)?)(m)$');

/// Transpone un tono de canción que puede incluir modo menor (ej.: Am, F#m).
String transposeKey(String key, int semitones, {required bool preferSharps}) {
  final trimmed = key.trim();
  final mm = _minorKeyRegex.firstMatch(trimmed);
  String root = trimmed;
  String suffix = '';
  if (mm != null) {
    root = mm.group(1)!;
    suffix = mm.group(2)!; // conserva 'm'
  }
  final t = transposeRootNote(root, semitones, preferSharps: preferSharps);
  if (t == null) return key;
  return t + suffix;
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
  // Si el token es un acorde entre paréntesis, transponer el contenido y mantener los paréntesis
  if (token.startsWith('(') && token.endsWith(')')) {
    final innerToken = token.substring(1, token.length - 1);
    final transposedInner = transposeToken(innerToken, semitones, options);
    return '($transposedInner)';
  }
  
  // Si el token contiene paréntesis en el medio o al final (ej: A(C), (C)-A)
  if (token.contains('(') && token.contains(')')) {
    // Transponer cada parte del token que esté entre paréntesis
    String result = token;
    final regex = RegExp(r'\(([^)]+)\)');
    final matches = regex.allMatches(token);
    
    for (final match in matches) {
      final original = match.group(0)!; // (C)
      final inner = match.group(1)!; // C
      final transposedInner = transposeToken(inner, semitones, options);
      result = result.replaceFirst(original, '($transposedInner)');
    }
    
    // Transponer las partes que no están entre paréntesis
    final parts = result.split(RegExp(r'[()]'));
    for (int i = 0; i < parts.length; i += 2) { // Solo las partes pares (no entre paréntesis)
      if (parts[i].isNotEmpty) {
        parts[i] = _transposeSingleToken(parts[i], semitones, options);
      }
    }
    
    // Reconstruir el token
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      buffer.write(parts[i]);
      if (i < parts.length - 1) {
        buffer.write(i % 2 == 0 ? '(' : ')');
      }
    }
    return buffer.toString();
  }
  
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


