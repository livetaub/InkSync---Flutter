import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/notes_service.dart';
import '../../config/theme.dart';

/// Screen to display a shared note and allow user to claim it
class SharedNoteScreen extends StatefulWidget {
  final String shareToken;

  const SharedNoteScreen({super.key, required this.shareToken});

  @override
  State<SharedNoteScreen> createState() => _SharedNoteScreenState();
}

class _SharedNoteScreenState extends State<SharedNoteScreen> {
  Map<String, dynamic>? _noteData;
  String? _sharedByEmail;
  bool _isLoading = true;
  bool _isClaiming = false;
  String? _error;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSharedNote();
  }

  Future<void> _loadSharedNote() async {
    try {
      final response = await _supabase
          .from('shared_notes')
          .select()
          .eq('id', widget.shareToken)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _error = 'This shared note was not found or has expired.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _noteData = Map<String, dynamic>.from(response['note_data'] ?? {});
        _sharedByEmail = response['shared_by_email'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading shared note: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _claimNote() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isLoggedIn) {
      // Navigate to login with return path
      Navigator.pushNamed(
        context,
        '/login',
        arguments: {'returnTo': '/shared/${widget.shareToken}'},
      );
      return;
    }

    setState(() => _isClaiming = true);

    try {
      final notesService = NotesService(authService);
      await notesService.claimSharedNote(widget.shareToken);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added to your collection!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => _isClaiming = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context, listen: false);
    final isLoggedIn = authService.isLoggedIn;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final title = _noteData?['title'] ?? 'Untitled Note';
    final content = _noteData?['content'] ?? '';
    final type = _noteData?['type'] ?? 'text';
    final checklistItems = _noteData?['checklistItems'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFEF9C3),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'InkSync',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_sharedByEmail != null)
                    Text(
                      'Shared by: $_sharedByEmail',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),

            // Note content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      if (title.isNotEmpty) const SizedBox(height: 16),

                      // Content based on type
                      if (type == 'text')
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: isDark
                                ? Colors.white70
                                : AppTheme.textSecondary,
                          ),
                        )
                      else
                        ...checklistItems.map((item) {
                          final checked = item['checked'] == true;
                          final text = item['text'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  checked
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: checked
                                      ? AppTheme.primaryColor
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      decoration: checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDark
                                          ? Colors.white70
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isClaiming ? null : _claimNote,
                    icon: _isClaiming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isLoggedIn ? Icons.add : Icons.login),
                    label: Text(
                      isLoggedIn
                          ? 'Add to My Notes'
                          : 'Login to add to your notepad',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
