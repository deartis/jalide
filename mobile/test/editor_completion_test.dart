import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:jalide/utils/code_completion.dart';

void main() {
  test('Sugestoes customizadas de JavaScript e Dart sao carregadas', () async {
    final jsController = CodeController(language: javascript);
    applyLanguageSuggestions(jsController, 'JS');

    expect(
      await jsController.autocompleter.getSuggestions('con'),
      contains('console'),
    );

    final dartController = CodeController(language: null);
    applyLanguageSuggestions(dartController, 'Dart');

    expect(
      await dartController.autocompleter.getSuggestions('set'),
      contains('setState'),
    );
    expect(
      await dartController.autocompleter.getSuggestions('bui'),
      contains('build'),
    );
  });
}
