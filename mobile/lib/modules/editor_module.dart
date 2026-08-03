import 'package:flutter/material.dart';
import 'module_context.dart';

class ModuleCommand {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final String? category;

  const ModuleCommand({
    required this.label,
    this.icon,
    required this.onTap,
    this.category,
  });
}

abstract class EditorModule {
  String get id;
  String get name;

  /// Descrição curta exibida no gerenciador de plugins
  String get description => '';

  /// Inicializa o módulo quando a IDE abre
  void init(ModuleContext ctx);

  /// Limpa recursos quando o módulo ou a IDE for encerrada
  void dispose();

  /// Lista de comandos fornecidos para a Command Palette
  List<ModuleCommand> get commands => const [];

  /// Mapeamento de atalhos de teclado (ex: 'Ctrl+Shift+G')
  Map<String, VoidCallback> get shortcuts => const {};

  /// Ações adicionais na AppBar da IDE
  List<Widget> get appBarActions => const [];

  /// Itens adicionais na barra de status inferior
  List<Widget> get statusBarItems => const [];

  /// Painel ou modal customizado fornecido pelo módulo
  Widget? buildPanel(BuildContext context) => null;

  // ─── Event Hooks ──────────────────────────────────────────────────────────

  /// Chamado após salvar um arquivo com sucesso
  void onFileSaved(String? path) {}

  /// Chamado ao abrir um arquivo no editor
  void onFileOpened(String? path) {}

  /// Chamado quando um projeto local/remoto é carregado
  void onProjectOpened(String? path) {}

  /// Chamado quando o projeto atual é fechado
  void onProjectClosed() {}

  /// Chamado quando o texto do editor ativo muda
  void onEditorContentChanged(String text) {}

  /// Chamado quando o cursor do editor se move
  void onCursorMoved(int offset) {}

  /// Chamado quando o terminal é aberto/fechado pelo usuário
  void onTerminalToggled(bool visible) {}

  /// Chamado após um auto-save bem-sucedido
  void onAutoSaved(String? path) {}
}
