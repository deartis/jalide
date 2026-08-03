import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/utils/indentation.dart';

void main() {
  test('computeLineIndents conta espacos e tabs', () {
    const text = 'function a() {\n'
        '  const x = 1;\n'
        '    const y = 2;\n'
        '\tconst z = 3;\n'
        '}\n';
    final lines = computeLineIndents(text);
    expect(lines.length, 6);
    expect(lines[0].indent, 0);
    expect(lines[1].indent, 2);
    expect(lines[2].indent, 4);
    expect(lines[3].indent, 4);
    expect(lines[4].indent, 0);
    expect(lines[5].indent, 0);
    expect(lines[5].isBlank, isTrue);
    expect(lines[0].isBlank, isFalse);
  });

  test('computeLineIndents marca linhas vazias como blank', () {
    const text = '  \n\t\nabc';
    final lines = computeLineIndents(text);
    expect(lines[0].isBlank, isTrue);
    expect(lines[1].isBlank, isTrue);
    expect(lines[2].isBlank, isFalse);
    expect(lines[2].indent, 0);
  });

  test('detectIndentSize retorna a indentacao predominante', () {
    expect(detectIndentSize(computeLineIndents('a\n  b\n  c\n  d')), 2);
    expect(detectIndentSize(computeLineIndents('a\n    b\n    c')), 4);
    expect(detectIndentSize(computeLineIndents('a\nb')), 4);
    expect(detectIndentSize(computeLineIndents('')), 4);
  });

  test('computeLineIndents trata texto vazio', () {
    final lines = computeLineIndents('');
    expect(lines.length, 1);
    expect(lines[0].indent, 0);
    expect(lines[0].isBlank, isTrue);
  });
}
