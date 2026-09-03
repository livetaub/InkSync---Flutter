import 'package:flutter/material.dart';
import '../services/notes_service.dart';

class SelectionProvider with ChangeNotifier {
  Note? _selectedNote;
  String? _selectedFolderId;
  int _currentScreenIndex = 0;
  String? _pendingSearchQuery;
  bool _isQuickNoteSelected = false;

  Note? get selectedNote => _selectedNote;
  String? get selectedFolderId => _selectedFolderId;
  int get currentScreenIndex => _currentScreenIndex;
  String? get pendingSearchQuery => _pendingSearchQuery;
  bool get isQuickNoteSelected => _isQuickNoteSelected;

  void selectNote(Note? note, {String? searchQuery}) {
    _selectedNote = note;
    _pendingSearchQuery = searchQuery;
    _isQuickNoteSelected = false;
    notifyListeners();
  }

  void selectQuickNote() {
    _selectedNote = null;
    _pendingSearchQuery = null;
    _isQuickNoteSelected = true;
    notifyListeners();
  }

  void selectFolder(String? folderId) {
    _selectedFolderId = folderId;
    notifyListeners();
  }

  void setScreenIndex(int index) {
    _currentScreenIndex = index;
    // Clear selected note when switching screens
    _selectedNote = null;
    _isQuickNoteSelected = false;
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedNote = null;
    _isQuickNoteSelected = false;
    notifyListeners();
  }
}
