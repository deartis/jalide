import 'dart:io';

void main() async {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('jalide_theme.dart') ||
        file.path.contains('main.dart'))
      continue;

    var content = await file.readAsString();
    if (!content.contains('JalideTheme.')) continue;

    // file_utils.dart
    if (file.path.contains('file_utils.dart')) {
      content = content.replaceAll(
        'static Color colorForFile(String name) {',
        'static Color colorForFile(String name, {required JalideThemeVariant theme}) {',
      );
      content = content.replaceAll('JalideTheme.', 'theme.');
      await file.writeAsString(content);
      continue;
    }

    content = content.replaceAll('JalideTheme.', '_theme.');

    // Inject getter for stateful widgets
    final stateMatch = RegExp(
      r'class\s+_[a-zA-Z0-9_]+State\s+extends\s+State<[^>]+>\s*\{',
    ).firstMatch(content);
    if (stateMatch != null) {
      final matchStr = stateMatch.group(0)!;
      content = content.replaceFirst(
        matchStr,
        '$matchStr\n  JalideThemeVariant get _theme => ThemeProvider.of(context).current;',
      );
    } else {
      // For stateless widgets
      if (content.contains('extends StatelessWidget')) {
        content = content.replaceAll(
          'Widget build(BuildContext context) {',
          'Widget build(BuildContext context) {\n    final _theme = ThemeProvider.of(context).current;',
        );
      }
    }

    await file.writeAsString(content);
    print('Updated \${file.path}');
  }
}
