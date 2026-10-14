import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

class KasirApp extends StatelessWidget {
  const KasirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir Anna Seragam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // Localization wajib didaftarkan agar pemilih tanggal (showDateRangePicker)
      // tampil dalam bahasa Indonesia, bukan bahasa Inggris.
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Skala teks dikunci minimal 1.0: pengaturan sistem boleh memperbesar,
      // tapi tidak boleh memperkecil di bawah ukuran yang sudah diuji.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.35),
          ),
          child: child!,
        );
      },
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          if (auth.needsSetup) return const SetupScreen();
          return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
        },
      ),
    );
  }
}
