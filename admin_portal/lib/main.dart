import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/users_screen.dart';
import 'screens/pricing_screen.dart';
import 'screens/reports_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase. Replace with actual keys later.
  // Using a dummy key for now just to scaffold.
  await Supabase.initialize(
    url: 'https://bgzogfldvbdaoajlxjhf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnem9nZmxkdmJkYW9hamx4amhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1MzQ4OTIsImV4cCI6MjA4NDExMDg5Mn0.Vthud-MOyDAL6NUuHHhGyDlVmCD5nG3B70Q4fQddtoI',
  );

  runApp(const AdminApp());
}

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isGoingToLogin = state.matchedLocation == '/login';

    if (session == null && !isGoingToLogin) {
      return '/login';
    }
    if (session != null && isGoingToLogin) {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => const UsersScreen(),
    ),
    GoRoute(
      path: '/pricing',
      builder: (context, state) => const PricingScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
  ],
);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InkSync Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
