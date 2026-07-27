# Prompt: Plugin System Interno + Refactoring de editor_screen.dart

Cole este prompt numa sessão nova do opencode para retomar o trabalho no sistema de plugin.

---

## Contexto

O JALIDE é uma IDE mobile Flutter para Android. O arquivo principal é `mobile/lib/screens/editor_screen.dart` com **4000+ linhas** - um god object que contém toda a lógica da aplicação: editor, terminal, git, SSH, AI, file explorer, teclado auxiliar, command palette, etc.

**Objetivo:** Refatorar `editor_screen.dart` em módulos internos ("plugins built-in") para:
1. Organizar o código em módulos auto-contained
2. Deixar `editor_screen.dart` leve (~1500 linhas)
3. Tornar cada feature independente e testável
4. Preparar terreno para futuros plugins de terceiros

**Não é um marketplace de plugins.** São módulos internos compilados no app.

## Diretório do Projeto

```
C:\Users\JAL\Documents\Projetos\jalide\mobile\lib\
```

## Estrutura Atual dos Arquivos

```
lib/
├── main.dart                          (46 lines)
├── controllers/
│   └── editor_tab_controller.dart     (363 lines)  Tab management + ChangeNotifier
├── l10n/                              Localizations (EN/PT)
├── models/
│   └── editor_tab.dart               (119 lines)
├── screens/
│   ├── about_screen.dart
│   ├── donation_screen.dart
│   ├── editor_screen.dart             (4053 lines) ← O MONOLITO
│   └── ssh_connect_screen.dart
├── services/
│   ├── ai_service.dart                (488 lines)
│   ├── file_service.dart              (35 lines)
│   ├── git_service.dart               (224 lines)
│   ├── ssh_connection_manager.dart
│   ├── ssh_foreground_service.dart
│   ├── ssh_host_key_service.dart
│   ├── ssh_service.dart
│   └── ssh_session_state_service.dart
├── theme/
│   └── jalide_theme.dart              (149 lines)  4 themes
├── utils/
│   ├── code_completion.dart
│   ├── code_formatter.dart
│   ├── file_utils.dart
│   └── path_navigator.dart
└── widgets/
    ├── ai_chat_panel.dart             (1100 lines)
    ├── ai_dialog.dart
    ├── ai_settings_dialog.dart
    ├── aux_keyboard.dart              (491 lines)  3-layer keyboard
    ├── command_palette.dart           (225 lines)
    ├── editor_tabs_bar.dart
    ├── file_explorer.dart             (1232+ lines)
    ├── find_replace_bar.dart          (424 lines)
    ├── ghost_suggestion_bar.dart
    ├── ssh_connection_status_widget.dart
    ├── status_bar.dart
    └── terminal_panel.dart            (660 lines)
```

## Análise de Acoplamento (Resumo)

### Mapeamento de Domínios em editor_screen.dart

| Domínio | State Variables | Métodos Principais |
|---------|----------------|-------------------|
| **CORE/TABS** | `_tabController` + getters delegados | `initState`, `_onControllerTextChanged`, `_addTab`, `_closeTab` |
| **SAVE/IO** | `_currentSave`, `_autoSaveTimers`, `_autoSaveEnabled`, `_autoFormatOnSave`, `_isFormatting` | `_saveFile`, `_saveFileAs`, `_triggerAutoSave`, `_formatCode` |
| **TERMINAL** | `_isTerminalVisible`, `_hasTerminalBeenOpened`, `_terminalMode`, `_activeTerminalState` | `_toggleTerminal`, `_runActiveFile`, `_handleTerminalKey` |
| **SSH** | `_sshProfileManager`, `_sshConnectionManager`, `_activeSshSession`, `_isRemoteProject` | `_initializeSshConnectionManager`, `_checkAndReconnectSsh`, `_openSshScreen`, `_disconnectSshSession`, `_buildOfflineBanner` |
| **PROJECT** | `_projectPath`, `_projectFiles` | `_loadProjectFiles`, `_pickProjectFolder`, `_deleteItem`, `_renameItem`, `_createNewEntity` |
| **AI** | `_aiService`, `_chatHistory`, `_lastContextPath`, `_ghostSuggestionsEnabled` | `_initializeAI`, `_openAIPanel`, `_showAISettingsDialog`, `_toggleGhostSuggestions` |
| **FIND/REPLACE** | `_isFindReplaceVisible` | `_showFindReplace` |
| **GIT** | `_gitStatus`, `_gitBranch` | `_loadGitStatus`, `_showGitPanel` |
| **EDITOR** | `_lastLineCount`, `_listenerController`, `_editorScrollKey`, `_horizontalScrollCtrl`, `_fontSize`, `_lastEditorTouchDown` | `_buildEditor`, `_goToLine`, `_toggleComment`, `_duplicateLine`, `_moveLineUp/Down`, `_insertSnippet`, `_handleCtrlShortcut` |
| **AUX KEYBOARD** | `_ctrlActive`, `_showAuxKeyboard` | `_handleAuxKeyTap`, `_handleEditorKey`, `_handleTerminalKey` |
| **PREFERENCES** | (usa SharedPreferences) | `_loadPreferences`, `_showThemeDialog` |

### Acoplamentos Criticos

1. **`_showCommandPalette()`** - lista hardcoded de 22 comandos que puxa de TODOS os domínios
2. **`_handleCtrlShortcut()`** - dispatch de atalhos que toca TODOS os domínios
3. **`_loadPreferences()`** - orquestrador que cruza 4 domínios (carrega path → files → git → tabs)
4. **`_onActiveFileChanged()`** - callback do CORE que atualiza contexto da AI (feature disfarçada de core)

### Estado Compartilhado entre Módulos

| Estado | Quem lê | Quem escreve |
|--------|---------|-------------|
| `_tabController` | TODOS | CORE |
| `_activeController` (CodeController) | CORE, EDITOR, FIND, AI, AUX KEYBOARD | CORE |
| `_activePath` | SAVE, EDITOR, AI, PROJECT, GIT | CORE |
| `_theme` | TODOS | THEME PROVIDER |
| `_projectPath` | PROJECT, GIT, TERMINAL, SSH, SAVE | PROJECT |
| `_isRemoteProject` | SSH, PROJECT, TERMINAL | SSH |
| `_activeSshSession` | SSH, TERMINAL, PROJECT, SAVE | SSH |

## Proposta de Arquitetura

### Nova pasta `lib/modules/`

```
lib/
├── modules/
│   ├── editor_module.dart             # Interface base
│   ├── module_context.dart            # O que o módulo pode acessar
│   ├── git_module.dart                # Extrai _GitPanel + _loadGitStatus
│   ├── terminal_module.dart           # Extrai terminal state + toggle + runFile
│   ├── ai_module.dart                 # Extrai chat + ghost + settings
│   ├── find_replace_module.dart       # Extrai visibility toggle
│   ├── ssh_module.dart                # Extrai SSH lifecycle
│   ├── project_module.dart            # Extrai file explorer state + CRUD
│   └── snippets_module.dart           # NOVO - primeiro plugin 100% novo
```

### Interface Base

```dart
abstract class EditorModule {
  String get id;
  String get name;
  
  /// Called when editor initializes
  void init(ModuleContext ctx);
  
  /// Called when editor disposes
  void dispose();
  
  /// Commands for the command palette
  List<ModuleCommand> get commands => [];
  
  /// Keyboard shortcuts this module registers
  Map<String, VoidCallback> get shortcuts => {};
  
  /// AppBar actions this module provides
  List<Widget> get appBarActions => [];
  
  /// Status bar items this module provides
  List<Widget> get statusBarItems => [];
  
  /// Custom panel widget (bottom sheet, etc.)
  Widget? buildPanel(BuildContext context) => null;
}
```

### ModuleContext

```dart
class ModuleContext {
  final EditorTabController tabController;
  final TextEditingController activeController;
  final String? activePath;
  final String? projectPath;
  final JalideThemeVariant theme;
  final bool isRemoteProject;
  final SshSession? sshSession;
  final void Function(String message, {String type}) showToast;
  final void Function(VoidCallback fn) setState;
  final void Function(String path) openFile;
  final void Function() saveCurrentFile;
}
```

### Módulo de Exemplo: Git

```dart
class GitModule extends EditorModule {
  @override String get id => 'git';
  @override String get name => 'Git';
  
  GitStatus? _status;
  String? _branch;
  ModuleContext? _ctx;

  @override
  void init(ModuleContext ctx) {
    _ctx = ctx;
    _loadStatus();
  }

  @override
  void dispose() { /* cleanup */ }

  @override
  List<ModuleCommand> get commands => [
    ModuleCommand(label: 'Git: Status', icon: Icons.commit, onTap: _showPanel),
    ModuleCommand(label: 'Git: Commit', icon: Icons.save, onTap: _showPanel),
  ];

  @override
  List<Widget> get appBarActions => [
    if (_branch != null)
      IconButton(
        icon: Icon(Icons.commit, color: Colors.amber),
        onPressed: _showPanel,
      ),
  ];

  void _showPanel() {
    // abre bottom sheet com o widget GitPanel (ja existente)
  }
  
  Future<void> _loadStatus() async {
    // le git status via GitService (ja existente)
  }
}
```

### Como editor_screen.dart fica depois

```dart
class _EditorScreenState extends State<EditorScreen> {
  final _modules = <EditorModule>[
    GitModule(),
    FindReplaceModule(),
    AiModule(),
    TerminalModule(),
    SshModule(),
    ProjectModule(),
  ];
  
  late ModuleContext _ctx;
  
  @override
  void initState() {
    super.initState();
    _ctx = ModuleContext(/* ... */);
    for (final m in _modules) {
      m.init(_ctx);
    }
  }
  
  @override
  void dispose() {
    for (final m in _modules) {
      m.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ... editor tabs ...
          // ... find replace bar (do modulo) ...
          _buildEditor(),
          // ... terminal (do modulo) ...
          // ... ghost suggestions (do modulo) ...
          // ... aux keyboard ...
          // ... status bar ...
        ],
      ),
    );
  }
  
  // _buildAppBar() usa _modules.flatMap((m) => m.appBarActions)
  // _showCommandPalette() usa _modules.expand((m) => m.commands)
  // _handleCtrlShortcut() usa _modules.expand((m) => m.shortcuts)
}
```

## Ordem de Implementacao

| Etapa | Modulo | Complexidade | Descricao |
|-------|--------|-------------|-----------|
| 1 | Base | Baixa | Criar `EditorModule`, `ModuleContext`, `ModuleCommand` |
| 2 | Git | Baixa | Extrai `_GitPanel` + `_loadGitStatus` (ja auto-contained, 3 inputs, 1 callback) |
| 3 | Find/Replace | Baixa | Extrai toggle `_isFindReplaceVisible` |
| 4 | AI | Media | Extrai chat + ghost + settings + `_onActiveFileChanged` |
| 5 | Terminal | Media | Extrai state + `_runActiveFile` + `_toggleTerminal` |
| 6 | SSH | Alta | Extrai lifecycle complexo |
| 7 | Project | Alta | Extrai file explorer CRUD |
| 8 | Refactor editor_screen | Alta | Remove codigo extraido, compoe modulos |
| 9 | Command Palette | Media | Command palette le de `module.commands` |
| 10 | Snippets | Baixa | **NOVO** - primeiro plugin 100% novo |
| 11 | Emmet | Media | **NOVO** - abreviacoes HTML/CSS |

## Regras Importantes

1. **Incremental** - refatorar 1 modulo por vez, rodar `dart analyze` + teste manual apos cada etapa
2. **Sem DI framework** - `ModuleContext` e suficiente para o tamanho do projeto
3. **Estado permanece em `_EditorScreenState`** - modulos recebem contexto mas nao substituem o state management atual
4. **Widgets existentes** (`_GitPanel`, `FindReplaceBar`, `TerminalPanel`, etc.) sao reutilizados, nao reescritos
5. **`dart analyze` deve passar limpo** apos cada etapa
6. **Teste manual no dispositivo** - o projeto nao tem testes unitarios

## Arquivos de Referencia

- Release notes: `mobile/docs/release_v1.0.3.md`
- Funcionalidades: `mobile/docs/funcionalidades.md`
- README: `README.md`
- Roadmap IA: `AI_ROADMAP.md`