import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = await file.readAsString();
    if (!content.contains('_theme')) continue;
    
    // Split into lines
    final lines = content.split('\n');
    bool changed = false;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('_theme') && lines[i].contains('const ')) {
        lines[i] = lines[i].replaceAll('const ', '');
        changed = true;
      }
      // sometimes 'const ' is on a previous line. E.g.
      // const Text(
      //   'Hello',
      //   style: TextStyle(color: _theme.textPri),
      // )
      // But this is harder to fix line-by-line.
    }
    
    if (changed) {
      await file.writeAsString(lines.join('\n'));
    }
  }
}
