import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/auth_service.dart';
import '../../services/tag_service.dart';
import '../../config/theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_header.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDialog;
  final VoidCallback? onSync;

  const SettingsScreen({super.key, this.isDialog = false, this.onSync});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsService _settingsService;
  UserSettings _settings = UserSettings();
  bool _isLoading = true;
  String _currentView =
      'main'; // 'main', 'view', 'sort', 'noteTags', 'checklistTags'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initService();
    });
  }

  void _initService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _settingsService = SettingsService(authService);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    // Update provider for immediate UI update (no page reload)
    await settingsProvider.saveSetting(authService, key, value);

    // Trigger resync to apply new settings
    widget.onSync?.call();
  }

  void _navigateTo(String view) {
    setState(() => _currentView = view);
  }

  void _goBack() {
    setState(() => _currentView = 'main');
  }

  String _getTitle() {
    switch (_currentView) {
      case 'view':
        return 'View';
      case 'sort':
        return 'Sort by';
      case 'noteTags':
        return 'Note Tags';
      case 'checklistTags':
        return 'Checklist Tags';
      default:
        return 'Settings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final content = Column(
      children: [
        // Header
        if (widget.isDialog)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                if (_currentView != 'main')
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _goBack,
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    _getTitle(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        if (widget.isDialog) const Divider(height: 1),

        // Content based on current view
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildCurrentView(),
          ),
        ),
      ],
    );

    // For dialog mode, just return the content directly
    if (widget.isDialog) {
      return content;
    }

    // For full-screen mode, wrap in Scaffold with SimpleAppBar
    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
      appBar: SimpleAppBar(
        title: _getTitle(),
        leading: _currentView != 'main'
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                onPressed: _goBack,
              )
            : null,
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case 'view':
        return _buildViewOptions();
      case 'sort':
        return _buildSortOptions();
      case 'noteTags':
        return _buildnoteTagsView();
      case 'checklistTags':
        return _buildchecklistTagsView();
      default:
        return _buildMainView();
    }
  }

  Widget _buildMainView() {
    return ListView(
      key: const ValueKey('main'),
      children: [
        // Display Section
        _buildSectionHeader('Display'),
        _buildListTile(
          icon: Icons.view_list_outlined,
          title: 'View',
          subtitle: _getViewModeLabel(
            Provider.of<SettingsProvider>(context).viewMode,
          ),
          onTap: () => _navigateTo('view'),
        ),
        _buildListTile(
          icon: Icons.sort,
          title: 'Sort by',
          subtitle: _getSortByLabel(
            Provider.of<SettingsProvider>(context).sortBy,
          ),
          onTap: () => _navigateTo('sort'),
        ),

        const Divider(height: 24),

        // Tags Section
        _buildSectionHeader('Tags'),
        _buildListTile(
          icon: Icons.label_outline,
          title: 'Manage Note Tags',
          subtitle: 'Reorder, rename, or delete tags',
          onTap: () => _navigateTo('noteTags'),
        ),
        _buildListTile(
          icon: Icons.checklist_rounded,
          title: 'Manage Checklist Tags',
          subtitle: 'Reorder, rename, or delete tags',
          onTap: () => _navigateTo('checklistTags'),
        ),

        const Divider(height: 24),

        // Appearance Section
        _buildSectionHeader('Appearance'),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text('Dark mode'),
          value: Theme.of(context).brightness == Brightness.dark,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            final themeProvider = Provider.of<ThemeProvider>(
              context,
              listen: false,
            );
            themeProvider.setThemeMode(
              value ? ThemeMode.dark : ThemeMode.light,
            );
          },
        ),

        const Divider(height: 24),

        // Notifications Section
        _buildSectionHeader('Notifications'),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Push notifications'),
          subtitle: const Text('Get notified about reminders'),
          value: _settings.notificationsEnabled,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            _updateSetting('notificationsEnabled', value);
          },
        ),
        const Divider(height: 24),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildViewOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final options = [
      {'id': 'list', 'label': 'List', 'icon': Icons.view_list_rounded},
      {'id': 'details', 'label': 'Details', 'icon': Icons.view_agenda_rounded},
      {'id': 'grid', 'label': 'Grid', 'icon': Icons.apps_rounded},
    ];

    return ListView(
      key: const ValueKey('view'),
      children: options
          .map(
            (option) {
              final isSelected = settingsProvider.viewMode == option['id'];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    option['icon'] as IconData,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isDark ? Colors.white54 : AppTheme.textSecondary),
                  ),
                  title: Text(
                    option['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isDark ? Colors.white : AppTheme.textPrimary),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    _updateSetting('viewMode', option['id']);
                  },
                ),
              );
            },
          )
          .toList(),
    );
  }

  Widget _buildSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final options = [
      {
        'id': 'modified',
        'label': 'Modified time',
        'icon': Icons.access_time_rounded,
      },
      {
        'id': 'created',
        'label': 'Created time',
        'icon': Icons.calendar_today_rounded,
      },
      {
        'id': 'alphabetical',
        'label': 'Alphabetically',
        'icon': Icons.sort_by_alpha_rounded,
      },
      {'id': 'color', 'label': 'By color', 'icon': Icons.palette_outlined},
      {
        'id': 'reminder',
        'label': 'Reminder time',
        'icon': Icons.notifications_outlined,
      },
    ];

    return ListView(
      key: const ValueKey('sort'),
      children: options
          .map(
            (option) {
              final isSelected = settingsProvider.sortBy == option['id'];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    option['icon'] as IconData,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isDark ? Colors.white54 : AppTheme.textSecondary),
                  ),
                  title: Text(
                    option['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isDark ? Colors.white : AppTheme.textPrimary),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    _updateSetting('sortBy', option['id']);
                  },
                ),
              );
            },
          )
          .toList(),
    );
  }

  Widget _buildnoteTagsView() {
    return _buildTagsView('text');
  }

  Widget _buildchecklistTagsView() {
    return _buildTagsView('checklist');
  }

  /// Migrate Tags without type and then fetch by type
  Future<List<Tag>> _migrateAndGetTags(
    TagService tagService,
    String type,
  ) async {
    return tagService.getTagsByType(type);
  }

  Widget _buildTagsView(String type) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tagService = TagService(authService);

    // Run migration first, then get Tags
    return FutureBuilder<List<Tag>>(
      future: _migrateAndGetTags(tagService, type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final tags = snapshot.data ?? [];

        return Column(
          key: ValueKey('${type}Tags'),
          children: [
            Expanded(
              child: tags.isEmpty
                  ? Center(
                      child: Text(
                        'No Tags yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: tags.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final reorderedTags = List<Tag>.from(tags);
                        final item = reorderedTags.removeAt(oldIndex);
                        reorderedTags.insert(newIndex, item);
                        await tagService.reorderTags(reorderedTags);
                        setState(() {}); // Trigger rebuild
                      },
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        return ListTile(
                          key: ValueKey(tag.id),
                          leading: const Icon(
                            Icons.label_outline,
                            color: AppTheme.primaryColor,
                          ),
                          title: Text(tag.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showEditTagDialog(
                                  tag,
                                  tagService,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red.shade400,
                                ),
                                onPressed: () => _showDeleteTagDialog(
                                  tag,
                                  tagService,
                                ),
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              title: const Text(
                'Add Tag',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
              onTap: () => _showAddTagDialog(type, tagService),
            ),
          ],
        );
      },
    );
  }

  void _showAddTagDialog(String type, TagService tagService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${type == 'text' ? 'Note' : 'Checklist'} Tag'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Tag name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await tagService.createTag(
                  controller.text.trim(),
                  type: type,
                );
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  widget.onSync?.call();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTagDialog(Tag tag, TagService tagService) {
    final controller = TextEditingController(text: tag.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tag'),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Tag name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await tagService.updateTag(
                  tag.id!,
                  name: controller.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  widget.onSync?.call();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTagDialog(Tag tag, TagService tagService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: SizedBox(
          width: 380,
          child: Text(
            'Are you sure you want to delete "${tag.name}"?\n\nNotes with this Tag will just lose the tag.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await tagService.deleteTag(tag.id!);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                widget.onSync?.call();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppTheme.textSecondary),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  String _getViewModeLabel(String mode) {
    switch (mode) {
      case 'list':
        return 'List';
      case 'grid':
        return 'Grid';
      case 'details':
        return 'Details';
      default:
        return 'List';
    }
  }

  String _getSortByLabel(String sortBy) {
    switch (sortBy) {
      case 'modified':
        return 'Modified time';
      case 'created':
        return 'Created time';
      case 'alphabetical':
        return 'Alphabetically';
      case 'color':
        return 'By color';
      case 'reminder':
        return 'Reminder time';
      default:
        return 'Modified time';
    }
  }
}
