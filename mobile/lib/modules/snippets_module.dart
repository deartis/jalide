import 'package:flutter/material.dart';
import 'editor_module.dart';
import 'module_context.dart';

class SnippetsModule extends EditorModule {
  @override
  String get id => 'snippets';

  @override
  String get name => 'Code Snippets';

  ModuleContext? _ctx;

  @override
  void init(ModuleContext ctx) {
    _ctx = ctx;
  }

  @override
  void dispose() {
    _ctx = null;
  }

  void _insertSnippet(String snippet) {
    final ctx = _ctx;
    if (ctx == null) return;
    final controller = ctx.activeController;
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;

    final newText = text.replaceRange(start, selection.end >= 0 ? selection.end : start, snippet);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: start + snippet.length);
    ctx.showToast('Snippet inserido');
  }

  @override
  List<ModuleCommand> get commands => [
        ModuleCommand(
          label: 'Snippet: console.log / print',
          icon: Icons.terminal_rounded,
          category: 'Snippets',
          onTap: () => _insertSnippet('console.log();'),
        ),
        ModuleCommand(
          label: 'Snippet: Bloco try-catch',
          icon: Icons.shield_outlined,
          category: 'Snippets',
          onTap: () => _insertSnippet('try {\n  \n} catch (e) {\n  \n}'),
        ),
        ModuleCommand(
          label: 'Snippet: Declaração de Função',
          icon: Icons.code,
          category: 'Snippets',
          onTap: () => _insertSnippet('function minhaFuncao() {\n  \n}'),
        ),
        ModuleCommand(
          label: 'Snippet: Declaração de Classe',
          icon: Icons.class_outlined,
          category: 'Snippets',
          onTap: () => _insertSnippet('class MinhaClasse {\n  constructor() {\n    \n  }\n}'),
        ),
      ];

  @override
  Map<String, VoidCallback> get shortcuts => {
        'Ctrl+Shift+L': () => _insertSnippet('console.log();'),
      };
}
