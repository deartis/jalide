import 'package:flutter/material.dart';
import 'editor_module.dart';
import 'module_context.dart';

class ModuleManager {
  final List<EditorModule> _modules = [];
  ModuleContext? _context;

  List<EditorModule> get modules => List.unmodifiable(_modules);

  /// Registra um novo módulo interno
  void registerModule(EditorModule module) {
    if (_modules.any((m) => m.id == module.id)) return;
    _modules.add(module);
    if (_context != null) {
      module.init(_context!);
    }
  }

  /// Inicializa todos os módulos registrados
  void initAll(ModuleContext ctx) {
    _context = ctx;
    for (final module in _modules) {
      try {
        module.init(ctx);
      } catch (e) {
        debugPrint('Erro ao inicializar módulo ${module.id}: $e');
      }
    }
  }

  /// Encerra todos os módulos
  void disposeAll() {
    for (final module in _modules) {
      try {
        module.dispose();
      } catch (e) {
        debugPrint('Erro ao encerrar módulo ${module.id}: $e');
      }
    }
    _modules.clear();
    _context = null;
  }

  /// Agrega todos os comandos para a Command Palette
  List<ModuleCommand> get allCommands {
    final list = <ModuleCommand>[];
    for (final module in _modules) {
      list.addAll(module.commands);
    }
    return list;
  }

  /// Agrega todos os atalhos de teclado de todos os módulos
  Map<String, VoidCallback> get allShortcuts {
    final map = <String, VoidCallback>{};
    for (final module in _modules) {
      map.addAll(module.shortcuts);
    }
    return map;
  }

  /// Agrega todas as ações para a AppBar
  List<Widget> get allAppBarActions {
    final list = <Widget>[];
    for (final module in _modules) {
      list.addAll(module.appBarActions);
    }
    return list;
  }

  /// Agrega todos os itens de barra de status
  List<Widget> get allStatusBarItems {
    final list = <Widget>[];
    for (final module in _modules) {
      list.addAll(module.statusBarItems);
    }
    return list;
  }

  /// Tenta executar um atalho de teclado registrado pelos módulos
  bool handleShortcut(String shortcutKey) {
    final action = allShortcuts[shortcutKey];
    if (action != null) {
      action();
      return true;
    }
    return false;
  }
}
