# ChordVault Refactoring — Task Tracker (Audited State)

## Fase 1: Parser Robusto ✅
- [x] Reescribir `parser.dart` con regex estricta
- [x] Reescribir `transposeToken` en `transpose.dart` con lógica limpia
- [x] Crear `test/parser_test.dart` con casos edge
- [x] Verificar: `flutter test test/parser_test.dart` — 37/37 passed ✅

## Fase 2: Editor Unificado de Texto ✅
- [x] Agregar `blocksToText` en `text_format.dart`
- [x] Agregar más section headers en `_isSectionHeader`
- [x] Crear `lib/screens/widgets/song_text_editor.dart`
- [x] Integrar en `note_editor_screen.dart` (reemplazar `_SongEditorSheet`)
- [x] Integrar en `library_screen.dart` (reemplazar `_LibrarySongEditor`)

## Fase 3: Comentarios con // ✅
- [x] Actualizar `text_format.dart` para exportar BlockType.note como `// contenido`
- [x] Actualizar render de BlockType.note en `note_editor_screen.dart` — itálica + icono + opacidad
- [x] Actualizar render de BlockType.note en `song_preview_screen.dart` — itálica + icono + opacidad
- [x] Actualizar `help_screen.dart` con documentación de `//` (ya tiene mención)

## Fase 4: Exportar Canción como Texto ✅
- [x] Agregar opciones "Copiar como texto" y "Compartir" en `_SongCard`
- [x] Agregar mismas opciones en `song_preview_screen.dart`
- [x] Implementar `_editSong` correctamente en SongPreviewScreen (usa SongTextEditor)

## Fase 5: Fixes Responsive y Bugs UI
- [x] Fix AppBar overflow en SongPreviewScreen — controles movidos a barra debajo
- [x] Fix lógica imposible en insertToNote — sentinel pattern implementado en library + song_preview
- [x] Fix TextEditingController en build — resuelto con SongTextEditor y Map persistente
- [x] Fix botón Importar deshabilitado — _ImportSongsSheet es StatefulWidget con controller
- [x] Fix FAB posicionamiento en HomeScreen — ayuda movida al AppBar
- [x] Eliminar `library_screen_backup.dart` — ya no existe

## Fase 6: Refactoring Código Duplicado
- [x] Crear `lib/utils/title_utils.dart`
- [x] Crear `lib/screens/widgets/insert_to_note_dialog.dart`
- [x] Actualizar home_screen, note_editor, library_screen, song_preview para usar utils

## Fase 7: Export/Import Biblioteca como Archivo
- [x] Agregar `file_picker` a `pubspec.yaml`
- [x] Crear `lib/services/io/library_file.dart`
- [x] Integrar exportar archivo en `library_screen.dart`
- [x] Integrar importar archivo en `library_screen.dart`
- [x] Loading indicator + resumen de deduplicación

## Post-auditoría (23-04-2026)
- [x] Corregidas regresiones de parser/transposición (`(C)-A`, `A(C)`, secuencias entre paréntesis)
- [x] Corregido `HiveService.init()` para tests sin plugin `path_provider`
- [x] Añadida vista previa en vivo en `SongTextEditor`
- [x] Verificación: `flutter test` — 55/55 passed ✅
