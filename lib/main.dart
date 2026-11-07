import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'models/app_models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_repository.dart';
import 'services/equipment_link_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const HatyaiwitBorrowSportsApp());
}

class HatyaiwitBorrowSportsApp extends StatefulWidget {
  const HatyaiwitBorrowSportsApp({super.key});

  @override
  State<HatyaiwitBorrowSportsApp> createState() =>
      _HatyaiwitBorrowSportsAppState();
}

class _HatyaiwitBorrowSportsAppState extends State<HatyaiwitBorrowSportsApp> {
  late Future<AppRepository> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initializeApp();
  }

  Future<AppRepository> _initializeApp() async {
    await initializeDateFormatting('th');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 20));
    return FirebaseAppRepository();
  }

  void _retry() {
    setState(() => _startup = _initializeApp());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hatyaiwit Borrow Sports',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateInitialRoutes: (initialRoute) => <Route<void>>[
        _buildRoute(initialRoute),
      ],
      onGenerateRoute: (settings) => _buildRoute(settings.name),
    );
  }

  Route<void> _buildRoute(String? routeName) {
    final equipmentId = EquipmentLinkService.equipmentIdFromRoute(routeName);
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName ?? '/'),
      builder: (context) => FutureBuilder<AppRepository>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StartupErrorScreen(onRetry: _retry);
          }

          final repository = snapshot.data;
          if (repository == null) return const _StartupLoadingScreen();

          return StreamBuilder<AppUser?>(
            stream: repository.watchUser(),
            builder: (context, userSnapshot) {
              final user = userSnapshot.data;
              if (user == null) {
                return AuthScreen(repository: repository, demoMode: false);
              }
              return HomeScreen(
                repository: repository,
                user: user,
                demoMode: false,
                initialEquipmentId: equipmentId,
              );
            },
          );
        },
      ),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/hatyaiwit_borrow_sports_logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'กำลังเปิด Hatyaiwit Borrow Sports…',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: AppTheme.blue,
                ),
                const SizedBox(height: 20),
                Text(
                  'เชื่อมต่อระบบไม่สำเร็จ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กรุณาตรวจสอบอินเทอร์เน็ต แล้วลองอีกครั้ง',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
