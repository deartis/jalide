import 'dart:io';

void main() async {
  final res = await Process.run('flutter.bat', ['analyze']);
  final lines = res.stdout.toString().split('\n');
  
  for (final line in lines) {
    if (line.contains('invalid_constant')) {
      final parts = line.split('-');
      if (parts.length < 3) continue;
      
      final locationPart = parts[parts.length - 2].trim();
      final locParts = locationPart.split(':');
      if (locParts.length < 3) continue;
      
      final path = locParts[0].trim();
      final lineNum = int.tryParse(locParts[1]);
      if (lineNum == null) continue;
      
      final file = File(path);
      if (!await file.exists()) continue;
      
      final fileLines = await file.readAsLines();
      
      for (int j = lineNum - 1; j >= 0 && j >= lineNum - 6; j--) {
        if (fileLines[j].contains('const ')) {
          fileLines[j] = fileLines[j].replaceAll('const ', '');
          break;
        }
      }
      
      await file.writeAsString(fileLines.join('\n'));
    }
  }
}
