import 'package:flutter/material.dart';
import 'controllers/app_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/permissions_screen.dart';

class OrionApp extends StatefulWidget {
  const OrionApp({super.key});

  @override
  State<OrionApp> createState() => _OrionAppState();
}

class _OrionAppState extends State<OrionApp> {
  late final AppController _controller;
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _bootstrapFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Orion Health Sync',
          theme: _buildTheme(),
          home: FutureBuilder<void>(
            future: _bootstrapFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _BootstrapScreen();
              }

              if (_controller.session == null) {
                return LoginScreen(controller: _controller);
              }

              if (!_controller.hasCompletedPermissionSetup) {
                return PermissionsScreen(controller: _controller);
              }

              return DashboardScreen(controller: _controller);
            },
          ),
        );
      },
    );
  }

  ThemeData _buildTheme() {
    const seedColor = Color(0xFF0B5D52);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
        primary: seedColor,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7F4),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F4),
        foregroundColor: Color(0xFF18211D),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Color(0xFF18211D),
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: Color(0xFF18211D),
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF18211D),
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF18211D),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: Color(0xFF33403A)),
        bodyMedium: TextStyle(color: Color(0xFF57645D)),
        labelLarge: TextStyle(
          color: Color(0xFF57645D),
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8E0D6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8E0D6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0B5D52), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF57645D)),
        hintStyle: const TextStyle(color: Color(0xFF57645D)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0B5D52),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0B5D52),
          side: const BorderSide(color: Color(0xFF0B5D52)),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
