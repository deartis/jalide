import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'editor_module.dart';
import 'module_context.dart';

class ModuleManager {
  final List<EditorModule> _modules = [];
  final Set<String> _disabledIds = {};
  ModuleContext? _context;
  bool _stateLoaded = false;

  static const _prefsKey = 'modules_disabled_ids';

  List<EditorModule> get modules => List.unmodifiable(_modules);

  /// Módulos registrados e habilitados
  List<EditorModule> get enabledModules =>
      List.unmodifiable(_modules.where((m) => isEnabled(m.id)));

  /// Carrega o estado persistido (módulos desabilitados)
  Future<void> loadState() async {
    if (_stateLoaded) return;
    _stateLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey);
      if (stored != null) _disabledIds.addAll(stored);
    } catch (e) {
      debugPrint('Erro ao carregar estado dos módulos: $e');
    }
  }

  bool isEnabled(String moduleId) => !_disabledIds.contains(moduleId);

  /// Liga/desliga um módulo e persiste a escolha. Módulos desabilitados não são
  /// inicializados e ficam de fora das agregações (comandos, atalhos, etc).
  Future<void> setEnabled(String moduleId, bool enabled) async {
    if (enabled) {
      _disabledIds.remove(moduleId);
      final module = _find(moduleId);
      if (module != null && _context != null) {
        module.init(_context!);
      }
    } else {
      _disabledIds.add(moduleId);
      _find(moduleId)?.dispose();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _disabledIds.toList());
    } catch (e) {
      debugPrint('Erro ao persistir estado do módulo $moduleId: $e');
    }
  }

  EditorModule? _find(String id) {
    for (final m in _modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Registra um novo módulo interno
  void registerModule(EditorModule module) {
    if (_modules.any((m) => m.id == module.id)) return;
    _modules.add(module);
    if (_context != null && isEnabled(module.id)) {
      module.init(_context!);
    }
  }

  /// Inicializa todos os módulos registrados e habilitados
  void initAll(ModuleContext ctx) {
    _context = ctx;
    for (final module in _modules) {
      if (!isEnabled(module.id)) continue;
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
      if (!isEnabled(module.id)) continue;
      list.addAll(module.commands);
    }
    return list;
  }

  /// Agrega todos os atalhos de teclado de todos os módulos
  Map<String, VoidCallback> get allShortcuts {
    final map = <String, VoidCallback>{};
    for (final module in _modules) {
      if (!isEnabled(module.id)) continue;
      map.addAll(module.shortcuts);
    }
    return map;
  }

  /// Agrega todas as ações para a AppBar
  List<Widget> get allAppBarActions {
    final list = <Widget>[];
    for (final module in _modules) {
      if (!isEnabled(module.id)) continue;
      list.addAll(module.appBarActions);
    }
    return list;
  }

  /// Agrega todos os itens de barra de status
  List<Widget> get allStatusBarItems {
    final list = <Widget>[];
    for (final module in _modules) {
      if (!isEnabled(module.id)) continue;
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

  // ─── Event Hooks ──────────────────────────────────────────────────────────

  void _broadcast(void Function(EditorModule module) call) {
    for (final module in _modules) {
      if (!isEnabled(module.id)) continue;
      try {
        call(module);
      } catch (e) {
        debugPrint('Erro no hook de ${module.id}: $e');
      }
    }
  }

  void onFileSaved(String? path) => _broadcast((m) => m.onFileSaved(path));

  void onFileOpened(String? path) => _broadcast((m) => m.onFileOpened(path));

  void onProjectOpened(String? path) =>
      _broadcast((m) => m.onProjectOpened(path));

  void onProjectClosed() => _broadcast((m) => m.onProjectClosed());

  void onEditorContentChanged(String text) =>
      _broadcast((m) => m.onEditorContentChanged(text));

  void onCursorMoved(int offset) => _broadcast((m) => m.onCursorMoved(offset));

  void onTerminalToggled(bool visible) =>
      _broadcast((m) => m.onTerminalToggled(visible));

  void onAutoSaved(String? path) => _broadcast((m) => m.onAutoSaved(path));
}
