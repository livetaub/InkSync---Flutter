import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:helploop_sdk/helploop_sdk.dart';
import 'config/theme.dart';
import 'config/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'services/auth_service.dart'; // Legacy wrapper around Supabase
import 'services/supabase_auth_service.dart';
import 'services/supabase_notes_service.dart';
import 'services/notes_service.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/shared/shared_note_screen.dart';
import 'screens/note_edit/note_edit_screen.dart';
import 'screens/snapshot/snapshot_viewer_screen.dart';
import 'screens/auth/note_unlock_verification_screen.dart';
import 'screens/checkout/checkout_entry.dart';

import 'providers/selection_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();


  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Initialize HelpLoop SDK
  await HelpLoop.initialize(
    projectId: '9773e382-5e44-4c64-b64e-4da37f93164d',
    apiKey: 'pk_live_ae92a406477da2342015cb8c941821a8e9afe7c751c6e615cd3db16c4bdf2413',
    apiUrl: 'https://bwnrvdgonsqffiflcbem.supabase.co/functions/v1/helploop',
    appVersion: '1.0.0',
  );

  // Sync authentication state with HelpLoop
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final user = data.session?.user;
    if (user != null) {
      await HelpLoop.identify(
        externalId: user.email ?? user.id,
        identifierType: IdentifierType.email,
        email: user.email,
        name: user.userMetadata?['name']?.toString() ?? user.email?.split('@').first,
        metadata: {
          'plan': user.userMetadata?['plan']?.toString() ?? 'free',
        },
      );
    } else {
      await HelpLoop.logout();
    }
  });

  // Mobile-only: Initialize local database, notifications, and subscriptions
  if (!kIsWeb) {
    await NotificationService.instance.init();
    NotificationService.onNotificationTapped = (noteId) async {
      try {
        final authService = AuthService();
        final notesService = NotesService(authService);
        final note = await notesService.getNote(noteId);
        if (note != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(note: note),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error handling notification tap: $e');
      }
    };
    // RevenueCat will be fully initialized after auth is resolved
    // (see _triggerMobileSync in _MainNavigationState)
  }

  runApp(const InkSyncApp());
}

class InkSyncApp extends StatelessWidget {
  const InkSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Legacy AuthService for backward compatibility with existing screens
        Provider<AuthService>(create: (_) => AuthService()),
        // New Supabase services
        Provider<SupabaseAuthService>(create: (_) => SupabaseAuthService()),
        Provider<SupabaseNotesService>(create: (_) => SupabaseNotesService()),
        Provider<GeminiService>(create: (_) => GeminiService()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<SelectionProvider>(
          create: (_) => SelectionProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'InkSync',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            // Mobile app always starts at AuthWrapper (/app) which handles
            // WelcomeScreen / guest mode. Web starts at / (LoginScreen).
            initialRoute: kIsWeb ? '/' : '/app',
            builder: (context, child) {
              return child ?? const SizedBox.shrink();
            },
            onGenerateRoute: _generateRoute,
            onGenerateInitialRoutes: (initialRoute) {
              return [_generateRoute(RouteSettings(name: initialRoute))];
            },
          );
        },
      ),
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    // Handle shared note URLs: /shared/:token
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'shared') {
      final token = uri.pathSegments[1];
      return MaterialPageRoute(
        builder: (_) => SharedNoteScreen(shareToken: token),
      );
    }

    // Handle snapshot URLs: /snapshot/:token (public, no auth)
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'snapshot') {
      final token = uri.pathSegments[1];
      return MaterialPageRoute(
        builder: (_) => SnapshotViewerScreen(token: token),
      );
    }

    // Named routes
    switch (uri.path) {
      case '/':
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/register':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case '/checkout-success':
        return MaterialPageRoute(builder: (_) => const CheckoutSuccessScreen());
      case '/app':
      case '/home':
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case '/checkout':
        final plan = uri.queryParameters['plan'] ?? 'premium';
        final period = uri.queryParameters['period'] ?? 'monthly';
        return MaterialPageRoute(
          builder: (_) => CheckoutScreen(plan: plan, period: period),
        );
      case '/note-unlock':
        final token = uri.queryParameters['token'] ?? '';
        final noteId = uri.queryParameters['note_id'] ?? '';
        return MaterialPageRoute(
          builder: (_) => NoteUnlockVerificationScreen(token: token, noteId: noteId),
        );
      default:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
    }
  }
}
