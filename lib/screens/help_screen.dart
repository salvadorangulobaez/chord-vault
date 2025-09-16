import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y formato')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionTitle('Conceptos'),
          _P('Notas contienen canciones. Cada canción tiene bloques: Etiqueta, Acordes, Nota.'),
          _P('Transposición con +/- no modifica el original hasta presionar "Aplicar".'),
          _P('Biblioteca permite guardar canciones reutilizables e insertarlas en notas.'),
          _SectionTitle('Importar/Exportar (texto)'),
          _P('Formato de canción (pegable):'),
          _Code('Glorioso Dia (D)\nINTRO\nD\n\nESTROFA\nD A Bm G\n\nCORO\nD A Bm G\n\nPUENTE\nBm A G Em'),
          _P('Reglas:'),
          _Bullet('Primera línea: Título (Tono) opcional.'),
          _Bullet('Bloque de etiqueta: línea en mayúsculas (INTRO, ESTROFA, CORO, PUENTE, INTERLUDIO).'),
          _Bullet('Líneas de acordes: tokens separados por espacios; admite barras (E/G#) y guiones internos.'),
          _Bullet('Notas/comentarios: líneas que empiecen con NOTE:, // o líneas entre paréntesis.'),
          _Bullet('Separador entre canciones: línea con --- o dos líneas en blanco.'),
          _SectionTitle('Biblioteca'),
          _Bullet('Importar: botón de "Importar" en la pantalla de Biblioteca (pegar texto).'),
          _Bullet('Exportar: activar "Exportar", seleccionar canciones y copiar al portapapeles.'),
          _SectionTitle('Notas'),
          _Bullet('Botón +: Importar texto, Insertar de biblioteca, Añadir canción.'),
          _Bullet('Editar: ícono de lápiz en cada canción. Reordenar canciones por arrastre.'),
          _Bullet('Título: se muestra como NOMBRE (TONO). El tono se transpone en vista y se fija al "Aplicar".'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _P extends StatelessWidget {
  const _P(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.code);
  final String code;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
    );
  }
}


