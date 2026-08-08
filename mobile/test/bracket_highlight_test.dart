import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:jalide/utils/jalide_code_controller.dart';

void main() {
  const focusFg = Color(0xFF00FFFF);

  List<(int, String, TextStyle?)> flatten(TextSpan? span) {
    final result = <(int, String, TextStyle?)>[];
    void walk(InlineSpan? s, int offset) {
      if (s == null) return;
      if (s is TextSpan) {
        final t = s.text ?? '';
        if (t.isNotEmpty) {
          result.add((offset, t, s.style));
        }
        var childOffset = offset + t.length;
        for (final c in s.children ?? []) {
          if (c is TextSpan) {
            walk(c, childOffset);
            childOffset += c.toPlainText().length;
          }
        }
      }
    }

    walk(span, 0);
    return result;
  }

  TextStyle? styleAt(String text, int index, TextSpan? span) {
    var acc = 0;
    for (final (offset, chunk, style) in flatten(span)) {
      final end = offset + chunk.length;
      if (index >= offset && index < end) return style;
      acc = end;
    }
    return null;
  }

  bool hasFocus(TextStyle? style) =>
      style?.color == focusFg && style?.fontWeight == FontWeight.w900;

  testWidgets('destaque aplicado no par e removido ao sair do cursor', (
    tester,
  ) async {
    final controller = JalideCodeController(
      text: 'void main() {\n  print("hi");\n}',
      language: javascript,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );

    TextSpan? buildSpan() {
      final span = controller.buildTextSpan(
        context: tester.element(find.byType(CodeField)),
        style: const TextStyle(color: Color(0xFFFFFFFF)),
      );
      return span;
    }

    final openIdx = controller.text.indexOf('{');
    final closeIdx = controller.text.lastIndexOf('}');

    controller.selection = TextSelection.collapsed(offset: openIdx + 1);
    var span = buildSpan();

    expect(
      hasFocus(styleAt(controller.text, openIdx, span)),
      isTrue,
      reason: 'abertura deve estar destacada com cursor nela',
    );
    expect(
      hasFocus(styleAt(controller.text, closeIdx, span)),
      isTrue,
      reason: 'fechamento deve estar destacada junto',
    );

    controller.selection = TextSelection.collapsed(offset: 0);
    span = buildSpan();

    expect(
      hasFocus(styleAt(controller.text, openIdx, span)),
      isFalse,
      reason: 'destaque deve sumir ao sair do par',
    );
    expect(
      hasFocus(styleAt(controller.text, closeIdx, span)),
      isFalse,
      reason: 'destaque deve sumir ao sair do par',
    );
  });

  testWidgets('parênteses também são destacados', (tester) async {
    final controller = JalideCodeController(
      text: 'print("hi")',
      language: javascript,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeField(controller: controller)),
      ),
    );

    final openIdx = controller.text.indexOf('(');
    final closeIdx = controller.text.indexOf(')');

    controller.selection = TextSelection.collapsed(offset: closeIdx);
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(CodeField)),
      style: const TextStyle(color: Color(0xFFFFFFFF)),
    );

    expect(hasFocus(styleAt(controller.text, openIdx, span)), isTrue);
    expect(hasFocus(styleAt(controller.text, closeIdx, span)), isTrue);
  });
}
