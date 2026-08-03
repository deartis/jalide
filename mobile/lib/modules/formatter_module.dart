import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'editor_module.dart';
import 'module_context.dart';

/// Formata o código do arquivo ativo e exibe o tipo de arquivo na barra de
/// status. É um módulo demonstrativo dos hooks/atalhos do sistema de plugins.
class FormatterModule extends EditorModule {
  @override
  String get id => 'formatter';

  @override
  String get name => 'Code Formatter';

  @override
  String get description =>
      'Formata o código do arquivo ativo (Ctrl+Shift+F) e exibe o tipo de arquivo na barra de status.';

  ModuleContext? _ctx;
  String? _extension;

  @override
  void init(ModuleContext ctx) {
    _ctx = ctx;
    ctx.tabController.addListener(_onTabChanged);
    _refreshExtension();
  }

  @override
  void dispose() {
    _ctx?.tabController.removeListener(_onTabChanged);
    _ctx = null;
  }

  void _onTabChanged() => _refreshExtension();

  void _refreshExtension() {
    final path = _ctx?.activePath;
    final ext = path == null || path.isEmpty
        ? null
        : p.extension(path).replaceFirst('.', '').toUpperCase();
    if (ext != _extension) {
      _extension = ext;
      _ctx?.setState(() {});
    }
  }

  Future<void> _format() async {
    final ctx = _ctx;
    if (ctx == null) return;
    if (ctx.activeController == null) {
      ctx.showToast('Nenhum arquivo aberto');
      return;
    }
    await ctx.formatCode?.call();
    ctx.showToast('Código formatado');
  }

  @override
  List<ModuleCommand> get commands => [
        ModuleCommand(
          label: 'Formatar código',
          icon: Icons.format_align_left_outlined,
          category: 'Editor',
          onTap: _format,
        ),
      ];

  @override
  Map<String, VoidCallback> get shortcuts => {
        'Ctrl+Shift+F': _format,
      };

  @override
  List<Widget> get statusBarItems {
    final theme = _ctx?.theme;
    final ext = _extension;
    if (ext == null || ext.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: (theme?.accent ?? Colors.blueAccent).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            ext,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: theme?.accent ?? Colors.blueAccent,
            ),
          ),
        ),
      ),
    ];
  }
}
