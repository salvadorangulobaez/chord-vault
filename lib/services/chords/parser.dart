/// Parser y tokenizador de líneas de acordes.
/// Reglas claves:
/// - Separar tokens por espacios únicamente. No separar por '-'.
/// - Detectar tokens de acorde: comienzan con [A-G], opcional accidental (#, b, ♯, ♭),
///   pueden incluir sufijos (m, maj7, sus4, add9, dim, aug, b5, #11, etc.) y slash con bajo.
/// - Cualquier token que no cumpla el patrón se marca como texto.

class LineToken {
  LineToken({required this.raw, required this.isChord});
  final String raw;
  final bool isChord;
}

final RegExp _rootRegex = RegExp(r'^[A-G](?:#|b|♯|♭)?');
final RegExp _bassRegex = RegExp(r'/(?:[A-G](?:#|b|♯|♭)?)');

bool _looksLikeChordToken(String token) {
  if (token.isEmpty) return false;
  
  // Verificar si es un acorde entre paréntesis
  if (token.startsWith('(') && token.endsWith(')')) {
    final innerToken = token.substring(1, token.length - 1);
    return _looksLikeChordToken(innerToken);
  }
  
  // Debe iniciar con nota
  if (!_rootRegex.hasMatch(token)) return false;
  // Permitir sufijos comunes y otros caracteres dentro del token, incluido '-'
  // Si contiene espacios, no es un único token (ya lo habríamos splitteado).
  if (token.contains(' ')) return false;
  return true;
}

List<LineToken> parseLineToTokens(String line) {
  // split por cualquier cantidad de espacios, conservando tokens no vacíos
  final parts = line.trimRight().split(RegExp(r'\s+'));
  return parts
      .where((p) => p.isNotEmpty)
      .map((p) => LineToken(raw: p, isChord: _looksLikeChordToken(p)))
      .toList();
}


