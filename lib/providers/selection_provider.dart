import 'package:flutter/material.dart';
import '../services/notes_service.dart';

class SelectionProvider with ChangeNotifier {
  Note? _selectedNote;
  String? _selectedFolderId;
  int _currentScreenIndex = 0;
  String? _pendingSearchQuery;

  Note? get selectedNote => _selectedNote;
  String? get selectedFolderId => _selectedFolderId;
  int get currentScreenIndex => _currentScreenIndex;
  String? get pendingSearchQuery => _pendingSearchQuery;

  void selectNote(Note? note, {String? searchQuery}) {
    _selectedNote = note;
    _pendingSearchQuery = searchQuery;
    notifyListeners();
  }

  void selectFolder(String? folderId) {
    _selectedFolderId = folderId;
    notifyListeners();
  }

  void setScreenIndex(int index) {
    _currentScreenIndex = index;
    // Clear selected note when switching screens if needed
    if (index != 0) _selectedNote = null;
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedNote = null;
    notifyListeners();
  }
}
