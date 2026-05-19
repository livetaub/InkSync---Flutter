import 'dart:io';

void main() {
  var file = File('lib/screens/note_edit/note_edit_screen.dart');
  var lines = file.readAsLinesSync();
  int count = 0;
  bool inString = false;
  bool inComment = false;
  
  for (int i = 0; i < lines.length; i++) {
    var line = lines[i];
    inComment = false;
    
    for (int j = 0; j < line.length; j++) {
      if (inString) {
        if (line[j] == "'" && (j == 0 || line[j-1] != '\\')) {
          inString = false;
        }
      } else if (inComment) {
        continue;
      } else {
        if (j + 1 < line.length && line[j] == '/' && line[j+1] == '/') {
          inComment = true;
          break;
        }
        if (line[j] == "'") {
          inString = true;
        }
        if (line[j] == '{') count++;
        if (line[j] == '}') count--;
      }
    }
    if (line.contains('Widget _') || line.contains('void _') || line.contains('Future<void> _')) {
      print('Line ' + (i + 1).toString() + ' (depth ' + count.toString() + '): ' + line.trim());
    }
  }
}
