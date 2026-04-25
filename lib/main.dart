import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage/hive_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/storage/seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await seedExampleData();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cancionero',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
