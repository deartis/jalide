import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/controllers/editor_tab_controller.dart';
import 'package:jalide/modules/editor_module.dart';
import 'package:jalide/modules/formatter_module.dart';
import 'package:jalide/modules/git_module.dart';
import 'package:jalide/modules/module_context.dart';
import 'package:jalide/modules/module_manager.dart';
import 'package:jalide/modules/snippets_module.dart';
import 'package:jalide/modules/word_count_module.dart';
import 'package:jalide/theme/jalide_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

ModuleContext _buildContext(EditorTabController tabController) {
  return ModuleContext(
    tabController: tabController,
    getActiveController: () => tabController.activeController,
    getActivePath: () => tabController.activePath,
    getProjectPath: () => null,
    getTheme: () => JalideThemeVariant.dark,
    getIsRemoteProject: () => false,
    getSshSession: () => null,
    showToast: (msg, {type = 'info'}) {},
    setState: (fn) => fn(),
    openFile: (_) {},
    saveCurrentFile: () async {},
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ModuleManager registra e inicializa modulos nativos', () {
    final manager = ModuleManager();
    final git = GitModule();
    final snippets = SnippetsModule();

    manager.registerModule(git);
    manager.registerModule(snippets);

    expect(manager.modules.length, 2);

    final tabController = EditorTabController();
    manager.initAll(_buildContext(tabController));
    tabController.dispose();

    final commands = manager.allCommands;
    expect(commands.isNotEmpty, isTrue);
    expect(commands.any((c) => c.label.contains('Git')), isTrue);
    expect(commands.any((c) => c.label.contains('Snippet')), isTrue);

    final shortcuts = manager.allShortcuts;
    expect(shortcuts.containsKey('Ctrl+Shift+L'), isTrue);

    manager.disposeAll();
    expect(manager.modules.isEmpty, isTrue);
  });

  test('ModuleManager desabilita modulos e exclui das agregacoes', () async {
    final manager = ModuleManager();
    manager.registerModule(GitModule());
    manager.registerModule(SnippetsModule());
    await manager.loadState();
    manager.initAll(_buildContext(EditorTabController()));

    expect(manager.isEnabled('git'), isTrue);
    expect(manager.allCommands.any((c) => c.category == 'Git'), isTrue);

    await manager.setEnabled('git', false);

    expect(manager.isEnabled('git'), isFalse);
    expect(manager.allCommands.any((c) => c.category == 'Git'), isFalse);
    expect(manager.allShortcuts.containsKey('Ctrl+Shift+L'), isTrue);

    await manager.setEnabled('git', true);
    expect(manager.allCommands.any((c) => c.category == 'Git'), isTrue);
    manager.disposeAll();
  });

  test('ModuleManager persiste estado de desabilitados', () async {
    final manager = ModuleManager();
    manager.registerModule(GitModule());
    await manager.loadState();
    await manager.setEnabled('git', false);

    final reloaded = ModuleManager();
    reloaded.registerModule(GitModule());
    await reloaded.loadState();
    expect(reloaded.isEnabled('git'), isFalse);

    reloaded.disposeAll();
  });

  test('ModuleManager dispara hooks de eventos', () async {
    final manager = ModuleManager();
    final recorder = _RecordingModule();
    manager.registerModule(recorder);
    await manager.loadState();
    manager.initAll(_buildContext(EditorTabController()));

    manager.onFileSaved('/tmp/a.dart');
    manager.onFileOpened('/tmp/b.dart');
    manager.onProjectOpened('/tmp/proj');
    manager.onEditorContentChanged('hello world');
    manager.onCursorMoved(5);
    manager.onTerminalToggled(true);
    manager.onAutoSaved('/tmp/a.dart');

    expect(recorder.savedPaths, ['/tmp/a.dart']);
    expect(recorder.openedPaths, ['/tmp/b.dart']);
    expect(recorder.projectOpened, ['/tmp/proj']);
    expect(recorder.lastContent, 'hello world');
    expect(recorder.lastCursor, 5);
    expect(recorder.terminalStates, [true]);
    expect(recorder.autoSaved, ['/tmp/a.dart']);

    manager.disposeAll();
  });

  test('Modulos desabilitados nao recebem hooks', () async {
    final manager = ModuleManager();
    final recorder = _RecordingModule();
    manager.registerModule(recorder);
    await manager.loadState();
    await manager.setEnabled(recorder.id, false);
    manager.initAll(_buildContext(EditorTabController()));

    manager.onFileSaved('/tmp/a.dart');
    expect(recorder.savedPaths, isEmpty);

    manager.disposeAll();
  });

  test('WordCountModule conta linhas/palavras/caracteres', () async {
    final manager = ModuleManager();
    final module = WordCountModule();
    manager.registerModule(module);
    await manager.loadState();

    final tabController = EditorTabController();
    manager.initAll(_buildContext(tabController));
    tabController.createNewTab();
    tabController.activeController!.text = 'linha um\nlinha dois';

    expect(module.lines, 2);
    expect(module.words, 4);
    expect(module.chars, 19);

    manager.disposeAll();
  });

  test('FormatterModule registra atalho e comando', () async {
    final manager = ModuleManager();
    final module = FormatterModule();
    manager.registerModule(module);
    await manager.loadState();
    manager.initAll(_buildContext(EditorTabController()));

    expect(manager.allShortcuts.containsKey('Ctrl+Shift+F'), isTrue);
    expect(
      manager.allCommands.any((c) => c.label == 'Formatar código'),
      isTrue,
    );
    expect(manager.handleShortcut('Ctrl+Shift+F'), isTrue);

    manager.disposeAll();
  });
}

class _RecordingModule extends EditorModule {
  @override
  String get id => 'recorder';

  @override
  String get name => 'Recorder';

  final savedPaths = <String>[];
  final openedPaths = <String>[];
  final projectOpened = <String>[];
  String? lastContent;
  int? lastCursor;
  final terminalStates = <bool>[];
  final autoSaved = <String>[];

  @override
  void init(ModuleContext ctx) {}

  @override
  void dispose() {}

  @override
  void onFileSaved(String? path) => savedPaths.add(path ?? '');

  @override
  void onFileOpened(String? path) => openedPaths.add(path ?? '');

  @override
  void onProjectOpened(String? path) => projectOpened.add(path ?? '');

  @override
  void onEditorContentChanged(String text) => lastContent = text;

  @override
  void onCursorMoved(int offset) => lastCursor = offset;

  @override
  void onTerminalToggled(bool visible) => terminalStates.add(visible);

  @override
  void onAutoSaved(String? path) => autoSaved.add(path ?? '');
}
