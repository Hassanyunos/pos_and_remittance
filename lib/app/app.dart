import 'package:flutter/material.dart';

import '../core/ui/app_notice.dart';
import '../features/auth/presentation/pages/login_page.dart';

class PosAndRemittanceApp extends StatelessWidget {
  const PosAndRemittanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'POS & Remittance',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNotice.navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.4),
            ),
            labelStyle: const TextStyle(color: Color(0xFF334155)),
          ),
          useMaterial3: true,
        ),
        home: const LoginPage(),
      );
}
