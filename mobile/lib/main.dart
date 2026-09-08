import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..bootstrap(),
      child: const GoldManagerApp(),
    ),
  );
}

class GoldManagerApp extends StatelessWidget {
  const GoldManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gold Manager',
      debugShowCheckedModeBanner: false,
      theme: buildGoldTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, AuthStatus>((s) => s.status);
    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body:
              Center(child: CircularProgressIndicator(color: GoldColors.gold)),
        );
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const DashboardScreen();
    }
  }
}
