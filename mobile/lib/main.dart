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
      title: 'AVS',
      debugShowCheckedModeBanner: false,
      theme: buildGoldTheme(),
      home: const _Root(),
      // A thin bar at the top of every screen (and dialog) whenever the app
      // is waiting on the server — one place to show "API loading" globally.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          if (context.watch<AppState>().loading) const _GlobalLoader(),
        ],
      ),
    );
  }
}

class _GlobalLoader extends StatelessWidget {
  const _GlobalLoader();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          child: SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: GoldColors.hairline,
              valueColor: AlwaysStoppedAnimation(GoldColors.gold),
            ),
          ),
        ),
      ),
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
