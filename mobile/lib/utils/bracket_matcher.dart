import 'package:flutter/widgets.dart';

class MatchResult {
  final int openIndex;
  final int closeIndex;
  final String openChar;
  final String closeChar;
  final int openColumn;
  final int closeColumn;

  MatchResult({
    required this.openIndex,
    required this.closeIndex,
    required this.openChar,
    required this.closeChar,
    required this.openColumn,
    required this.closeColumn,
  });
}

class BracketMatcher {
  static final Map<String, String> _pairs = {
    '{': '}',
    '(': ')',
    '[': ']',
    '}': '{',
    ')': '(',
    ']': '[',
  };

  static final Set<String> _openers = {'{', '(', '['};

  static int _getColumn(String text, int offset) {
    int col = 0;
    for (int i = 0; i < offset && i < text.length; i++) {
      if (text[i] == '\n') {
        col = 0;
      } else {
        col++;
      }
    }
    return col;
  }

  /// Procura a posição da chave/parêntese/colchete correspondente no texto.
  /// Retorna [MatchResult] com os índices de abertura e fechamento se encontrar.
  static MatchResult? findMatchingPair(String text, int cursorOffset) {
    if (text.isEmpty || cursorOffset < 0 || cursorOffset > text.length) {
      return null;
    }

    int targetPos = -1;
    String? targetChar;

    if (cursorOffset > 0 && _pairs.containsKey(text[cursorOffset - 1])) {
      targetPos = cursorOffset - 1;
      targetChar = text[targetPos];
    } else if (cursorOffset < text.length && _pairs.containsKey(text[cursorOffset])) {
      targetPos = cursorOffset;
      targetChar = text[targetPos];
    }

    if (targetPos == -1 || targetChar == null) {
      return null;
    }

    final isOpener = _openers.contains(targetChar);
    final partnerChar = _pairs[targetChar]!;

    int depth = 0;
    if (isOpener) {
      for (int i = targetPos; i < text.length; i++) {
        final ch = text[i];
        if (ch == targetChar) {
          depth++;
        } else if (ch == partnerChar) {
          depth--;
          if (depth == 0) {
            return MatchResult(
              openIndex: targetPos,
              closeIndex: i,
              openChar: targetChar,
              closeChar: partnerChar,
              openColumn: _getColumn(text, targetPos),
              closeColumn: _getColumn(text, i),
            );
          }
        }
      }
    } else {
      for (int i = targetPos; i >= 0; i--) {
        final ch = text[i];
        if (ch == targetChar) {
          depth++;
        } else if (ch == partnerChar) {
          depth--;
          if (depth == 0) {
            return MatchResult(
              openIndex: i,
              closeIndex: targetPos,
              openChar: partnerChar,
              closeChar: targetChar,
              openColumn: _getColumn(text, i),
              closeColumn: _getColumn(text, targetPos),
            );
          }
        }
      }
    }

    return null;
  }
}

/// Aplica cores nos colchetes/chaves/parênteses do span renderizado e, quando
/// [openIndex]/[closeIndex] são válidos, aplica o [focusStyle] (destaque) no par.
///
/// Importante: o flutter_code_editor 0.3.5 NÃO renderiza `patternMap`
/// (o regex/style é montado no construtor e nunca aplicado ao TextSpan).
/// Por isso o destaque precisa ser aplicado sobre o span retornado por
/// `CodeController.buildTextSpan`.
TextSpan applyBracketHighlighting({
  required TextSpan? root,
  required String text,
  required int openIndex,
  required int closeIndex,
  required Map<String, Color> bracketColors,
  required TextStyle focusStyle,
}) {
  if (root == null) return const TextSpan();
  return _applyBracketHighlighting(
    root,
    text,
    openIndex,
    closeIndex,
    bracketColors,
    focusStyle,
    0,
  );
}

TextSpan _applyBracketHighlighting(
  TextSpan span,
  String text,
  int openIndex,
  int closeIndex,
  Map<String, Color> colors,
  TextStyle focusStyle,
  int offset,
) {
  final rawText = span.text;
  final children = span.children;

  if (rawText != null && rawText.isNotEmpty) {
    final segStart = offset;
    final segEnd = offset + rawText.length;

    final builder = <InlineSpan>[];
    final buffer = StringBuffer();
    TextStyle? current;

    void flush() {
      if (buffer.isEmpty) return;
      builder.add(TextSpan(text: buffer.toString(), style: current));
      buffer.clear();
    }

    for (var i = 0; i < rawText.length; i++) {
      final abs = segStart + i;
      var effective = span.style;
      final color = colors[rawText[i]];
      if (color != null) {
        effective = (effective ?? const TextStyle()).copyWith(color: color);
      }
      if (abs == openIndex || abs == closeIndex) {
        effective = (effective ?? const TextStyle()).merge(focusStyle);
      }
      if (effective != current) {
        flush();
        current = effective;
      }
      buffer.write(rawText[i]);
    }
    flush();

    if (children != null) {
      for (final child in children) {
        if (child is TextSpan) {
          builder.add(_applyBracketHighlighting(
            child,
            text,
            openIndex,
            closeIndex,
            colors,
            focusStyle,
            segEnd,
          ));
        } else {
          builder.add(child);
        }
      }
    }

    return TextSpan(text: null, style: span.style, children: builder);
  }

  if (children != null) {
    final builder = <InlineSpan>[];
    var childOffset = offset;
    for (final child in children) {
      if (child is TextSpan) {
        builder.add(_applyBracketHighlighting(
          child,
          text,
          openIndex,
          closeIndex,
          colors,
          focusStyle,
          childOffset,
        ));
        childOffset += child.toPlainText().length;
      } else {
        builder.add(child);
      }
    }
    return TextSpan(text: null, style: span.style, children: builder);
  }

  return span;
}
