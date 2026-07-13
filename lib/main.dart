import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'database/database_manager.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for web
  if (kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiWeb;
    print('🌐 Web mode initialized');
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('📱 Mobile mode initialized');
  }

  // Initialize database
  try {
    await DatabaseManager().database;
    print('✅ Database initialized successfully!');
  } catch (e) {
    print('❌ Database initialization error: $e');
    print('Stack trace: ${StackTrace.current}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS & Remittance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}