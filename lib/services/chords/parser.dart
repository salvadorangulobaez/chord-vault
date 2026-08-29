// Parser y tokenizador de líneas de acordes.
//
// Reglas claves:
// - Separar tokens por espacios.
// - Detectar tokens de acorde usando regex estricta: raíz + accidental +
//   sufijos válidos + bajo slash opcional.
// - Cualquier token que no cumpla el patrón exacto se marca como texto.
// - Paréntesis exteriores se tratan como decoradores: (Am) -> acorde Am.
// - Tokens con '-' se tratan como sub-acordes: Am-G -> dos acordes unidos.

class LineToken {
  LineToken({required this.raw, required this.isChord});
  final String raw;
  final bool isChord;
}

/// Regex estricta para validar un acorde individual (sin paréntesis ni dash).
/// Matchea: C, Am, F#m7, Bbmaj7, Dsus4, E/G#, A7b5, C#dim, Gadd9, etc.
/// NO matchea: Amor, Dios, ESTROFA, CORO, Gloria, x2, etc.
/// Chord suffix regex: matches valid suffixes after the root note.
/// Strategy: allow known musical tokens (m, maj, dim, sus, add, numbers,
/// accidentals in combination) but reject random letters (like 'mor', 'ios').
final RegExp _chordRegex = RegExp(
  r'^[A-G](?:#|b|♯|♭)?'                   // Raíz: A-G + accidental
  r'(?:'                                    // Inicio grupo sufijo opcional
    r'm(?:aj|in)?|'                          // m, maj, min
    r'M|aug|dim|\+|°|ø'                    // Calidad
  r')?'
  r'(?:2|4|5|6|7|9|11|13)?'                // Extensión
  r'(?:sus[24]?)?'                          // Suspendidas
  r'(?:add(?:2|4|9|11|13))?'               // Add
  r'(?:'                                    // Alteraciones (0 o más)
    r'(?:#|b|♯|♭)(?:5|7|9|11|13)|'         // #5, b9, etc.
    r'(?:5|7|9|11|13)(?:#|b|♯|♭)'          // 5b, 7#, etc. (alternate order)
  r')*'
  r'(?:\/[A-G](?:#|b|♯|♭)?)?'             // Bajo slash (/G#)
  r'$',
);

bool _hasBalancedParens(String token) {
  var depth = 0;
  for (final rune in token.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth < 0) return false;
    }
  }
  return depth == 0;
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
      // Si cierra antes del final, no envuelve todo el token.
      if (depth == 0 && i < token.length - 1) return false;
    }
  }
  return depth == 0;
}

/// Verifica si un token individual (sin paréntesis ni dash) es un acorde.
bool _isSingleChord(String token) {
  if (token.isEmpty) return false;
  return _chordRegex.hasMatch(token);
}

/// Verifica si un token completo (puede incluir paréntesis y dash) es un acorde.
/// Depth guard evita recursión infinita con nesting profundo.
bool _looksLikeChordToken(String token, [int depth = 0]) {
  if (depth > 6) return false;
  final trimmed = token.trim();
  if (trimmed.isEmpty) return false;

  // Strip paréntesis exteriores: (Am) -> Am, ((Am)) -> (Am) -> Am
  String inner = trimmed;
  while (_isWrappedInBalancedParens(inner) && inner.length > 2) {
    inner = inner.substring(1, inner.length - 1).trim();
  }

  if (inner.isEmpty) return false;

  // Soporta acordes con grupos parentéticos internos, p.ej. A(C) o A(B C)
  if (inner.contains('(') || inner.contains(')')) {
    if (!_hasBalancedParens(inner)) return false;

    final groupPattern = RegExp(r'\(([^()]*)\)');
    final groups = groupPattern.allMatches(inner).toList();
    if (groups.isEmpty) return false;

    for (final group in groups) {
      final groupContent = group.group(1)!.trim();
      if (groupContent.isEmpty || !_looksLikeChordToken(groupContent, depth + 1)) {
        return false;
      }
    }

    final outside = inner.replaceAll(groupPattern, '').trim();
    if (outside.isEmpty) return true;
    return _looksLikeChordToken(outside, depth + 1);
  }

  // Si contiene espacios (usualmente ocurre porque venía envuelto en paréntesis)
  if (inner.contains(RegExp(r'\s'))) {
    final parts = inner.split(RegExp(r'\s+'));
    int chordParts = 0;
    for (final part in parts) {
      final p = part.trim();
      if (p.isEmpty) continue;
      if (_looksLikeChordToken(p, depth + 1)) {
        chordParts++;
      } else {
        return false;
      }
    }
    return chordParts > 0;
  }

  // Si contiene '-', verificar que cada parte sea un acorde o vacía
  // Ejemplos: Am-G, F#5b-F, (A/E-D) -> después de strip: A/E-D
  if (inner.contains('-')) {
    final parts = inner.split('-');
    int chordParts = 0;
    for (final part in parts) {
      final p = part.trim();
      if (p.isEmpty) continue;
      if (_looksLikeChordToken(p, depth + 1)) {
        chordParts++;
      } else {
        return false;
      }
    }
    return chordParts > 0;
  }



  // Verificar como acorde simple
  return _isSingleChord(inner);
}

List<LineToken> parseLineToTokens(String rawLine) {
  final line = rawLine.trimRight();
  final parts = <String>[];
  var start = 0;
  var depth = 0;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      if (depth > 0) depth--;
    } else if (depth == 0 && (ch == ' ' || ch == '\t')) {
      if (start < i) {
        parts.add(line.substring(start, i));
      }
      start = i + 1;
    }
  }
  if (start < line.length) {
    parts.add(line.substring(start));
  }
  
  return parts
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .map((p) => LineToken(raw: p, isChord: _looksLikeChordToken(p)))
      .toList();
}
