import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';

/// Settings Provider - shares settings state across screens
class SettingsProvider extends ChangeNotifier {
  String _viewMode = 'list';
  String _sortBy = 'modified';
  bool _isPremium = false;
  bool _showBrainDump = true;
  
  String get viewMode => _viewMode;
  String get sortBy => _sortBy;
  bool get isPremium => _isPremium;
  bool get showBrainDump => _showBrainDump;
  
  void setViewMode(String mode) {
    _viewMode = mode;
    notifyListeners();
  }
  
  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }
  
  void setPremium(bool value) {
    _isPremium = value;
    notifyListeners();
  }
  
  /// Load settings from service
  Future<void> loadSettings(AuthService authService) async {
    try {
      final settingsService = SettingsService(authService);
      final settings = await settingsService.getSettings();

      // Only accept valid values; keep defaults if Supabase returns garbage
      const validViewModes = ['list', 'details', 'grid'];
      const validSortOptions = ['modified', 'created', 'alphabetical', 'color', 'reminder'];

      _viewMode = validViewModes.contains(settings.viewMode)
          ? settings.viewMode
          : 'list';
      _sortBy = validSortOptions.contains(settings.sortBy)
          ? settings.sortBy
          : 'modified';
      _isPremium = settings.isPremium;
      _showBrainDump = settings.showBrainDump;
      notifyListeners();
    } catch (e) {
      // Use defaults
    }
  }
  
  /// Save a setting
  Future<void> saveSetting(AuthService authService, String key, dynamic value) async {
    // Update local state FIRST for immediate UI feedback
    switch (key) {
      case 'viewMode':
        _viewMode = value as String;
        break;
      case 'sortBy':
        _sortBy = value as String;
        break;
      case 'isPremium':
        _isPremium = value as bool;
        break;
      case 'showBrainDump':
        _showBrainDump = value as bool;
        break;
    }
    notifyListeners();

    // Then persist to Supabase in the background
    try {
      final settingsService = SettingsService(authService);
      await settingsService.updateSetting(key, value);
    } catch (e) {
      // Remote save failed, but local state is already updated
      debugPrint('Settings save to Supabase failed: $e');
    }
  }
}
