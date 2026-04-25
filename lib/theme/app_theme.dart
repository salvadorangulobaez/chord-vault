import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
        // Tonos ligeramente más azulados/sofisticados para las superficies
        surface: const Color(0xFF0F1115),
        surfaceContainerHighest: const Color(0xFF1A1D24), 
      ),
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );

    return base.copyWith(
      // Tipografía principal
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      
      // Estilo de las tarjetas (NoteCard, SongCard, etc.)
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1D24),
        elevation: 0, // Las sombras en M3 a veces ensucian, usaremos bordes
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      
      // Botones Flotantes (FAB)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F1115),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      
      // TextFields (SearchBar)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1D24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
