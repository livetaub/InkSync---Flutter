import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminScaffold extends StatefulWidget {
  final Widget child;
  final String title;
  
  const AdminScaffold({super.key, required this.child, required this.title});

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  bool _isVerifying = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _verifyAdmin();
  }

  Future<void> _verifyAdmin() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }
      final result = await Supabase.instance.client
          .from('admin_users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (result == null) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) setState(() => _isVerifying = false);
    } on PostgrestException catch (_) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      debugPrint('Admin verification error: $e');
      if (mounted) {
        final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Connection Error'),
            content: const Text('Could not verify admin status. Please check your network connection.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Sign Out'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        if (shouldRetry == true) {
          _verifyAdmin();
        } else {
          await Supabase.instance.client.auth.signOut();
          if (mounted) context.go('/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: isWide
            ? null
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: isWide ? null : _buildDrawer(currentRoute),
      body: isWide
          ? Row(
              children: [
                _buildSidebar(currentRoute),
                Expanded(child: widget.child),
              ],
            )
          : widget.child,
    );
  }

  Widget _buildSidebar(String currentRoute) {
    return Container(
      width: 240,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _navItem(context, 'Dashboard', Icons.dashboard_rounded, '/dashboard', currentRoute),
          _navItem(context, 'Users', Icons.people_rounded, '/users', currentRoute),
          _navItem(context, 'Paywall', Icons.science_rounded, '/paywall', currentRoute),
          _navItem(context, 'Reports', Icons.analytics_rounded, '/reports', currentRoute),
          const Spacer(),
          _externalNavItem('Support Inbox', Icons.support_agent_rounded),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDrawer(String currentRoute) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, size: 24, color: Colors.white),
                  SizedBox(width: 12),
                  Text('InkSync Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            _navItem(context, 'Dashboard', Icons.dashboard_rounded, '/dashboard', currentRoute, closeDrawer: true),
            _navItem(context, 'Users', Icons.people_rounded, '/users', currentRoute, closeDrawer: true),
            _navItem(context, 'Paywall', Icons.science_rounded, '/paywall', currentRoute, closeDrawer: true),
            _navItem(context, 'Reports', Icons.analytics_rounded, '/reports', currentRoute, closeDrawer: true),
            const Spacer(),
            _externalNavItem('Support Inbox', Icons.support_agent_rounded, closeDrawer: true),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, String label, IconData icon, String route, String currentRoute, {bool closeDrawer = false}) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white54),
      title: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
      selected: isSelected,
      onTap: () {
        if (closeDrawer) Navigator.pop(context);
        context.go(route);
      },
    );
  }

  Widget _externalNavItem(String label, IconData icon, {bool closeDrawer = false}) {
    const supportUrl = 'https://web-black-five-25.vercel.app/#/projects/9773e382-5e44-4c64-b64e-4da37f93164d/inbox';
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w400)),
      trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white30, size: 16),
      onTap: () {
        if (closeDrawer) Navigator.pop(context);
        launchUrl(Uri.parse(supportUrl), mode: LaunchMode.externalApplication);
      },
    );
  }
}
