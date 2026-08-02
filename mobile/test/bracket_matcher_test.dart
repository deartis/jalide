import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/utils/bracket_matcher.dart';

void main() {
  test('Encontra par correspondente de chaves {}', () {
    const code = 'function test() { const a = 1; }';
    // { está na posição 16
    final match = BracketMatcher.findMatchingPair(code, 17);
    expect(match, isNotNull);
    expect(match!.openIndex, 16);
    expect(match.closeIndex, code.length - 1);
  });

  test('Encontra par correspondente de chaves fechando }', () {
    const code = 'void main() { print("hi"); }';
    final closePos = code.lastIndexOf('}');
    final match = BracketMatcher.findMatchingPair(code, closePos + 1);
    expect(match, isNotNull);
    expect(match!.openIndex, code.indexOf('{'));
    expect(match.closeIndex, closePos);
  });

  test('Gerador de Regex encontra exatamente a chave de abertura e fechamento pelos colunas', () {
    const code = 'void main() {\n  print("hi");\n}';
    final match = BracketMatcher.findMatchingPair(code, 13);
    expect(match, isNotNull);
    expect(match!.openColumn, 12);
    expect(match.closeColumn, 0);

    final openEsc = RegExp.escape(match.openChar);
    final closeEsc = RegExp.escape(match.closeChar);
    final regex = RegExp('(?<=^.{${match.openColumn}})$openEsc|(?<=^.{${match.closeColumn}})$closeEsc', multiLine: true);

    final lines = code.split('\n');
    expect(regex.hasMatch(lines[0]), isTrue);
    expect(regex.hasMatch(lines[2]), isTrue);
  });
}
