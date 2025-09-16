# Cancionero

App Flutter para gestionar notas de canciones y acordes con transposición rápida.

## Requisitos
- Flutter instalado y en PATH de la sesión (PowerShell):
```
$env:Path += ";C:\Users\salvi\flutter\bin"
```

## Ejecutar
1. Instalar dependencias:
```
flutter pub get
```
2. Ejecutar tests:
```
flutter test
```
3. Correr la app en Android:
```
flutter run
```

## Estructura
- `lib/models/`: modelos `Note`, `Song`, `Block` con adapters Hive.
- `lib/services/chords/`: parser y transposición de acordes.
- `lib/services/storage/`: inicialización Hive.
- `lib/providers/`: estado con Riverpod.
- `lib/screens/`: `HomeScreen` y `NoteEditorScreen` (editor por bloques con transposición en vista).

## Flujo
- Desde Home creá una nota con el botón +.
- En la nota, cada canción es una tarjeta con controles de `-`, `+`, `Reset` y `Aplicar` (permanente).
- La transposición en vista no altera el texto original hasta presionar `Aplicar`.

## Próximos pasos sugeridos (prompts)
- "Añadí biblioteca de canciones con búsqueda e inserción a notas"
- "Agregá exportar/importar JSON y compartir .txt"
- "Mejorá el parser para distinguir tokens no musicales con guiones largos —"
- "Agregá controles de capo y preferencia de sostenidos/bemoles en Settings"
- "Hacé el editor de bloques con duplicar, reordenar y borrar"


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
