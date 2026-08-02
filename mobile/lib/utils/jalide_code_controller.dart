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
    backgroundColor: Color(0xFFFF9E3B),
    color: Color(0xFF000000),
    fontWeight: FontWeight.bold,
  );

  JalideCodeController({
    super.text,
    super.language,
    super.patternMap,
  });

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
