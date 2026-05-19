import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/platform_helper.dart' as platform;
import 'config/theme.dart';
import 'config/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'services/auth_service.dart'; // Legacy wrapper around Supabase
import 'services/supabase_auth_service.dart';
import 'services/supabase_notes_service.dart';
import 'services/notes_service.dart';
import 'services/gemini_service.dart';
import 'services/debug_service.dart';
import 'services/local_database_service.dart';
import 'services/local_notes_service.dart';
import 'services/sync_engine.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/shared/shared_note_screen.dart';
import 'screens/note_edit/note_edit_screen.dart';
import 'screens/trash/trash_screen.dart';
import 'screens/snapshot/snapshot_viewer_screen.dart';
import 'screens/checkout/checkout_entry.dart';
import 'widgets/main_menu_sheet.dart';
import 'widgets/web_sidebar.dart';
import 'widgets/mobile_sidebar.dart';
import 'screens/auth/welcome_screen.dart';

import 'providers/selection_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Debug Service
  await DebugService.instance.init();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Mobile-only: Initialize local database, notifications, and subscriptions
  if (!kIsWeb) {
    await NotificationService.instance.init();
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
            title: 'InkSync',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              // Wrap all pages with debug panel
              return DebugWrapper(child: child ?? const SizedBox.shrink());
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
        final plan = uri.queryParameters['plan'];
        return MaterialPageRoute(
          builder: (_) => LoginScreen(showRegisterDialog: true, initialPlan: plan),
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
      default:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
    }
  }
}

/// AuthWrapper - Decides whether to show login or home based on auth state.
/// On WEB: Uses Supabase auth stream (existing behavior).
/// On MOBILE: Checks for guest mode via SharedPreferences, shows WelcomeScreen on first launch.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingGuest = true;
  bool _isGuestMode = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkGuestMode();
    } else {
      _isCheckingGuest = false;
    }
  }

  Future<void> _checkGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final isGuest = prefs.getBool('is_guest_mode') ?? false;

    if (mounted) {
      setState(() {
        _isGuestMode = isGuest;
        _isCheckingGuest = !hasSeenOnboarding && !isGuest;
      });
    }

    // If user has seen onboarding and chose guest, go straight to main
    // If user has an active session, go to main
    // If first launch, show welcome screen (_isCheckingGuest stays true)
    if (hasSeenOnboarding) {
      setState(() => _isCheckingGuest = false);
    }
  }

  Future<void> _enterGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setBool('is_guest_mode', true);
    if (mounted) {
      setState(() {
        _isGuestMode = true;
        _isCheckingGuest = false;
      });
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<SupabaseAuthService>(
      context,
      listen: false,
    );

    // Mobile first-launch: show WelcomeScreen
    if (!kIsWeb && _isCheckingGuest) {
      return WelcomeScreen(
        onLoginTap: _goToLogin,
        onSignUpTap: _goToLogin,
        onGoogleSignIn: () async {
          await authService.signInWithGoogle();
        },
        onGuestContinue: _enterGuestMode,
      );
    }

    // Mobile guest mode: skip auth, go straight to main
    if (!kIsWeb && _isGuestMode) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // User logged in after being a guest — exit guest mode
        return const MainNavigation();
      }
      return const MainNavigation();
    }

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Check if user is logged in
        final session = snapshot.data?.session;
        if (session != null) {
          // Web-only: Check for a pending plan from OAuth signup flow
          if (kIsWeb) {
            final pendingPlan = platform.getLocalStorageValue('pending_plan');
            final pendingPeriod = platform.getLocalStorageValue('pending_period');
            if (pendingPlan != null && pendingPlan.isNotEmpty) {
              platform.removeLocalStorageValue('pending_plan');
              platform.removeLocalStorageValue('pending_period');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final origin = platform.getLocationOrigin();
                platform.setLocationHref('$origin/#/checkout?plan=$pendingPlan&period=${pendingPeriod ?? 'monthly'}');
              });
            }
          }
          return const MainNavigation();
        }

        return const LoginScreen();
      },
    );
  }
}

/// MainNavigation - Bottom navigation with all main screens
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  double _noteListWidth = 380; // Resizable width for note list panel

  // GlobalKeys to access HomeScreen state for refresh
  final GlobalKey<HomeScreenState> _notesScreenKey =
      GlobalKey<HomeScreenState>();
  final GlobalKey<HomeScreenState> _checklistsScreenKey =
      GlobalKey<HomeScreenState>();

  // Store screens as late final to preserve their state
  late final List<Widget> _screens = [
    HomeScreen(
      key: _notesScreenKey,
      noteTypeFilter: 'text',
    ), // Notes only (index 0)
    HomeScreen(
      key: _checklistsScreenKey,
      noteTypeFilter: 'checklist',
    ), // Checklists only (index 1)
    const CalendarScreen(), // Calendar (index 2)
    const TrashScreen(), // Trash (index 3)
  ];

  @override
  void initState() {
    super.initState();
    _initDefaultFolders();
    if (kIsWeb) {
      _checkPendingSnapshotImport();
    } else {
      // Mobile: trigger initial sync when entering the main app
      _triggerMobileSync();
    }
  }

  /// Initialize default folders for new users
  Future<void> _initDefaultFolders() async {
    // TODO: Implement with Supabase folder service
    debugPrint('TODO: Initialize default folders with Supabase');
  }

  /// Mobile: initial sync + subscription setup on app launch
  Future<void> _triggerMobileSync() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isLoggedIn) {
      // Initialize RevenueCat with the authenticated user
      final subService = SubscriptionService.instance;
      await subService.initialize(authService);

      // Run delta sync
      final syncEngine = SyncEngine(LocalDatabaseService.instance, authService);
      await syncEngine.sync();
      if (mounted) {
        setState(() => _lastSyncAt = DateTime.now());
      }
    }
  }

  /// Check if the user arrived via a snapshot import link after login.
  /// Web-only: URL pattern: /#/login?import_snapshot=TOKEN
  Future<void> _checkPendingSnapshotImport() async {
    if (!kIsWeb) return;
    try {
      final fragment = platform.getLocationHash();
      if (!fragment.contains('import_snapshot=')) return;

      // Parse token from fragment
      final fragmentUri = Uri.parse(fragment.replaceFirst('#', ''));
      final token = fragmentUri.queryParameters['import_snapshot'];
      if (token == null || token.isEmpty) return;

      // Clean the URL immediately to prevent re-importing on refresh
      platform.replaceHistoryState('${platform.getLocationOrigin()}/#/app');

      // Fetch the snapshot
      final snapshot = await Supabase.instance.client
          .from('note_snapshots')
          .select()
          .eq('token', token)
          .maybeSingle();

      if (snapshot == null || !mounted) return;

      // Import it
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final newNote = await notesService.importFromSnapshot(snapshot);

      if (!mounted) return;

      if (newNote != null) {
        // Refresh the note lists
        _performDataSync();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${newNote.title.isNotEmpty ? newNote.title : 'Untitled'}" imported to your notes'),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing snapshot: $e');
    }
  }

  /// Centralized data sync function - call this whenever data needs to be synced
  Future<void> _performDataSync() async {
    debugPrint('Performing data sync...');
    try {
      await Future.wait([
        if (_notesScreenKey.currentState != null) _notesScreenKey.currentState!.refreshData(),
        if (_checklistsScreenKey.currentState != null) _checklistsScreenKey.currentState!.refreshData(),
      ]);
      
      if (mounted) {
        setState(() {
          _lastSyncAt = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
      rethrow;
    }
  }

  /// Legacy method for backwards compatibility
  void _refreshHomeScreens() {
    _performDataSync(); // fire and forget
  }

  /// Manual sync triggered by user clicking sync button
  Future<void> _handleSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);

    try {
      await _performDataSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  /// Toggle global search on the currently visible HomeScreen
  void _toggleGlobalSearch() {
    // Determine which HomeScreen key to use
    final selectionProvider = Provider.of<SelectionProvider>(context, listen: false);
    final isWide = MediaQuery.of(context).size.width > 900;
    final currentIndex = isWide ? selectionProvider.currentScreenIndex : _currentIndex;

    HomeScreenState? activeScreen;
    if (currentIndex == 0) {
      activeScreen = _notesScreenKey.currentState;
    } else if (currentIndex == 1) {
      activeScreen = _checklistsScreenKey.currentState;
    }

    if (activeScreen != null) {
      if (activeScreen.isSearchActive) {
        activeScreen.deactivateSearch();
      } else {
        activeScreen.activateSearch();
      }
    } else {
      // If not on a HomeScreen tab, switch to Notes first then activate search
      if (isWide) {
        selectionProvider.setScreenIndex(0);
      } else {
        setState(() => _currentIndex = 0);
      }
      _performDataSync();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notesScreenKey.currentState?.activateSearch();
      });
    }
  }

  void _openMenu(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (isWide) {
          // Floating desktop style
          return Align(
            alignment: Alignment.bottomRight,
            child: Container(
              margin: const EdgeInsets.only(right: 8, bottom: 70),
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 600),
              child: MainMenuSheet(
                isFloating: true,
                onDataChanged: _performDataSync,
              ),
            ),
          );
        } else {
          // Native mobile bottom sheet
          return MainMenuSheet(
            isFloating: false,
            onDataChanged: _performDataSync,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final selectionProvider = Provider.of<SelectionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117), // Dark background
        body: Row(
          children: [
            // Pane 1: Persistent Sidebar
            WebSidebar(
              currentIndex: selectionProvider.currentScreenIndex,
              onIndexChanged: (index) {
                selectionProvider.setScreenIndex(index);
                _performDataSync();
              },
              onMenuOpen: () => _openMenu(context),
              onSync: _handleSync,
              onSearch: _toggleGlobalSearch,
              isSyncing: _isSyncing,
              lastSyncAt: _lastSyncAt,
              onTrashOpen: () {
                selectionProvider.setScreenIndex(3); // Show Trash screen inline
              },

              onCreateNote: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        const NoteEditScreen(noteType: 'text'),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                ).then((_) => _refreshHomeScreens());
              },
              onCreateChecklist: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        const NoteEditScreen(noteType: 'checklist'),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                ).then((_) => _refreshHomeScreens());
              },
            ),

            // Combined Note List and Editor Area with rounded corners
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? AppTheme.bgPrimaryDark
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Note List - Resizable
                    SizedBox(
                      width: _noteListWidth,
                      child: IndexedStack(
                        index: selectionProvider.currentScreenIndex,
                        children: _screens,
                      ),
                    ),
                    // Draggable Divider
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _noteListWidth += details.delta.dx;
                            // Clamp between min and max widths
                            _noteListWidth = _noteListWidth.clamp(280.0, 600.0);
                          });
                        },
                        child: Container(
                          width: 8,
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 1,
                              color: themeProvider.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Editor
                    Expanded(
                      child: selectionProvider.selectedNote != null
                          ? NoteEditScreen(
                              note: selectionProvider.selectedNote,
                              isEmbedded: true,
                              key: ValueKey(selectionProvider.selectedNote!.id),
                              onSave: _refreshHomeScreens,
                              initialSearchQuery: selectionProvider.pendingSearchQuery,
                            )
                          : _buildEmptyEditorPlaceholder(
                              themeProvider.isDarkMode,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile Navigation - Bottom navigation bar
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? AppTheme.bgPrimaryDark
          : Colors.white,
      body: IndexedStack(
        index: _currentIndex, 
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMobileCreateDialog(context),
        backgroundColor: const Color(0xFF10D98C),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? const Color(0xFF1A1D21)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: themeProvider.isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  icon: Icons.description_outlined,
                  label: 'Notes',
                  isSelected: _currentIndex == 0,
                  onTap: () {
                    setState(() => _currentIndex = 0);
                    _performDataSync();
                  },
                  isDark: themeProvider.isDarkMode,
                ),
                _buildBottomNavItem(
                  icon: Icons.checklist_rounded,
                  label: 'Checklists',
                  isSelected: _currentIndex == 1,
                  onTap: () {
                    setState(() => _currentIndex = 1);
                    _performDataSync();
                  },
                  isDark: themeProvider.isDarkMode,
                ),
                _buildBottomNavItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Calendar',
                  isSelected: _currentIndex == 2,
                  onTap: () {
                    setState(() => _currentIndex = 2);
                    // Calendar might need refresh if added
                  },
                  isDark: themeProvider.isDarkMode,
                ),
                _buildBottomNavItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: false,
                  onTap: _toggleGlobalSearch,
                  isDark: themeProvider.isDarkMode,
                ),
                _buildBottomNavItem(
                  icon: Icons.menu_rounded,
                  label: 'Menu',
                  isSelected: false,
                  onTap: () => _openMenu(context),
                  isDark: themeProvider.isDarkMode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final color = isSelected
        ? const Color(0xFF10D98C)
        : (isDark ? Colors.white54 : AppTheme.textSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show creation menu for mobile - matches desktop sidebar style
  void _showMobileCreateDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Note option
              _buildCreateOption(
                context,
                icon: Icons.description_outlined,
                label: 'Note',
                subtitle: 'Write text, add images',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          const NoteEditScreen(noteType: 'text'),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  ).then((_) => _refreshHomeScreens());
                },
              ),

              const SizedBox(height: 12),

              // Checklist option
              _buildCreateOption(
                context,
                icon: Icons.checklist_rounded,
                label: 'Checklist',
                subtitle: 'Track tasks with checkboxes',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) =>
                          const NoteEditScreen(noteType: 'checklist'),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  ).then((_) => _refreshHomeScreens());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : AppTheme.textMuted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyEditorPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 80,
            color: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a note to view or edit',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
