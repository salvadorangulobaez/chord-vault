import '../services/chords/transpose.dart';

/// Única fuente de verdad para mostrar título con tono transpuesto.
///
/// Si el título ya contiene un tono entre paréntesis (ej. "Glorioso Día (D)"),
/// lo extrae y usa como fallback si [originalKey] es null.
String displayTitleWithKey(
  String title,
  String? originalKey,
  int semitones, {
  bool preferSharps = true,
}) {
  String baseTitle = title;
  String? key = originalKey;
  final match = RegExp(r"^(.*)\(([^)]+)\)\s*$").firstMatch(title);
  if (match != null) {
    baseTitle = match.group(1)!.trim();
    key ??= match.group(2)!.trim();
  }
  if (key == null || key.isEmpty) return baseTitle;
  final transposed = transposeKey(key, semitones, preferSharps: preferSharps);
  return baseTitle.isEmpty ? transposed : '$baseTitle ($transposed)';
}
