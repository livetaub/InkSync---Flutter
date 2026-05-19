import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/debug_config.dart';

/// Debug Service - Singleton for logging errors
class DebugService extends ChangeNotifier {
  static final DebugService _instance = DebugService._();
  static DebugService get instance => _instance;

  DebugService._();

  final List<String> _logs = [];
  bool _isExpanded = false;
  bool _notifyScheduled = false;

  bool get isDebugMode => debugMode;
  List<String> get logs => List.unmodifiable(_logs);
  bool get isExpanded => _isExpanded;

  /// Initialize and set up error handling
  Future<void> init() async {
    if (debugMode) {
      FlutterError.onError = (FlutterErrorDetails details) {
        log('[ERROR] ${details.exceptionAsString()}');
        FlutterError.dumpErrorToConsole(details);
      };
      log('[INFO] Debug mode enabled');
    }
  }

  /// Log a message with timestamp
  void log(String message) {
    final timestamp = DateTime.now();
    final formatted =
        '[${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}] $message';
    _logs.add(formatted);

    // Keep max 200 entries
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }

    // Schedule notification for next frame to avoid setState during build
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Toggle expanded state
  void toggleExpanded() {
    _isExpanded = !_isExpanded;
    notifyListeners();
  }

  /// Collapse panel
  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    log('[INFO] Logs cleared');
  }

  /// Get all logs as string for copying
  String getLogsAsText() {
    return _logs.join('\n');
  }
}

/// Debug Panel Widget - Shows at bottom of screen when debug mode is on
class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!debugMode) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: DebugService.instance,
      builder: (context, _) {
        final service = DebugService.instance;

        if (service.isExpanded) {
          return _buildExpandedPanel(context, service);
        } else {
          return _buildCollapsedBar(context, service);
        }
      },
    );
  }

  Widget _buildCollapsedBar(BuildContext context, DebugService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          top: BorderSide(color: Colors.orange.shade700, width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: Colors.orange.shade400, size: 18),
          const SizedBox(width: 8),
          Text(
            'DEBUG',
            style: TextStyle(
              color: Colors.orange.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              service.logs.isNotEmpty ? service.logs.last : 'No logs',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${service.logs.length}',
            style: TextStyle(color: Colors.orange.shade300, fontSize: 11),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => service.toggleExpanded(),
            child: const Icon(
              Icons.expand_less,
              color: Colors.white54,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedPanel(BuildContext context, DebugService service) {
    final scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          top: BorderSide(color: Colors.orange.shade700, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade800),
            child: Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange.shade400, size: 18),
                const SizedBox(width: 8),
                Text(
                  'DEBUG LOG',
                  style: TextStyle(
                    color: Colors.orange.shade400,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${service.logs.length} entries)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
                // Copy button
                _ActionButton(
                  icon: Icons.copy,
                  label: 'Copy',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: service.getLogsAsText()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logs copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Clear button
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Clear',
                  onTap: () => service.clearLogs(),
                ),
                const SizedBox(width: 8),
                // Collapse button
                GestureDetector(
                  onTap: () => service.collapse(),
                  child: const Icon(
                    Icons.expand_more,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          // Log content
          Expanded(
            child: service.logs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: service.logs.length,
                    itemBuilder: (context, index) {
                      final log = service.logs[index];
                      Color color = Colors.white70;
                      if (log.contains('[ERROR]')) {
                        color = Colors.red.shade300;
                      } else if (log.contains('[WARN]')) {
                        color = Colors.orange.shade300;
                      } else if (log.contains('[INFO]')) {
                        color = Colors.blue.shade300;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper widget that adds debug panel to bottom of any screen
class DebugWrapper extends StatelessWidget {
  final Widget child;

  const DebugWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!debugMode) return child;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = Supabase.instance.client.auth.currentUser;
        final isAdmin = user?.email == 'livetaub@gmail.com';

        if (!isAdmin) return child;

        return Column(
          children: [
            Expanded(child: child),
            const DebugPanel(),
          ],
        );
      },
    );
  }
}
