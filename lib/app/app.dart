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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const LoginPage(),
      );
}
