import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/db_helper.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Buka database lebih awal supaya seed data selesai sebelum layar pertama.
  await DatabaseHelper.instance.database;

  final settings = SettingsProvider();
  await settings.load();

  final auth = AuthProvider();
  await auth.checkSetup();
  await auth.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const KasirApp(),
    ),
  );
}
