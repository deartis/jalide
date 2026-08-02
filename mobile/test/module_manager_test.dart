import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/controllers/editor_tab_controller.dart';
import 'package:jalide/modules/git_module.dart';
import 'package:jalide/modules/module_context.dart';
import 'package:jalide/modules/module_manager.dart';
import 'package:jalide/modules/snippets_module.dart';
import 'package:jalide/theme/jalide_theme.dart';

void main() {
  test('ModuleManager registra e inicializa modulos nativos', () {
    final manager = ModuleManager();
    final git = GitModule();
    final snippets = SnippetsModule();

    manager.registerModule(git);
    manager.registerModule(snippets);

    expect(manager.modules.length, 2);

    final tabController = EditorTabController();
    final context = ModuleContext(
      tabController: tabController,
      getActiveController: () => null,
      getActivePath: () => null,
      getProjectPath: () => null,
      getTheme: () => JalideThemeVariant.dark,
      getIsRemoteProject: () => false,
      getSshSession: () => null,
      showToast: (msg, {type = 'info'}) {},
      setState: (fn) => fn(),
      openFile: (_) {},
      saveCurrentFile: () async {},
    );

    manager.initAll(context);

    final commands = manager.allCommands;
    expect(commands.isNotEmpty, isTrue);
    expect(commands.any((c) => c.label.contains('Git')), isTrue);
    expect(commands.any((c) => c.label.contains('Snippet')), isTrue);

    final shortcuts = manager.allShortcuts;
    expect(shortcuts.containsKey('Ctrl+Shift+L'), isTrue);

    manager.disposeAll();
    expect(manager.modules.isEmpty, isTrue);
  });
}
