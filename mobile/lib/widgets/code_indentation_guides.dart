import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import '../utils/indentation.dart';

/// Desenha linhas verticais de indentação ("indentation guides") por cima do
/// editor, indicando o início/fim de blocos.
///
/// Como o CodeField 0.3.5 usa um TextField nativo para renderizar o texto,
/// as guias são desenhadas em um CustomPaint sobreposto, alinhadas via métricas
/// do texto (largura do caractere, altura da linha) e offsets de scroll.
class CodeIndentationGuides extends StatefulWidget {
  final CodeController controller;
  final ScrollController horizontalScrollController;

  /// Deslocamento horizontal (em pixels) onde o código começa dentro do
  /// CodeField (padding do container + largura do gutter).
  final double gutterOffset;

  final TextStyle textStyle;
  final Color guideColor;
  final Color activeGuideColor;
  final Widget? child;

  const CodeIndentationGuides({
    super.key,
    required this.controller,
    required this.horizontalScrollController,
    required this.gutterOffset,
    required this.textStyle,
    required this.guideColor,
    required this.activeGuideColor,
    this.child,
  });

  @override
  State<CodeIndentationGuides> createState() => _CodeIndentationGuidesState();
}

class _CodeIndentationGuidesState extends State<CodeIndentationGuides> {
  static const double _topPadding = 16; // contentPadding vertical do TextField

  List<IndentLine> _lines = const [];
  int _indentSize = 4;
  double _verticalOffset = 0;
  double _horizontalOffset = 0;
  double _charWidth = 0;
  double _lineHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.horizontalScrollController.addListener(_onHScroll);
    _measureTextMetrics();
    _onTextChanged();
  }

  @override
  void didUpdateWidget(covariant CodeIndentationGuides oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.horizontalScrollController !=
        widget.horizontalScrollController) {
      oldWidget.horizontalScrollController.removeListener(_onHScroll);
      widget.horizontalScrollController.addListener(_onHScroll);
    }
    if (oldWidget.textStyle != widget.textStyle) {
      _measureTextMetrics();
    }
    _onTextChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.horizontalScrollController.removeListener(_onHScroll);
    super.dispose();
  }

  void _measureTextMetrics() {
    final painter = TextPainter(
      text: TextSpan(text: 'W', style: widget.textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    _charWidth = painter.width;
    _lineHeight = painter.height;
    painter.dispose();
  }

  void _onHScroll() {
    setState(() {
      _horizontalOffset = widget.horizontalScrollController.hasClients
          ? widget.horizontalScrollController.offset
          : 0;
    });
  }

  void _onTextChanged() {
    setState(() {
      _lines = computeLineIndents(widget.controller.text);
      _indentSize = detectIndentSize(_lines);
    });
  }

  int _activeLine() {
    final selection = widget.controller.selection;
    if (!selection.isValid) return -1;
    var line = 0;
    final text = widget.controller.text;
    final end = selection.baseOffset > text.length
        ? text.length
        : selection.baseOffset;
    for (var i = 0; i < end; i++) {
      if (text[i] == '\n') line++;
    }
    return line;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          final offset = notification.metrics.pixels;
          if (offset != _verticalOffset) {
            setState(() => _verticalOffset = offset);
          }
        }
        return false;
      },
      child: Stack(
        children: [
          if (widget.child != null) widget.child!,
          Positioned(
            left: widget.gutterOffset,
            top: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _IndentGuidesPainter(
                  lines: _lines,
                  indentSize: _indentSize,
                  charWidth: _charWidth,
                  lineHeight: _lineHeight,
                  verticalOffset: _verticalOffset,
                  horizontalOffset: _horizontalOffset,
                  topPadding: _topPadding,
                  activeLine: _activeLine(),
                  guideColor: widget.guideColor,
                  activeGuideColor: widget.activeGuideColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndentGuidesPainter extends CustomPainter {
  final List<IndentLine> lines;
  final int indentSize;
  final double charWidth;
  final double lineHeight;
  final double verticalOffset;
  final double horizontalOffset;
  final double topPadding;
  final int activeLine;
  final Color guideColor;
  final Color activeGuideColor;

  _IndentGuidesPainter({
    required this.lines,
    required this.indentSize,
    required this.charWidth,
    required this.lineHeight,
    required this.verticalOffset,
    required this.horizontalOffset,
    required this.topPadding,
    required this.activeLine,
    required this.guideColor,
    required this.activeGuideColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || charWidth <= 0 || lineHeight <= 0) return;
    if (size.width <= 0 || size.height <= 0) return;

    const maxColumns = 24;
    var maxIndent = 0;
    for (final line in lines) {
      if (line.indent > maxIndent) maxIndent = line.indent;
    }
    final maxLevel = maxIndent > maxColumns * indentSize
        ? maxColumns * indentSize
        : maxIndent;

    final activeIndent = activeLine >= 0 && activeLine < lines.length
        ? lines[activeLine].indent
        : 0;

    for (var level = indentSize; level <= maxLevel; level += indentSize) {
      var start = -1;
      for (var i = 0; i < lines.length; i++) {
        final keep =
            lines[i].indent >= level || (start != -1 && lines[i].isBlank);
        if (keep) {
          if (start == -1) start = i;
        } else {
          if (start != -1) {
            _drawColumn(
              canvas,
              size,
              level,
              start,
              i - 1,
              level == activeIndent,
            );
            start = -1;
          }
        }
      }
      if (start != -1) {
        _drawColumn(
          canvas,
          size,
          level,
          start,
          lines.length - 1,
          level == activeIndent,
        );
      }
    }
  }

  void _drawColumn(
    Canvas canvas,
    Size size,
    int level,
    int from,
    int to,
    bool active,
  ) {
    // Quantos caracteres à esquerda da borda da coluna a guia fica.
    // Aumente para empurrar mais para a esquerda (ex.: 1.5, 2.0).
    const double guideInsetChars = 1.5;
    final x =
        (level * charWidth) - (guideInsetChars * charWidth) - horizontalOffset;
    if (x < 0 || x > size.width) return;

    final yTop = topPadding + from * lineHeight - verticalOffset;
    final yBottom = topPadding + (to + 1) * lineHeight - verticalOffset;
    final paint = Paint()
      ..color = active ? activeGuideColor : guideColor
      ..strokeWidth = active ? 1.2 : 1.0
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(x, yTop.clamp(0.0, size.height)),
      Offset(x, yBottom.clamp(0.0, size.height)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IndentGuidesPainter oldDelegate) => true;
}
