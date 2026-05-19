import 'dart:io';

void main() {
  var file = File('lib/screens/note_edit/note_edit_screen.dart');
  var lines = file.readAsLinesSync();
  int count = 1;
  for (int i = 37; i < lines.length; i++) {
    var line = lines[i];
    
    // Ignore simple single-line strings that might have braces
    // (A full parser is better but this works for basic checks)
    for (int j = 0; j < line.length; j++) {
      if (line[j] == '{') count++;
      if (line[j] == '}') count--;
    }
    if (count <= 0 && i > 30) {
      print('Class closed prematurely at line ${i + 1}');
      print('Line content: $line');
      return;
    }
  }
}
