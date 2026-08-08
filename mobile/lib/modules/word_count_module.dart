import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'editor_module.dart';
import 'module_context.dart';

/// Exibe contagem de linhas/palavras/caracteres do arquivo ativo na barra de
/// status e fornece um comando de resumo na Command Palette.
class WordCountModule extends EditorModule {
  @override
  String get id => 'wordcount';

  @override
  String get name => 'Word Count';

  @override
  String get description =>
      'Exibe a contagem de linhas, palavras e caracteres do arquivo ativo na barra de status.';

  ModuleContext? _ctx;
  CodeController? _currentController;
  VoidCallback? _onTextChange;

  int _lines = 0;
  int _words = 0;
  int _chars = 0;

  int get lines => _lines;
  int get words => _words;
  int get chars => _chars;

  @override
  void init(ModuleContext ctx) {
    _ctx = ctx;
    ctx.tabController.addListener(_onTabChanged);
    _attach();
    _refresh();
  }

  @override
  void dispose() {
    if (_currentController != null && _onTextChange != null) {
      _currentController!.removeListener(_onTextChange!);
    }
    _ctx?.tabController.removeListener(_onTabChanged);
    _currentController = null;
    _onTextChange = null;
    _ctx = null;
  }

  void _onTabChanged() {
    _attach();
    _refresh();
  }

  void _attach() {
    final controller = _ctx?.activeController;
    if (controller == _currentController) return;
    if (_currentController != null && _onTextChange != null) {
      _currentController!.removeListener(_onTextChange!);
    }
    _currentController = controller;
    _onTextChange = _refresh;
    _currentController?.addListener(_onTextChange!);
  }

  void _refresh() {
    final text = _ctx?.activeController?.text ?? '';
    _chars = text.length;
    _lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    _words = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    _ctx?.setState(() {});
  }

  @override
  List<ModuleCommand> get commands => [
        ModuleCommand(
          label: 'Word Count: Ver contagem',
          icon: Icons.numbers_rounded,
          category: 'Editor',
          onTap: () {
            _refresh();
            _ctx?.showToast(
              '$_lines linhas · $_words palavras · $_chars caracteres',
            );
          },
        ),
      ];

  @override
  List<Widget> get statusBarItems {
    final theme = _ctx?.theme;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          '$_lines ln · $_words wd',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: theme?.textMuted ?? Colors.grey,
          ),
        ),
      ),
    ];
  }
}
