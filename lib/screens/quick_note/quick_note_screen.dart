import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/selection_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme.dart';
import '../../models/quick_note.dart';
import '../../services/quick_note_service.dart';
import '../../services/auth_service.dart';
import '../../utils/ui_helper.dart';
import '../subscription/mobile_paywall_screen.dart';
import '../../widgets/lined_paper_painter.dart';

/// QuickNoteScreen — WhatsApp-style "message yourself" experience
/// Supports: text, voice notes, images, PDFs
class QuickNoteScreen extends StatefulWidget {
  final bool isEmbedded;
  
  const QuickNoteScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<QuickNoteScreen> createState() => _QuickNoteScreenState();
}

class _QuickNoteScreenState extends State<QuickNoteScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  late QuickNoteService _service;
  List<QuickNote> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  // Edit mode
  String? _editingMessageId;
  final TextEditingController _editController = TextEditingController();

  // Pinned banner expand state
  bool _isPinnedBannerExpanded = false;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  void _initService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = QuickNoteService(authService);
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final messages = await _service.getMessages();
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(QuickNote msg) {
    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index == -1) return;

    if (_scrollController.hasClients) {
      final total = _messages.length;
      final targetFraction = index / (total > 0 ? total : 1);
      final maxOffset = _scrollController.position.maxScrollExtent;
      final targetOffset = targetFraction * maxOffset;

      _scrollController.animateTo(
        targetOffset.clamp(0.0, maxOffset),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Check if user has premium access. Returns true if allowed, false if gated.
  Future<bool> _checkPremiumAccess() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('account_type')
          .eq('id', userId)
          .single();
      final accountType = profile['account_type'] ?? 'free';

      if (accountType == 'free') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MobilePaywallScreen(
                featureContext: 'Quick Note',
                triggerSource: 'quick_note',
              ),
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking premium access: $e');
      return true; // Allow on error to avoid blocking
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Premium gate
    final allowed = await _checkPremiumAccess();
    if (!allowed) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final message = QuickNote(
      userId: authService.currentUserId ?? '',
      type: 'text',
      content: text,
    );

    final sent = await _service.sendMessage(message);
    if (mounted) {
      setState(() {
        if (sent != null) _messages.add(sent);
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  // ignore: unused_element
  Future<void> _pickAndSendImage() async {
    // Premium gate
    final allowed = await _checkPremiumAccess();
    if (!allowed) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;

      final url = await _service.uploadMediaBytes(bytes, fileName, 'image');
      final authService = Provider.of<AuthService>(context, listen: false);
      final message = QuickNote(
        userId: authService.currentUserId ?? '',
        type: 'image',
        mediaUrl: url,
        fileName: fileName,
      );

      final sent = await _service.sendMessage(message);
      if (mounted) {
        setState(() {
          if (sent != null) _messages.add(sent);
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        showErrorSnackBar(context, 'Failed to send image');
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    // Premium gate
    final allowed = await _checkPremiumAccess();
    if (!allowed) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await io.File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        if (mounted) showErrorSnackBar(context, 'Could not read file data');
        return;
      }

      final ext = file.extension?.toLowerCase() ?? '';
      final isImg = ['png', 'jpg', 'jpeg', 'webp'].contains(ext);
      final mediaType = isImg ? 'image' : 'pdf';

      setState(() => _isSending = true);
      final url = await _service.uploadMediaBytes(
        bytes,
        file.name,
        mediaType,
      );
      final authService = Provider.of<AuthService>(context, listen: false);
      final message = QuickNote(
        userId: authService.currentUserId ?? '',
        type: mediaType,
        mediaUrl: url,
        fileName: file.name,
      );

      final sent = await _service.sendMessage(message);
      if (mounted) {
        setState(() {
          if (sent != null) _messages.add(sent);
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending attachment: $e');
      if (mounted) {
        setState(() => _isSending = false);
        showErrorSnackBar(context, 'Failed to send attachment: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    // Check premium gate
    final allowed = await _checkPremiumAccess();
    if (!allowed) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Microphone permission denied. Please enable microphone access in your browser/device settings.',
          );
        }
        return;
      }

      if (kIsWeb) {
        // Default RecordConfig lets the browser pick native audio encoder (webm/mp4)
        await _audioRecorder.start(const RecordConfig(), path: '');
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      }

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          setState(() => _recordingSeconds++);
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        showErrorSnackBar(
          context,
          'Could not access microphone. Ensure microphone permission is granted in site settings.',
        );
      }
    }
  }

  Future<void> _stopAndSendVoiceNote() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      final duration = _recordingSeconds;

      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
        _isSending = true;
      });

      if (path != null && path.isNotEmpty) {
        String url;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'voice_$timestamp.${kIsWeb ? 'webm' : 'm4a'}';

        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          url = await _service.uploadMediaBytes(response.bodyBytes, fileName, 'voice');
        } else {
          url = await _service.uploadMedia(path, fileName, 'voice');
        }

        final authService = Provider.of<AuthService>(context, listen: false);
        final message = QuickNote(
          userId: authService.currentUserId ?? '',
          type: 'voice',
          mediaUrl: url,
          fileName: fileName,
          durationSeconds: duration > 0 ? duration : 1,
        );

        final sent = await _service.sendMessage(message);
        if (mounted) {
          setState(() {
            if (sent != null) _messages.add(sent);
            _isSending = false;
          });
          _scrollToBottom();
        }
      } else {
        if (mounted) setState(() => _isSending = false);
      }
    } catch (e) {
      debugPrint('Error sending voice note: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isSending = false;
        });
        showErrorSnackBar(context, 'Failed to send voice note');
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });
    }
  }



  Future<void> _pickFromCamera() async {
    // Premium gate
    final allowed = await _checkPremiumAccess();
    if (!allowed) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final fileName = picked.name;

      final url = await _service.uploadMediaBytes(bytes, fileName, 'image');
      final authService = Provider.of<AuthService>(context, listen: false);
      final message = QuickNote(
        userId: authService.currentUserId ?? '',
        type: 'image',
        mediaUrl: url,
        fileName: fileName,
      );

      final sent = await _service.sendMessage(message);
      if (mounted) {
        setState(() {
          if (sent != null) _messages.add(sent);
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error capturing camera image: $e');
      if (mounted) {
        setState(() => _isSending = false);
        showErrorSnackBar(context, 'Failed to capture image: $e');
      }
    }
  }

  Future<void> _deleteMessage(QuickNote msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || msg.id == null) return;

    try {
      // Delete media from storage if applicable
      if (msg.mediaUrl != null) {
        await _service.deleteMedia(msg.mediaUrl!);
      }
      await _service.deleteMessage(msg.id!);
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == msg.id);
        });
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Failed to delete message');
    }
  }

  Future<void> _togglePinMessage(QuickNote msg) async {
    if (msg.id == null) return;
    final newPinnedState = !msg.isPinned;
    try {
      await _service.updateMessage(msg.id!, {'is_pinned': newPinnedState});
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            _messages[index] = msg.copyWith(isPinned: newPinnedState);
          }
        });
        showSuccessSnackBar(
          context,
          newPinnedState ? 'Message pinned to top' : 'Message unpinned',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Failed to update pin status');
    }
  }

  void _startEditing(QuickNote msg) {
    if (msg.type != 'text' || msg.id == null) return;
    setState(() {
      _editingMessageId = msg.id;
      _editController.text = msg.content ?? '';
    });
  }

  Future<void> _saveEdit(QuickNote msg) async {
    final newText = _editController.text.trim();
    if (newText.isEmpty || msg.id == null) return;

    try {
      await _service.updateMessage(msg.id!, {'content': newText});
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            _messages[index] = msg.copyWith(
              content: newText,
              updatedAt: DateTime.now(),
            );
          }
          _editingMessageId = null;
        });
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Failed to update message');
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editController.clear();
    });
  }

  void _showMessageActions(QuickNote msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D21) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              if (msg.type == 'text')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEditing(msg);
                  },
                ),
              if (msg.type == 'text' && msg.content != null)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.content!));
                    Navigator.pop(ctx);
                    showSuccessSnackBar(context, 'Copied to clipboard');
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade400),
                title: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        leading: widget.isEmbedded && MediaQuery.of(context).size.width < 800
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Provider.of<SelectionProvider>(context, listen: false).clearSelection();
                },
              )
            : null,
        automaticallyImplyLeading: !widget.isEmbedded,
        backgroundColor: isDark ? const Color(0xFF1A1D21) : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            // Gradient InkSync Logo
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF1E88E5), // Blue
                  Color(0xFF10D98C), // Green
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Image.asset(
                'assets/images/logo_transparent.png',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'InkSync - Quick Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHelperMessage(isDark),
          // Messages area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildMessageList(isDark),
          ),

          // Input bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Quick Note is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jot down quick thoughts, ideas, or send files',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildMessageBubble(msg, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHelperMessage(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900.withValues(alpha: 0.5) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.blueGrey.shade700 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Capture temporary thoughts, quick numbers, or fleeting ideas here. Delete them when you\'re done to keep this space clean.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.blueGrey.shade100 : Colors.blueGrey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }



  String _getMessageSnippet(QuickNote msg) {
    if (msg.type == 'text') {
      return msg.content ?? 'Message';
    } else if (msg.type == 'voice') {
      return 'Voice note (${msg.durationSeconds ?? 0}s)';
    } else {
      return msg.fileName ?? '${msg.type.toUpperCase()} attachment';
    }
  }



  Widget _buildMessageBubble(QuickNote msg, bool isDark) {
    final isEditing = _editingMessageId == msg.id;
    // Add date to the sticky note header format
    final time = DateFormat('MMM d, h:mm a').format(msg.createdAt.toLocal());
    final wasEdited = msg.updatedAt != null &&
        msg.updatedAt!.isAfter(msg.createdAt.add(const Duration(seconds: 2)));

    Widget content;
    switch (msg.type) {
      case 'image':
        content = _buildImageBubble(msg, isDark);
        break;
      case 'pdf':
        content = _buildPdfBubble(msg, isDark);
        break;
      case 'voice':
        content = _buildVoiceBubble(msg, isDark);
        break;
      default:
        content = isEditing
            ? _buildEditingBubble(msg, isDark)
            : _buildTextBubble(msg, isDark);
    }

    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: kIsWeb
            ? _buildWebMessageWrapper(msg, content, time, wasEdited, isDark)
            : _buildMobileMessageWrapper(msg, content, time, wasEdited, isDark),
      ),
    );
  }

  Widget _buildWebMessageWrapper(
    QuickNote msg,
    Widget content,
    String time,
    bool wasEdited,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildBubbleContainer(msg, content, time, wasEdited, isDark),
        ),
        const SizedBox(width: 4),
        // Ellipsis menu for web
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            size: 18,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            padding: const EdgeInsets.all(4),
          ),
          onSelected: (action) {
            switch (action) {
              case 'edit':
                _startEditing(msg);
                break;
              case 'copy':
                if (msg.content != null) {
                  Clipboard.setData(ClipboardData(text: msg.content!));
                  showSuccessSnackBar(context, 'Copied to clipboard');
                }
                break;
              case 'delete':
                _deleteMessage(msg);
                break;
            }
          },
          itemBuilder: (ctx) => [
            if (msg.type == 'text')
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
            if (msg.type == 'text' && msg.content != null)
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 10),
                    Text('Copy'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileMessageWrapper(
    QuickNote msg,
    Widget content,
    String time,
    bool wasEdited,
    bool isDark,
  ) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showMessageActions(msg);
      },
      child: SizedBox(
        width: double.infinity,
        child: _buildBubbleContainer(msg, content, time, wasEdited, isDark),
      ),
    );
  }

  Widget _buildBubbleContainer(
    QuickNote msg,
    Widget content,
    String time,
    bool wasEdited,
    bool isDark,
  ) {
    // Note sticky colors (Yellow)
    final headerColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
    final bodyColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    final lineColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bodyColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.push_pin, size: 12, color: textColor),
                      ),
                    Text(
                      '$time${wasEdited ? ' (edited)' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                if (!kIsWeb)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _showMessageActions(msg);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
                      child: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: textColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Body with lines
          CustomPaint(
            painter: LinedPaperPainter(lineColor: lineColor),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBubble(QuickNote msg, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        msg.content ?? '',
        style: TextStyle(
          fontSize: 14.5,
          height: 1.3,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEditingBubble(QuickNote msg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _editController,
          autofocus: true,
          maxLines: null,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
              ),
            ),
            contentPadding: const EdgeInsets.all(10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelEdit,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _saveEdit(msg),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageBubble(QuickNote msg, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 350, maxWidth: 350),
        child: GestureDetector(
          onTap: () => _showFullScreenImage(msg),
          child: Image.network(
            msg.mediaUrl ?? '',
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 200,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              );
            },
            errorBuilder: (_, e, s) => Container(
              height: 100,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image,
                size: 40,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(QuickNote msg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(msg.mediaUrl ?? ''),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfBubble(QuickNote msg, bool isDark) {
    return InkWell(
      onTap: () async {
        if (msg.mediaUrl != null) {
          final uri = Uri.parse(msg.mediaUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) showErrorSnackBar(context, 'Could not open PDF');
          }
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.picture_as_pdf,
            color: Colors.red,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.fileName ?? 'Document.pdf',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'PDF Document',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildVoiceBubble(QuickNote msg, bool isDark) {
    if (msg.mediaUrl == null || msg.mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _VoiceNotePlayerWidget(
      mediaUrl: msg.mediaUrl!,
      durationSeconds: msg.durationSeconds ?? 0,
      isDark: isDark,
    );
  }

  Widget _buildInputBar(bool isDark) {
    if (_isRecording) {
      final minutes = _recordingSeconds ~/ 60;
      final seconds = _recordingSeconds % 60;
      final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

      return Container(
        color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F5F7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Cancel recording (red trash icon)
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: 26,
                ),
                onPressed: _cancelRecording,
                tooltip: 'Cancel recording',
              ),
              const SizedBox(width: 8),
              // Pulsing recording red indicator dot + timer
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              // Send recording button
              GestureDetector(
                onTap: _stopAndSendVoiceNote,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10D98C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasText = _messageController.text.trim().isNotEmpty;
    final containerBg = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final iconColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Container(
      color: isDark ? const Color(0xFF0F1115) : const Color(0xFFF5F5F7),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Rounded text input field container (WhatsApp style)
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: containerBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 14),

                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        maxLines: 5,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 15.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a quick note...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                            fontSize: 15.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _sendTextMessage(),
                      ),
                    ),

                    // Paperclip (File / Attachment) button - direct native file picker
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: iconColor,
                        size: 22,
                      ),
                      onPressed: _pickAndSendFile,
                      tooltip: 'Attach File',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),

                    // Camera button - direct native camera
                    IconButton(
                      icon: Icon(
                        Icons.camera_alt,
                        color: iconColor,
                        size: 22,
                      ),
                      onPressed: _pickFromCamera,
                      tooltip: 'Camera',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.only(right: 6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Voice Note / Send button (Green circular button on far right)
            GestureDetector(
              onTap: () {
                if (hasText) {
                  if (!_isSending) _sendTextMessage();
                } else {
                  _startRecording();
                }
              },
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFF10D98C), // WhatsApp / InkSync Green
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasText ? Icons.send : Icons.mic,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Audio Player Widget for Voice Notes
class _VoiceNotePlayerWidget extends StatefulWidget {
  final String mediaUrl;
  final int durationSeconds;
  final bool isDark;

  const _VoiceNotePlayerWidget({
    required this.mediaUrl,
    required this.durationSeconds,
    required this.isDark,
  });

  @override
  State<_VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<_VoiceNotePlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted && dur > Duration.zero) {
        setState(() {
          _duration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.mediaUrl));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isDark ? Colors.white : Colors.black87;
    final totalDur = _duration.inSeconds > 0 ? _duration : Duration(seconds: widget.durationSeconds);

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF10D98C).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: themeColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: themeColor,
                    inactiveTrackColor: themeColor.withValues(alpha: 0.25),
                    thumbColor: themeColor,
                  ),
                  child: Slider(
                    value: _position.inSeconds.toDouble().clamp(
                          0.0,
                          totalDur.inSeconds.toDouble() > 0 ? totalDur.inSeconds.toDouble() : 1.0,
                        ),
                    max: totalDur.inSeconds.toDouble() > 0 ? totalDur.inSeconds.toDouble() : 1.0,
                    onChanged: (val) async {
                      final newPos = Duration(seconds: val.toInt());
                      await _audioPlayer.seek(newPos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: themeColor.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        _formatDuration(totalDur),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: themeColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
