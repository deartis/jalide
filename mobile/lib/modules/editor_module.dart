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
}
