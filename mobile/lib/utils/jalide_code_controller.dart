import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'bracket_matcher.dart';

/// Controller que aplica o destaque dinâmico do par de colchetes/chaves/
/// parênteses com base na posição do cursor, sobre o span renderizado.
class JalideCodeController extends CodeController {
  static const Map<String, Color> _bracketColors = {
    '{': Color(0xFFFF9E3B),
    '}': Color(0xFFFF9E3B),
    '(': Color(0xFF7AA2F7),
    ')': Color(0xFF7AA2F7),
    '[': Color(0xFFBB9AF7),
    ']': Color(0xFFBB9AF7),
  };

  static const TextStyle _focusStyle = TextStyle(
    color: Color(0xFF00FFFF),
    backgroundColor: Color(0x3D00FFFF), // Fundo neon ciano translúcido (24% de opacidade) - sem laranja
    fontWeight: FontWeight.w900,
    shadows: [
      Shadow(color: Color(0xFF00FFFF), blurRadius: 3),
      Shadow(color: Color(0xFF00FFFF), blurRadius: 8),
      Shadow(color: Color(0xFF00E5FF), blurRadius: 16),
    ],
  );

  JalideCodeController({super.text, super.language, super.patternMap});

  /// Instrumentação temporária p/ caçar o bug de caractere removido no save.
  /// Remove junto com os logs JALIDE_VALUE_CHANGE após o diagnóstico.
  static const bool _debugValueChanges = true;

  @override
  set value(TextEditingValue newValue) {
    if (_debugValueChanges && newValue.text != value.text) {
      final oldText = value.text;
      final oldSel = value.selection;
      final newSel = newValue.selection;
      final newLen = newValue.text.length;
      final removed = oldText.length - newLen;
      final insertLen = newLen - oldText.length;
      final cursor = newSel.isValid ? newSel.baseOffset : -1;
      final oldCursor = oldSel.isValid ? oldSel.baseOffset : -1;

      String changedRegion(String a, int from) {
        final start = from - 15 < 0 ? 0 : from - 15;
        final end = (from + 15) > a.length ? a.length : (from + 15);
        return a.substring(start, end);
      }

      final newText = newValue.text;
      var p = 0;
      final commonLen = oldText.length < newText.length
          ? oldText.length
          : newText.length;
      while (p < commonLen && oldText[p] == newText[p]) {
        p++;
      }
      var s = 0;
      while (s < commonLen - p &&
          oldText[oldText.length - 1 - s] == newText[newText.length - 1 - s]) {
        s++;
      }
      final removedSlice = oldText.substring(p, oldText.length - s);
      final insertedSlice = newText.substring(p, newText.length - s);
      String esc(String x) => x.replaceAll('\n', r'\n').replaceAll('\t', r'\t');

      debugPrint(
        'JALIDE_VALUE_CHANGE oldLen=${oldText.length} newLen=$newLen '
        'insert=$insertLen removed=$removed '
        'oldCursor=$oldCursor newCursor=$cursor '
        'diff@$p removed="${esc(removedSlice)}" inserted="${esc(insertedSlice)}" '
        'before="...${changedRegion(oldText, cursor)}..." '
        'after="...${changedRegion(newText, cursor)}..."',
      );
      final trace = StackTrace.current.toString().split('\n');
      final relevant = trace
          .where((l) => !l.contains('jalide_code_controller.dart'))
          .take(16)
          .join('\n');
      debugPrint('JALIDE_VALUE_CHANGE stack:\n$relevant');
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    final base = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );

    final match = BracketMatcher.findMatchingPair(text, selection.baseOffset);

    return applyBracketHighlighting(
      root: base,
      text: text,
      openIndex: match?.openIndex ?? -1,
      closeIndex: match?.closeIndex ?? -1,
      bracketColors: _bracketColors,
      focusStyle: _focusStyle,
    );
  }
}
