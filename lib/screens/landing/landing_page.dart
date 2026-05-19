import 'package:flutter/material.dart';
import '../../utils/platform_helper.dart' as platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _featuresKey = GlobalKey();
  late AnimationController _heroAnim;
  late AnimationController _floatAnim;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _floatAnim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _scrollController.addListener(() => setState(() => _scrollOffset = _scrollController.offset));
  }

  @override
  void dispose() {
    _heroAnim.dispose();
    _floatAnim.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _nav(String path) {
    final origin = platform.getLocationOrigin();
    platform.assignAndReload('$origin/#$path');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Animated gradient orbs
          _GradientOrbs(scrollOffset: _scrollOffset, floatAnim: _floatAnim),
          // Content
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _buildNav(isMobile, isLoggedIn),
                _buildHero(isMobile, isLoggedIn),
                _buildPainPoints(isMobile),
                _buildFeatures(isMobile, key: _featuresKey),
                _buildHowItWorks(isMobile),
                _buildStats(isMobile),
                _buildFinalCta(isMobile, isLoggedIn),
                _buildFooter(isMobile, isLoggedIn),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── NAV ──────────────────────────────────────────────────────
  Widget _buildNav(bool isMobile, bool isLoggedIn) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: 16),
      child: Row(
        children: [
          _brandLogo(),
          const Spacer(),
          if (!isMobile) ...[
            _navLink('Home', () {
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
            }),
            const SizedBox(width: 28),
            _navLink('Features', () {
              Scrollable.ensureVisible(
                _featuresKey.currentContext!,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            }),
            const SizedBox(width: 28),
            _navLink('Pricing', () => _nav('/pricing')),
            const SizedBox(width: 28),
            _navLink('FAQ', () => _nav('/pricing')),
            const SizedBox(width: 28),
            if (!isLoggedIn) _navLink('Sign In', () => _nav('/login')),
            if (!isLoggedIn) const SizedBox(width: 20),
            _ctaButton(isLoggedIn ? 'Go to App' : 'Get Started Free', () => _nav(isLoggedIn ? '/app' : '/pricing'), small: true),
          ],
          if (isMobile) ...[
            _ctaButton(isLoggedIn ? 'Go to App' : 'Get Started Free', () => _nav(isLoggedIn ? '/app' : '/pricing'), small: true),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF64748B)),
              onPressed: () => _showMobileMenu(isLoggedIn),
            ),
          ],
        ],
      ),
    );
  }

  void _showMobileMenu(bool isLoggedIn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          _menuItem('Home', Icons.home_rounded, () {
            Navigator.pop(ctx);
            _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
          }),
          _menuItem('Features', Icons.auto_awesome_rounded, () {
            Navigator.pop(ctx);
            Scrollable.ensureVisible(
              _featuresKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }),
          _menuItem('Pricing', Icons.diamond_outlined, () { Navigator.pop(ctx); _nav('/pricing'); }),
          _menuItem('FAQ', Icons.help_outline_rounded, () { Navigator.pop(ctx); _nav('/pricing'); }),
          if (!isLoggedIn) _menuItem('Sign In', Icons.login_rounded, () { Navigator.pop(ctx); _nav('/login'); }),
          if (isLoggedIn) _menuItem('Go to App', Icons.dashboard_rounded, () { Navigator.pop(ctx); _nav('/app'); }),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _menuItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(label, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  // ─── HERO ─────────────────────────────────────────────────────
  Widget _buildHero(bool isMobile, bool isLoggedIn) {
    return AnimatedBuilder(
      animation: _heroAnim,
      builder: (_, __) {
        final contentSlide = Tween(begin: 30.0, end: 0.0).animate(CurvedAnimation(parent: _heroAnim, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
        final contentFade = CurvedAnimation(parent: _heroAnim, curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
        
        final imageSlide = Tween(begin: 40.0, end: 0.0).animate(CurvedAnimation(parent: _heroAnim, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
        final imageFade = CurvedAnimation(parent: _heroAnim, curve: const Interval(0.3, 1.0, curve: Curves.easeIn));

        Widget heroContent = Column(
          crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, color: AppTheme.primaryColor, size: 16),
                SizedBox(width: 6),
                Text('Now available on iOS, Android & Web', style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            SizedBox(height: isMobile ? 28 : 40),
            // Headline
            Text(
              'Your thoughts,\nperfectly in sync.',
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: isMobile ? 36 : 64,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                height: 1.1,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'Stop losing notes between devices. InkSync keeps your notes, checklists, and ideas beautifully organized and instantly synced across every platform.',
                textAlign: isMobile ? TextAlign.center : TextAlign.left,
                style: TextStyle(fontSize: isMobile ? 16 : 18, color: const Color(0xFF64748B), height: 1.6),
              ),
            ),
            SizedBox(height: isMobile ? 32 : 44),
            // CTA buttons
            Wrap(
              alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
              spacing: 12, runSpacing: 12, 
              children: [
                _ctaButton(isLoggedIn ? 'Go to App' : 'Start Free — No Credit Card', () => _nav(isLoggedIn ? '/app' : '/pricing')),
                if (!isLoggedIn) _outlineButton('View Pricing', () => _nav('/pricing')),
              ]
            ),
            if (!isLoggedIn) const SizedBox(height: 20),
            if (!isLoggedIn) Text('Free forever • No credit card required', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13)),
          ]
        );

        Widget heroImage = Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 20))],
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/hero_image.png', fit: BoxFit.cover),
          ),
        );

        return Container(
          padding: EdgeInsets.fromLTRB(isMobile ? 24 : 64, isMobile ? 48 : 80, isMobile ? 24 : 64, isMobile ? 48 : 80),
          child: isMobile 
            ? Column(
                children: [
                  Transform.translate(offset: Offset(0, contentSlide.value), child: Opacity(opacity: contentFade.value, child: heroContent)),
                  const SizedBox(height: 48),
                  Transform.translate(offset: Offset(0, imageSlide.value), child: Opacity(opacity: imageFade.value, child: heroImage)),
                ]
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: Transform.translate(offset: Offset(0, contentSlide.value), child: Opacity(opacity: contentFade.value, child: heroContent))),
                  const SizedBox(width: 48),
                  Expanded(flex: 5, child: Transform.translate(offset: Offset(0, imageSlide.value), child: Opacity(opacity: imageFade.value, child: heroImage))),
                ]
              ),
        );
      },
    );
  }

  // ─── PAIN POINTS ──────────────────────────────────────────────
  Widget _buildPainPoints(bool isMobile) {
    return _ScrollReveal(
      scrollOffset: _scrollOffset,
      triggerOffset: isMobile ? 200 : 100, // Reduced offset for earlier visibility
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: isMobile ? 48 : 72),
        child: Column(children: [
          Text('Sound familiar?', textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 28 : 40, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), letterSpacing: -1)),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _painCard(0, 'Notes stuck on one device', 'You write on your phone, but can\'t find it on your laptop.'),
              _painCard(1, 'Can\'t find anything', 'Scrolling endlessly through unsorted notes looking for that one idea.'),
              _painCard(2, 'Sharing is painful', 'Copy-pasting notes into emails just to share with a teammate.'),
              _painCard(3, 'No privacy control', 'Sensitive notes sitting alongside grocery lists with no protection.'),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [AppTheme.primaryColor.withValues(alpha: 0.15), const Color(0xFF1E88E5).withValues(alpha: 0.15)])),
            child: Text('InkSync fixes all of this. ↓', style: TextStyle(color: AppTheme.primaryColor, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _painCard(int index, String title, String desc) {
    return _HoverCard(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PainGraphic(index: index),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.6)),
        ]),
      ),
    );
  }

  // ─── FEATURES ─────────────────────────────────────────────────
  Widget _buildFeatures(bool isMobile, {Key? key}) {
    final features = [
      _F(Icons.sync_rounded, 'Cross-Platform Sync', 'Your notes follow you everywhere — phone, tablet, laptop. Always up to date.', [const Color(0xFF10D98C), const Color(0xFF1E88E5)]),
      _F(Icons.people_rounded, 'Real-Time Collaboration', 'Invite others to edit notes together. See changes live, no refresh needed.', [const Color(0xFF6366F1), const Color(0xFFA855F7)]),
      _F(Icons.checklist_rounded, 'Notes & Checklists', 'Rich text notes and interactive checklists. Convert between them anytime.', [const Color(0xFFF59E0B), const Color(0xFFEF4444)]),
      _F(Icons.auto_awesome_rounded, 'AI Writing Assist', 'Let AI help you draft, rewrite, or expand your notes. Smart suggestions on demand.', [const Color(0xFF3B82F6), const Color(0xFF06B6D4)]),
      _F(Icons.label_rounded, 'Tags & Colors', 'Organize with colored themes and tags. Find anything in seconds.', [const Color(0xFFEC4899), const Color(0xFFF97316)]),
      _F(Icons.lock_rounded, 'Note Locking', 'Password-protect sensitive notes. Your private thoughts stay private.', [const Color(0xFF14B8A6), const Color(0xFF22D3EE)]),
    ];

    return _ScrollReveal(
      key: key,
      scrollOffset: _scrollOffset,
      triggerOffset: isMobile ? 600 : 400, // Reduced offset
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: isMobile ? 48 : 72),
        child: Column(children: [
          Text('Everything you need', textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 28 : 40, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), letterSpacing: -1)),
          const SizedBox(height: 12),
          Text('Powerful features, beautifully simple.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 16)),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: List.generate(features.length, (i) => _featureCard(features[i], i, isMobile)),
          ),
        ]),
      ),
    );
  }

  Widget _featureCard(_F f, int index, bool isMobile) {
    return _HoverCard(
      width: isMobile ? double.infinity : 360,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FeatureGraphic(f: f, index: index),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.title, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(f.desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, height: 1.6)),
          ]),
        ),
      ]),
    );
  }

  // ─── HOW IT WORKS ─────────────────────────────────────────────
  Widget _buildHowItWorks(bool isMobile) {
    return _ScrollReveal(
      scrollOffset: _scrollOffset,
      triggerOffset: isMobile ? 1200 : 900, // Reduced offset
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: isMobile ? 48 : 72),
        child: Column(children: [
          Text('Get started in 30 seconds', textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 28 : 40, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), letterSpacing: -1)),
          const SizedBox(height: 48),
          Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
            _stepCard('1', 'Sign up free', 'Create your account with email or Google. No credit card needed.', Icons.person_add_rounded),
            _stepCard('2', 'Start writing', 'Create notes, checklists, tag and color-code them your way.', Icons.edit_note_rounded),
            _stepCard('3', 'Sync everywhere', 'Open InkSync on any device. Everything is already there.', Icons.devices_rounded),
          ]),
        ]),
      ),
    );
  }

  Widget _stepCard(String num, String title, String desc, IconData icon) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor.withValues(alpha: 0.12)),
          child: Center(child: Text(num, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 24, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(height: 20),
        Icon(icon, color: const Color(0xFF94A3B8), size: 32),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5)),
      ]),
    );
  }

  // ─── STATS ────────────────────────────────────────────────────
  Widget _buildStats(bool isMobile) {
    return _ScrollReveal(
      scrollOffset: _scrollOffset,
      triggerOffset: isMobile ? 1800 : 1300, // Reduced offset
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: 32),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48, vertical: isMobile ? 32 : 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 10))],
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
        ),
        child: Wrap(spacing: 48, runSpacing: 32, alignment: WrapAlignment.center, children: [
          _stat('3', 'Platforms', 'Web, iOS, Android'),
          _stat('∞', 'Sync Speed', 'Real-time, always'),
          _stat('100%', 'Free Tier', 'No credit card'),
          _stat('256-bit', 'Encryption', 'Your data is safe'),
        ]),
      ),
    );
  }

  Widget _stat(String value, String label, String sub) {
    return SizedBox(
      width: 160,
      child: Column(children: [
        Text(value, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 36, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      ]),
    );
  }

  // ─── FINAL CTA ────────────────────────────────────────────────
  Widget _buildFinalCta(bool isMobile, bool isLoggedIn) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: isMobile ? 56 : 80),
      child: Column(children: [
        Text('Ready to sync your thoughts?', textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 28 : 44, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), letterSpacing: -1)),
        const SizedBox(height: 16),
        Text('Join thousands who never lose a note again.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 16)),
        const SizedBox(height: 36),
        _ctaButton(isLoggedIn ? 'Go to App' : 'Create Your Free Account', () => _nav(isLoggedIn ? '/app' : '/login')),
        const SizedBox(height: 24),
        Wrap(alignment: WrapAlignment.center, spacing: 16, children: [
          _storeButton('App Store', Icons.apple_rounded),
          _storeButton('Google Play', Icons.android_rounded),
        ]),
      ]),
    );
  }

  // ─── FOOTER ───────────────────────────────────────────────────
  Widget _buildFooter(bool isMobile, bool isLoggedIn) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _brandLogo(),
          const Spacer(),
          _footerLink('Pricing', () => _nav('/pricing')),
          const SizedBox(width: 24),
          if (!isLoggedIn) _footerLink('Sign In', () => _nav('/login')),
        ]),
        const SizedBox(height: 20),
        Text('© 2026 InkSync. All rights reserved.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      ]),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────
  Widget _brandLogo() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF10D98C)]).createShader(b),
        child: const Icon(Icons.sync_rounded, color: Colors.white, size: 28),
      ),
      const SizedBox(width: 8),
      const Text('InkSync', style: TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
    ]);
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _ctaButton(String label, VoidCallback onTap, {bool small = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 20 : 32, vertical: small ? 10 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF10D98C)]),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Text(label, style: TextStyle(color: Colors.white, fontSize: small ? 13 : 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withValues(alpha: 0.1))),
          child: Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _storeButton(String label, IconData icon) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14))),
    );
  }
}

// ─── HELPER CLASSES ───────────────────────────────────────────────
class _F {
  final IconData icon;
  final String title, desc;
  final List<Color> colors;
  const _F(this.icon, this.title, this.desc, this.colors);
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final double width;
  const _HoverCard({required this.child, required this.width});
  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: widget.width,
        transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: _isHovered 
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 12))] 
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 8))],
          border: Border.all(color: _isHovered ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PainGraphic extends StatelessWidget {
  final int index;
  const _PainGraphic({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (index == 0) ...[ // Devices
            const Positioned(left: 12, child: Icon(Icons.smartphone_rounded, color: Color(0xFF94A3B8), size: 28)),
            const Positioned(right: 8, child: Icon(Icons.laptop_mac_rounded, color: Color(0xFF64748B), size: 36)),
            const Positioned(top: 10, right: 10, child: Icon(Icons.error_rounded, color: Color(0xFFEF4444), size: 16)),
          ] else if (index == 1) ...[ // Search
            const Positioned(child: Icon(Icons.manage_search_rounded, color: Color(0xFF64748B), size: 40)),
            Positioned(bottom: 12, right: 12, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Color(0xFFFCA5A5), shape: BoxShape.circle), child: const Icon(Icons.question_mark_rounded, color: Colors.white, size: 10))),
          ] else if (index == 2) ...[ // Sharing
            const Positioned(left: 14, child: Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 30)),
            const Positioned(right: 14, child: Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 30)),
            const Positioned(child: Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 22)),
          ] else ...[ // Privacy
            const Positioned(child: Icon(Icons.file_copy_rounded, color: Color(0xFF94A3B8), size: 36)),
            const Positioned(child: Icon(Icons.visibility_rounded, color: Color(0xFFF59E0B), size: 20)),
          ]
        ],
      ),
    );
  }
}

class _FeatureGraphic extends StatelessWidget {
  final _F f;
  final int index;
  const _FeatureGraphic({required this.f, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [f.colors[0].withValues(alpha: 0.1), f.colors[1].withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.03))),
      ),
      child: Stack(
        children: [
          // Background abstract shapes
          Positioned(top: -20, right: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: f.colors[1].withValues(alpha: 0.1)))),
          Positioned(bottom: 20, left: 20, child: Container(width: 60, height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: f.colors[0].withValues(alpha: 0.15)))),
          // Main Icon Composition
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: f.colors[0].withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(colors: f.colors).createShader(b),
                child: Icon(f.icon, color: Colors.white, size: 36),
              ),
            ),
          ),
          // Accents based on index
          if (index == 0) ...[
            const Positioned(top: 40, left: 80, child: Icon(Icons.cloud_sync_rounded, color: Color(0xFF10D98C), size: 24)),
          ] else if (index == 1) ...[
            const Positioned(bottom: 30, right: 60, child: Icon(Icons.edit_rounded, color: Color(0xFFA855F7), size: 20)),
          ] else if (index == 3) ...[
            const Positioned(top: 30, right: 80, child: Icon(Icons.auto_awesome, color: Color(0xFF06B6D4), size: 24)),
          ]
        ],
      ),
    );
  }
}

class _ScrollReveal extends StatelessWidget {
  final double scrollOffset, triggerOffset;
  final Widget child;
  const _ScrollReveal({super.key, required this.scrollOffset, required this.triggerOffset, required this.child});

  @override
  Widget build(BuildContext context) {
    // Smoother animation based on progress with a slight scale effect
    final progress = ((scrollOffset - triggerOffset + 600) / 400).clamp(0.0, 1.0);
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 40 * (1 - progress)), 
        child: Transform.scale(
          scale: 0.98 + (0.02 * progress),
          child: child
        )
      ),
    );
  }
}

class _GradientOrbs extends StatelessWidget {
  final double scrollOffset;
  final AnimationController floatAnim;
  const _GradientOrbs({required this.scrollOffset, required this.floatAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatAnim,
      builder: (_, __) {
        final f = floatAnim.value;
        return Stack(children: [
          Positioned(
            top: -100 - scrollOffset * 0.3 + f * 20,
            right: -80,
            child: _orb(400, const Color(0xFFFCA5A5).withValues(alpha: 0.15)), // Coral
          ),
          Positioned(
            top: 300 - scrollOffset * 0.2 + f * 15,
            left: -120,
            child: _orb(350, const Color(0xFF5EEAD4).withValues(alpha: 0.2)), // Teal
          ),
          Positioned(
            top: 900 - scrollOffset * 0.15,
            right: -60,
            child: _orb(300, const Color(0xFFFCD34D).withValues(alpha: 0.15)), // Warm Yellow
          ),
        ]);
      },
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
