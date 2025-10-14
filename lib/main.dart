import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/document_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Delete existing database to force recreation with new schema
  final dbFactory = databaseFactoryFfi;
  final dbPath = await databaseFactoryFfi.getDatabasesPath();
  final path = join(dbPath, 'lockverse_v2_full.db');
  await dbFactory.deleteDatabase(path);

  // Initialize services
  final authService = AuthService();
  final docService = DocumentService();
  await docService.init();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: authService),
      ChangeNotifierProvider.value(value: docService),
    ],
    child: LockVerseApp(),
  ));
}

class LockVerseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockVerse',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/onboarding': (context) => OnboardingScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
