// Transposición robusta de acordes.
// Soporta:
// - Notas con sostenidos/bemoles (incluyendo ♯/♭),
// - Sufijos y modificadores (m, maj7, sus4, add9, dim, aug, b5, #11 ...),
// - Bajo con slash E/G# conservando sufijos,
// - Preferencia de notación con sostenidos o bemoles,
// - Tokens complejos con '-' y paréntesis.

import 'parser.dart';

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

final RegExp _keySuffixRegex = RegExp(r'^([A-G](?:#|b|♯|♭)?)(m.*)?$');

/// Transpone un tono de canción que puede incluir modo menor (ej.: Am, Am7, F#m9, Bbm7b5).
String transposeKey(String key, int semitones, {required bool preferSharps}) {
  final trimmed = key.trim();
  final mm = _keySuffixRegex.firstMatch(trimmed);
  String root = trimmed;
  String suffix = '';
  if (mm != null) {
    root = mm.group(1)!;
    suffix = mm.group(2) ?? '';
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

ChordTokenParsed? parseChordToken(String token) {
  final m = _rootStart.firstMatch(token);
  if (m == null) return null;
  String head = token.substring(0, m.group(0)!.length);
  String rest = token.substring(m.group(0)!.length);
  String? bass;

  // Buscar slash para nota de bajo. Usar lastIndexOf para manejar
  // casos como Am7/G donde hay un solo slash.
  final slashIdx = rest.lastIndexOf('/');
  if (slashIdx >= 0) {
    final afterSlash = rest.substring(slashIdx + 1);
    final bassMatch = _rootStart.firstMatch(afterSlash);
    if (bassMatch != null) {
      bass = afterSlash.substring(0, bassMatch.group(0)!.length);
      final remaining = afterSlash.substring(bassMatch.group(0)!.length);
      rest = rest.substring(0, slashIdx);
      if (remaining.isNotEmpty) {
        rest += remaining;
      }
    }
  }
  return ChordTokenParsed(root: head, suffix: rest, bass: bass);
}

/// Transpone un token de acorde completo.
///
/// Maneja en orden limpio y sin ambigüedad:
/// 1. Paréntesis exteriores -> strip, recurse, re-envolver
/// 2. Dash '-' a nivel superior -> split, transponer cada parte, rejoin
/// 3. Grupos parentéticos internos (p.ej. A(C)) -> transponer fuera y dentro
/// 4. Acorde simple -> parsear root+suffix+bass, transponer
String transposeToken(String token, int semitones, TransposeOptions options) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return token;

  // Paso 1: Strip paréntesis exteriores
  if (_isWrappedInBalancedParens(trimmed)) {
    final inner = trimmed.substring(1, trimmed.length - 1);
    final transposedInner = inner.contains(RegExp(r'\s'))
        ? _transposeSpaceSeparated(inner, semitones, options)
        : transposeToken(inner, semitones, options);
    return '($transposedInner)';
  }

  // Paso 2: Si contiene '-', split a nivel superior y transponer cada parte
  final dashParts = _splitTopLevel(trimmed, '-');
  if (dashParts.length > 1) {
    final transposed = dashParts.map((p) {
      if (p.isEmpty) return p;
      return transposeToken(p, semitones, options);
    }).toList();
    return transposed.join('-');
  }

  // Paso 3: Paréntesis internos (p.ej. A(C), A(B-C), etc.)
  if (trimmed.contains('(') && trimmed.contains(')')) {
    return _transposeParentheticalSegments(trimmed, semitones, options);
  }

  // Paso 4: Transponer como acorde simple
  return _transposeSingleToken(trimmed, semitones, options);
}

bool _isWrappedInBalancedParens(String token) {
  if (token.length < 2) return false;
  if (!token.startsWith('(') || !token.endsWith(')')) return false;

  var depth = 0;
  for (var i = 0; i < token.length; i++) {
    final ch = token[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth < 0) return false;
      if (depth == 0 && i < token.length - 1) return false;
    }
  }
  return depth == 0;
}

List<String> _splitTopLevel(String token, String separator) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;

  for (var i = 0; i < token.length; i++) {
    final ch = token[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      if (depth > 0) depth--;
    } else if (depth == 0 && ch == separator) {
      parts.add(token.substring(start, i));
      start = i + 1;
    }
  }

  parts.add(token.substring(start));
  return parts;
}

String _transposeSpaceSeparated(String inner, int semitones, TransposeOptions options) {
  final tokens = parseLineToTokens(inner);
  return tokens.map((t) => transposeToken(t.raw, semitones, options)).join(' ');
}

String _transposeParentheticalSegments(String token, int semitones, TransposeOptions options) {
  final out = StringBuffer();
  var i = 0;

  while (i < token.length) {
    final open = token.indexOf('(', i);
    if (open == -1) {
      final tail = token.substring(i);
      out.write(_transposeSingleToken(tail, semitones, options));
      break;
    }

    final prefix = token.substring(i, open);
    if (prefix.isNotEmpty) {
      out.write(_transposeSingleToken(prefix, semitones, options));
    }

    var depth = 0;
    var close = -1;
    for (var j = open; j < token.length; j++) {
      final ch = token[j];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) {
          close = j;
          break;
        }
      }
    }

    if (close == -1) {
      // Paréntesis desbalanceados: fallback seguro.
      out.write(_transposeSingleToken(token.substring(open), semitones, options));
      break;
    }

    final inner = token.substring(open + 1, close);
    out.write('(');
    out.write(inner.contains(RegExp(r'\s'))
        ? _transposeSpaceSeparated(inner, semitones, options)
        : transposeToken(inner, semitones, options));
    out.write(')');

    i = close + 1;
  }

  return out.toString();
}

String _transposeSingleToken(String token, int semitones, TransposeOptions options) {
  final parsedByLine = parseLineToTokens(token);
  if (parsedByLine.length != 1 || !parsedByLine.first.isChord || parsedByLine.first.raw != token) {
    return token;
  }

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
