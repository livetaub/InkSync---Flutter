import 'package:flutter/material.dart';
import '../../config/theme.dart';


/// Tutorial/Onboarding screen showing app features
class TutorialScreen extends StatefulWidget {
  final bool isOnboarding;
  final bool isDialog;
  final VoidCallback? onComplete;

  const TutorialScreen({
    super.key,
    this.isOnboarding = false,
    this.isDialog = false,
    this.onComplete,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialPage> _pages = [
    TutorialPage(
      icon: Icons.edit_note_rounded,
      title: 'Welcome to InkSync',
      description:
          'Your ideas, beautifully organized. Create notes, checklists, and more with a delightful experience.',
      color: AppTheme.primaryColor,
    ),
    TutorialPage(
      icon: Icons.palette_outlined,
      title: 'Colorful Notes',
      description:
          'Organize your notes with 10 beautiful colors. Pin important notes to the top for quick access.',
      color: Colors.orange,
    ),
    TutorialPage(
      icon: Icons.auto_fix_high,
      title: 'AI Writing Assistant',
      description:
          'Proofread, rephrase, or transform your writing with our AI-powered tools. Make every note perfect.',
      color: Colors.purple,
    ),
    TutorialPage(
      icon: Icons.people_outline,
      title: 'Collaborate',
      description:
          'Share notes with friends and colleagues. Work together in real-time with live sync.',
      color: Colors.blue,
    ),
    TutorialPage(
      icon: Icons.calendar_today_outlined,
      title: 'Calendar Integration',
      description:
          'Add events, set reminders, and never miss an important date. Your notes and calendar, together.',
      color: Colors.teal,
    ),
    TutorialPage(
      icon: Icons.lock_outline,
      title: 'Secure & Private',
      description:
          'Lock sensitive notes with a password. Your data is encrypted and synced securely across devices.',
      color: Colors.red,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      children: [
        if (widget.isDialog)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        // Page content
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(page);
            },
          ),
        ),

        // Page indicators
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Back'),
                )
              else
                TextButton(onPressed: _finish, child: const Text('Skip')),
              const Spacer(),
              ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isDialog) {
      return content;
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : Colors.white,
      appBar: widget.isOnboarding
          ? null
          : AppBar(
              backgroundColor: isDark ? AppTheme.bgPrimaryDark : Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Tutorial',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
      body: SafeArea(
        child: content,
      ),
    );
  }

  Widget _buildPage(TutorialPage page) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 60, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class TutorialPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  TutorialPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
