import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'core/shop_repository.dart';
import 'screens/shell.dart';
import 'widgets/hud.dart';

void main() {
  const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  final baseUrl = configuredBaseUrl.isNotEmpty
      ? configuredBaseUrl
      : kIsWeb
      ? 'http://127.0.0.1:5288'
      : 'http://10.0.2.2:5288';
  final api = ApiClient(baseUrl: baseUrl);
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<ShopRepository>(create: (_) => ShopRepository(api)),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(api),
        ),
      ],
      child: const GundamApp(),
    ),
  );
}

class GundamApp extends StatelessWidget {
  const GundamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FiveGuysGundam',
    debugShowCheckedModeBanner: false,
    theme: Hud.theme(),
    home: const ShopShell(),
  );
}
