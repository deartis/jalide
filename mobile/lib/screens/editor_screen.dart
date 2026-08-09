import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:jalide/models/editor_tab.dart';
import 'package:jalide/services/ssh_service.dart';
import 'package:jalide/screens/about_screen.dart';
import 'package:jalide/screens/help_screen.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_service.dart';
import '../utils/file_utils.dart';
import '../services/ai_service.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_foreground_service.dart';
import '../services/ssh_host_key_service.dart';
import '../services/ssh_session_state_service.dart';
import '../theme/jalide_theme.dart';
import '../controllers/editor_tab_controller.dart';
import '../widgets/aux_keyboard.dart';
import '../widgets/ghost_suggestion_bar.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/file_explorer.dart';
import '../widgets/editor_tabs_bar.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/ai_settings_dialog.dart';
import '../utils/code_formatter.dart';
import '../services/project_stack_detector.dart';
import '../services/environment_orchestrator.dart';
import '../widgets/environment_status_bar.dart';
import 'ssh_connect_screen.dart';
import '../l10n/app_localizations.dart';
import '../widgets/find_replace_bar.dart';
import '../widgets/command_palette.dart';
import '../widgets/code_indentation_guides.dart';
import 'package:highlight/languages/typescript.dart' as lang_ts;
import 'package:highlight/languages/java.dart' as lang_java;
import 'package:highlight/languages/go.dart' as lang_go;
import 'package:highlight/languages/rust.dart' as lang_rust;
import 'package:highlight/languages/kotlin.dart' as lang_kt;
import 'package:highlight/languages/sql.dart' as lang_sql;
import 'package:highlight/languages/yaml.dart' as lang_yaml;
import 'package:highlight/languages/bash.dart' as lang_bash;
import 'package:highlight/languages/ruby.dart' as lang_ruby;
import 'package:highlight/languages/php.dart' as lang_php;
import 'package:highlight/languages/cs.dart' as lang_cs;
import '../modules/module_manager.dart';
import '../modules/module_context.dart';
import '../modules/snippets_module.dart';
import '../modules/word_count_module.dart';
import '../modules/formatter_module.dart';
import 'plugin_manager_screen.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

enum _ToastType { info, success, error }

class _SnackBarStyle {
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  const _SnackBarStyle({
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controller de Tabs
  late final EditorTabController _tabController;

  // Getters delegados ao controller
  CodeController? get _activeController => _tabController.activeController;
  FocusNode? get _activeFocusNode => _tabController.activeFocusNode;
  String? get _activePath => _tabController.activePath;
  bool get _activeHasUnsavedChanges => _tabController.hasUnsavedChanges;
  String get _fileName => _tabController.fileName;
  String get _languageName => _tabController.languageName;

  JalideThemeVariant get _theme => ThemeProvider.of(context).current;

  bool _isTerminalVisible = false;
  bool _hasTerminalBeenOpened = false;
  TerminalMode _terminalMode = TerminalMode.local;
  SshSession? _activeSshSession;
  TerminalInputHandler? _activeTerminalState;
  DateTime? _lastEditorTouchDown;
  bool _isRemoteProject = false;
  Future<void>? _currentSave;
  final SshProfileManager _sshProfileManager = SshProfileManager();
  late SshConnectionManager _sshConnectionManager;

  // Explorer de Projeto
  String? _projectPath;
  List<Map<String, dynamic>> _projectFiles = [];
  JalideProjectConfig? _projectConfig;
  final EnvironmentOrchestrator _environmentOrchestrator =
      EnvironmentOrchestrator();

  // Configurações
  final AIService _aiService = AIService();
  // Histórico persistente do chat — sobrevive ao fechar/reabrir o painel
  List<ChatMessage> _chatHistory = [];
  // Arquivo ativo na última vez que o contexto foi atualizado
  String? _lastContextPath;
  double _fontSize = 14.0;
  bool _autoSaveEnabled = true;
  bool _ghostSuggestionsEnabled = true;
  bool _autoFormatOnSave = false;
  Timer? _autoSaveTimer;
  // BUG2 FIX: Um timer por path de aba para evitar race condition no auto-save
  final Map<String, Timer> _autoSaveTimers = {};
  bool _isFormatting =
      false; // Guard contra loop de auto-save durante formatação
  int _lastLineCount = 1;
  CodeController? _listenerController;

  // Key para encontrar o ScrollPosition horizontal interno do CodeField
  final GlobalKey _editorScrollKey = GlobalKey();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  bool _isFindReplaceVisible = false;

  // Teclado auxiliar
  bool _ctrlActive = false;
  bool _showAuxKeyboard = true;

  List<String> get _currentAuxKeys {
    if (_ctrlActive) {
      return [
        'Ctrl',
        'Z (Undo)',
        'Y (Redo)',
        'A (All)',
        'C (Copy)',
        'V (Paste)',
        'X (Cut)',
        '↑ (MoveUp)',
        '↓ (MoveDown)',
      ];
    }
    return [
      'Tab',
      'Ctrl',
      '↑',
      '↓',
      '←',
      '→',
      '{ }',
      '[ ]',
      '( )',
      '" "',
      "' '",
      '🔍',
      '//',
      '⊞',
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = EditorTabController();
    _tabController.onUnsavedChanged = (a, b) {
      if (mounted) setState(() {});
    };
    _tabController.onAutoSaveTriggered = (index) {
      // Ignora mudanças causadas pelo próprio _formatCode para evitar loop
      if (_isFormatting) return;
      if (_autoSaveEnabled &&
          mounted &&
          index < _tabController.openTabs.length) {
        final tab = _tabController.openTabs[index];
        if (tab.hasUnsavedChanges) {
          _triggerAutoSave(tab);
        }
      }
    };
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
        _onActiveFileChanged();
      }
    });
    _sshProfileManager.load();
    _sshConnectionManager = SshConnectionManager(
      profileManager: _sshProfileManager,
    );
    _sshConnectionManager.addListener(_onSshConnectionChanged);
    WidgetsBinding.instance.addObserver(this);
    _initializeAI();
    _initializeSshConnectionManager();
    // Escuta o botão "Desconectar" da notificação do Foreground Service
    SshForegroundService.addDataCallback(_onForegroundServiceData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initModules();
      _loadPreferences();
      // #14 FIX: reseta _ctrlActive quando o foco do editor muda
      _activeFocusNode?.addListener(() {
        if (_activeFocusNode?.hasFocus != true && _ctrlActive) {
          setState(() => _ctrlActive = false);
        }
      });
    });
  }

  final ModuleManager _moduleManager = ModuleManager();

  void _initModules() {
    _moduleManager.registerModule(SnippetsModule());
    _moduleManager.registerModule(WordCountModule());
    _moduleManager.registerModule(FormatterModule());

    final ctx = ModuleContext(
      tabController: _tabController,
      getActiveController: () => _activeController,
      getActivePath: () => _activePath,
      getProjectPath: () => _projectPath,
      getTheme: () => _theme,
      getIsRemoteProject: () => _isRemoteProject,
      getSshSession: () => _activeSshSession,
      showToast: (msg, {type = 'info'}) => _showToast(msg),
      setState: (fn) {
        if (mounted) setState(fn);
      },
      openFile: (path) => _openFileFromExplorer(path),
      saveCurrentFile: () => _saveFile(),
      formatCode: () async => _formatCode(),
    );

    _moduleManager.loadState().then((_) => _moduleManager.initAll(ctx));
  }

  Future<void> _initializeSshConnectionManager() async {
    await _sshConnectionManager.initialize();

    // Garante que o sshd do Termux foi acionado/iniciado antes de tentar reconectar
    await _startTermuxSshdIfNeeded();

    // Tenta reconectar silenciosamente à última sessão SSH ao iniciar o app
    final persistedState = await SshSessionStateService.load();
    if (persistedState != null && mounted) {
      debugPrint('📱 Estado SSH anterior encontrado: $persistedState');
      await _sshProfileManager.load();
      final profile = await _sshConnectionManager.getLastSuccessfulProfile();
      if (profile != null && mounted) {
        debugPrint('🔄 Tentando reconexão silenciosa com: ${profile.label}');
        final success = await _sshConnectionManager.connect(
          profile,
          onHostKeyVerify: _silentHostKeyVerify,
        );
        if (success && mounted) {
          setState(() {
            _activeSshSession = _sshConnectionManager.currentSession;
            _terminalMode = TerminalMode.ssh;
          });
          final prefs = await SharedPreferences.getInstance();
          final targetRemotePath =
              persistedState.projectPath ??
              prefs.getString('last_project_path');
          if (targetRemotePath != null &&
              targetRemotePath.isNotEmpty &&
              mounted) {
            setState(() {
              _isRemoteProject = true;
            });
            await _loadRemoteProjectFiles(targetRemotePath);
          }
          await _reloadRemoteTabsContent();
          _showToast(
            'SSH reconectado: ${profile.label}',
            type: _ToastType.success,
          );
        } else {
          debugPrint(
            '⚠️ Reconexão silenciosa falhou. App inicia em modo local.',
          );
        }
      }
    }
  }

  Future<void> _startTermuxSshdIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      debugPrint('🚀 Solicitando inicialização do sshd no Termux...');
      await _termuxChannel.invokeMethod('runTermuxCommand', {
        'script': 'pgrep sshd || sshd',
      });
      debugPrint('✅ Comando de inicialização do sshd enviado ao Termux.');
    } catch (e) {
      debugPrint('⚠️ Erro ao tentar iniciar sshd no Termux: $e');
    }
  }

  void _onSshConnectionChanged() {
    if (mounted) {
      setState(() {
        _activeSshSession = _sshConnectionManager.currentSession;
        final session = _activeSshSession;
        if (session == null) {
          // Sessão completamente nula: resetar para local
          _terminalMode = TerminalMode.local;
          _isRemoteProject = false;
        } else if (session.isConnected) {
          _terminalMode = TerminalMode.ssh;
        }
        // Se em estado de erro/reconectando: mantém _terminalMode e _isRemoteProject
        // intactos — o usuário continua vendo os arquivos remotos em "modo offline".
      });
    }
  }

  /// Recebe dados enviados pelo TaskHandler do Foreground Service.
  /// Atualmente usado para processar o botão "Desconectar" da notificação.
  void _onForegroundServiceData(Object data) {
    if (data is Map<String, dynamic>) {
      final action = data['action'];
      if (action == 'disconnect') {
        debugPrint('📲 Botão desconectar da notificação pressionado.');
        _sshConnectionManager.disconnect();
      } else if (action == 'exit') {
        debugPrint(
          '📲 Botão sair da notificação pressionado. Encerrando app...',
        );
        SystemNavigator.pop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndReconnectSsh();
    }
  }

  Future<void> _checkAndReconnectSsh() async {
    debugPrint('📱 App retomado. Verificando saúde da conexão SSH...');
    if (_isRemoteProject || _sshConnectionManager.currentSession != null) {
      final isHealthy = await _sshConnectionManager.checkConnectionHealth();
      if (!isHealthy) {
        _showToast('Conexão SSH perdida. Tentando reconectar...');
        final success = await _sshConnectionManager.reconnectNow();
        if (success) {
          _showToast('SSH reconectado com sucesso!', type: _ToastType.success);
          if (_projectPath != null && _isRemoteProject) {
            await _loadRemoteProjectFiles(_projectPath!);
          }
          await _reloadRemoteTabsContent();
        } else {
          _showToast('Falha ao reconectar SSH', type: _ToastType.error);
        }
      } else {
        debugPrint('🟢 Conexão SSH continua ativa.');
      }
    }
  }

  @override
  void dispose() {
    SshForegroundService.removeDataCallback(_onForegroundServiceData);
    WidgetsBinding.instance.removeObserver(this);
    _sshConnectionManager.removeListener(_onSshConnectionChanged);
    _sshConnectionManager.dispose();
    _autoSaveTimer?.cancel();
    // BUG2 FIX: cancela todos os timers de auto-save individuais
    for (final t in _autoSaveTimers.values) {
      t.cancel();
    }
    _autoSaveTimers.clear();
    _listenerController?.removeListener(_onControllerTextChanged);
    _tabController.disposeTabs();
    _tabController.dispose();
    _horizontalScrollCtrl.dispose();
    _moduleManager.disposeAll();
    super.dispose();
  }

  void _onControllerTextChanged() {
    if (_activeController == null) return;
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    _moduleManager.onEditorContentChanged(text);
    _moduleManager.onCursorMoved(sel.baseOffset);
    final lineCount = '\n'.allMatches(text).length + 1;
    if (lineCount != _lastLineCount) {
      _lastLineCount = lineCount;
      if (mounted) {
        setState(() {});
      }
    }
    // Rola horizontal para inicio quando cursor esta no comeco de uma linha
    if (sel.isCollapsed &&
        sel.start > 0 &&
        sel.start <= text.length &&
        text[sel.start - 1] == '\n') {
      _scrollHorizontalToStart();
    } else if (sel.isCollapsed && sel.start == 0) {
      _scrollHorizontalToStart();
    }
  }

  void _updateActiveControllerListener() {
    final currentController = _activeController;
    if (_listenerController != currentController) {
      _listenerController?.removeListener(_onControllerTextChanged);
      _listenerController = currentController;
      _listenerController?.addListener(_onControllerTextChanged);
      if (currentController != null) {
        _lastLineCount = '\n'.allMatches(currentController.text).length + 1;
      }
    }
  }

  double _calculateGutterWidth() {
    if (_activeController == null) return 64.0;
    final lineCount = _lastLineCount;
    final digits = lineCount.toString().length;

    // IMPORTANT: flutter_code_editor 0.3.5 ignores fontSize in GutterStyle.textStyle
    // and always uses the editor's font size for line numbers.
    // So we must base width on _fontSize, NOT the smaller gutter font size.
    // Monospace char width ≈ 0.6 * fontSize
    // Gutter total = lineNumber column + error column (16) + folding column (16) + margin
    final charWidth = _fontSize * 0.6;
    final lineNumberColumnWidth = digits * charWidth;

    // 16 (errors) + 16 (folding) = 32px for icons, + 10px right margin
    const iconColumnsWidth = 32.0;
    const rightMargin = 10.0;
    const leftPadding = 8.0; // CodeField has padding: left: 8

    return lineNumberColumnWidth + iconColumnsWidth + rightMargin + leftPadding;
  }

  Future<void> _initializeAI() async {
    try {
      if (await _aiService.hasApiKey()) {
        await _aiService.initialize();
        debugPrint('✅ AIService inicializado com sucesso');
      } else {
        debugPrint('ℹ️ AIService não inicializado: Nenhuma chave salva');
      }
    } catch (e) {
      debugPrint('❌ Erro ao inicializar AIService: $e');
    }
    // Carrega histórico persistido em disco
    try {
      final raw = await _aiService.loadPersistedHistory();
      if (raw.isNotEmpty && mounted) {
        setState(() {
          _chatHistory = raw.map(ChatMessage.fromJson).toList();
        });
        debugPrint('✅ Histórico do chat restaurado: ${raw.length} msgs');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar histórico do chat: $e');
    }
  }

  /// Chamado quando a aba ativa muda — atualiza o contexto da IA silenciosamente.
  void _onActiveFileChanged() {
    final currentPath = _activePath;
    if (currentPath == null || currentPath == _lastContextPath) return;
    _lastContextPath = currentPath;

    // Só atualiza contexto se há uma sessão ativa
    if (_chatHistory.length <= 1) {
      return; // Apenas msg de sistema = sem conversa
    }

    // Evita adicionar marcadores de contexto duplicados consecutivos
    if (_chatHistory.isNotEmpty &&
        _chatHistory.last.role == ChatMsgRole.system) {
      final lastText = _chatHistory.last.text;
      final fileName = currentPath.split(RegExp(r'[/\\]')).last;
      if (lastText.contains('Contexto atualizado') &&
          lastText.contains(fileName)) {
        return; // Já tem marcador recente para este arquivo
      }
    }

    final projectPaths = _projectFiles
        .where((f) => f['isDir'] != true)
        .map((f) => (f['path'] ?? f['name']) as String)
        .toList();

    _aiService
        .updateContext(
          activeFileContent: _activeController?.text ?? '',
          activeFilePath: currentPath,
          languageName: _languageName,
          projectFilePaths: projectPaths,
          openTabsPaths: _tabController.openTabs
              .map((t) => t.path ?? 'untitled')
              .toList(),
        )
        .then((_) {
          // Adiciona marcador visual de contexto atualizado no chat
          if (mounted && _chatHistory.isNotEmpty) {
            final fileName = currentPath.split(RegExp(r'[/\\]')).last;
            setState(() {
              _chatHistory.add(
                ChatMessage(
                  role: ChatMsgRole.system,
                  text: '↺ Contexto atualizado: $fileName',
                ),
              );
            });
          }
        })
        .catchError((e) {
          debugPrint('⚠️ Falha ao atualizar contexto da IA: $e');
        });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Auto-Save Setting
    final savedAutoSave = prefs.getBool('autosave_enabled') ?? true;
    final savedGhost = prefs.getBool('ghost_suggestions_enabled') ?? true;
    final savedAutoFormat = prefs.getBool('autoformat_on_save') ?? false;
    if (mounted) {
      setState(() {
        _autoSaveEnabled = savedAutoSave;
        _ghostSuggestionsEnabled = savedGhost;
        _autoFormatOnSave = savedAutoFormat;
      });
    }

    // Load Font Size
    final savedFontSize = prefs.getDouble('last_font_size');
    if (savedFontSize != null && mounted) {
      setState(() => _fontSize = savedFontSize);
    }

    // Load Project Path
    final savedProjectPath = prefs.getString('last_project_path');
    if (savedProjectPath != null && savedProjectPath.isNotEmpty) {
      bool isSpecialPath =
          savedProjectPath.startsWith('content://') ||
          savedProjectPath.startsWith('/data/data/com.termux') ||
          savedProjectPath.contains('jalide-workspace');
      bool exists = isSpecialPath || Directory(savedProjectPath).existsSync();

      if (exists && !_isRemoteProject) {
        await _loadProjectFiles(savedProjectPath);
      }
    }

    // Load Persisted Tabs
    final persistedTabsStr = prefs.getString('persisted_open_tabs');
    if (persistedTabsStr != null) {
      try {
        final List<dynamic> tabsData = jsonDecode(persistedTabsStr);
        for (final tabData in tabsData) {
          final String? path = tabData['path'];
          final bool isRemote = tabData['isRemote'] as bool? ?? false;
          if (path != null && path.isNotEmpty) {
            bool exists = false;
            if (path.startsWith('content://') || isRemote) {
              exists = true;
            } else {
              exists = File(path).existsSync();
            }

            if (exists) {
              String content = "";
              if (!isRemote) {
                try {
                  content = await FileService.readFile(path);
                } catch (e) {
                  debugPrint('JALIDE_LOAD_PERSISTED_TAB_READ_ERROR: $e');
                }
              }
              _tabController.addOrActivateTab(
                path,
                content,
                isRemote: isRemote,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('JALIDE_LOAD_PERSISTED_TABS_ERROR: $e');
      }
    }

    // Load Last Active File
    final savedActiveFile = prefs.getString('last_active_file');
    if (savedActiveFile != null) {
      final index = _tabController.openTabs.indexWhere(
        (t) => t.path == savedActiveFile,
      );
      if (index != -1) {
        _tabController.setActiveTab(index);
      } else {
        bool exists = false;
        if (savedActiveFile.startsWith('content://')) {
          exists = true;
        } else {
          exists = File(savedActiveFile).existsSync();
        }

        if (exists) {
          try {
            final content = await FileService.readFile(savedActiveFile);
            _tabController.addOrActivateTab(savedActiveFile, content);
          } catch (_) {}
        }
      }
    }

    if (mounted && _tabController.openTabs.isEmpty) {
      _tabController.createNewTab();
    }
  }

  Future<void> _updateFontSize(double newSize) async {
    if (!mounted) return;
    setState(() => _fontSize = newSize.clamp(8.0, 32.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_font_size', _fontSize);
  }

  Future<void> _saveTabsPreference() => _tabController.saveTabsPreference();

  Future<void> _loadProjectFiles(String path) async {
    if (path.startsWith('content://')) {
      try {
        final List<dynamic> files = await _termuxChannel.invokeMethod(
          'listSafDirectory',
          {'uri': path},
        );
        if (mounted) {
          setState(() {
            _projectPath = path;
            _isRemoteProject = false;
            _projectFiles = files
                .map(
                  (f) => {
                    'name': f['name'] as String,
                    'path': f['uri'] as String,
                    'isDir': f['isDir'] as bool,
                    'isSaf': true,
                  },
                )
                .toList();
          });
          _moduleManager.onProjectOpened(path);
        }
      } catch (e) {
        _showToast('Erro ao listar pasta SAF: $e', type: _ToastType.error);
      }
      return;
    }

    final dir = Directory(path);
    if (!dir.existsSync()) {
      _showToast('Erro: Pasta não encontrada em $path', type: _ToastType.error);
      return;
    }

    try {
      final entities = await dir.list().toList();

      entities.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      if (mounted) {
        setState(() {
          _projectPath = path;
          _isRemoteProject = false;
          _projectFiles = entities
              .map(
                (e) => {
                  'name': p.basename(e.path),
                  'path': e.path,
                  'isDir': e is Directory,
                  'isSaf': false,
                },
              )
              .toList();
        });
        _moduleManager.onProjectOpened(path);
        // Persiste o caminho do projeto ativo no SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_project_path', path);
        } catch (_) {}
        // Auto-detecta a stack e cria jalide.json caso não exista
        try {
          final config = await ProjectStackDetector.detectLocal(path);
          if (mounted) {
            setState(() => _projectConfig = config);
          }
          _environmentOrchestrator.startEnvironment(config: config);
        } catch (_) {}
      }
    } catch (e) {
      _showToast('Erro ao listar arquivos: $e', type: _ToastType.error);
      debugPrint('JALIDE_ERROR: $e');
    }
  }

  Future<void> _loadRemoteProjectFiles(String path) async {
    if (_activeSshSession == null || !_activeSshSession!.isConnected) return;

    try {
      final files = await _activeSshSession!.listDir(path);
      if (mounted) {
        setState(() {
          _projectPath = path;
          _isRemoteProject = true;
          _projectFiles = files
              .map(
                (f) => {
                  'name': f.name,
                  'path': f.path,
                  'isDir': f.isDir,
                  'isSaf': false,
                  'isRemote': true,
                },
              )
              .toList();
        });
        _moduleManager.onProjectOpened(path);
        // Persiste o caminho do projeto para retomada após reinício do app
        await SshSessionStateService.updateProjectPath(path);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_project_path', path);
        } catch (_) {}
        try {
          final config = ProjectStackDetector.detectFromFilenames(
            p.posix.basename(path),
            files.map((f) => f.name).toList(),
          );
          if (mounted) {
            setState(() => _projectConfig = config);
          }
          _environmentOrchestrator.startEnvironment(
            config: config,
            sshSession: _activeSshSession,
          );
        } catch (_) {}
      }
    } catch (e) {
      _showToast('Erro ao listar arquivos remotos: $e', type: _ToastType.error);
    }
  }

  Future<void> _reloadRemoteTabsContent() async {
    final session = _activeSshSession;
    if (session == null || !session.isConnected) return;

    for (int i = 0; i < _tabController.openTabs.length; i++) {
      final tab = _tabController.openTabs[i];
      if (tab.isRemote && tab.path != null) {
        try {
          // Preserva alterações não salvas do usuário
          if (tab.hasUnsavedChanges) {
            debugPrint(
              '⚠️ Pulando recarga da aba remota ${tab.path} — alterações não salvas preservadas',
            );
            continue;
          }
          debugPrint('🔄 Recarregando conteúdo da aba remota: ${tab.path}');
          final content = await session.readFile(tab.path!);
          if (mounted) {
            setState(() {
              tab.initialContent = content;
              tab.controller.text = content;
              tab.hasUnsavedChanges = false;
            });
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao recarregar aba remota ${tab.path}: $e');
        }
      }
    }
  }

  // Métodos movidos para EditorTabController:
  // _createController, _getLanguageDisplayName, _createNewTab,
  // _fileName, _languageName, _getInitialLanguageName, _langForPath

  void _showLanguageSelector() {
    if (_tabController.activeTabIndex == -1) return;

    final languages = [
      {'name': 'JavaScript', 'highlight': javascript, 'displayName': 'JS'},
      {
        'name': 'TypeScript',
        'highlight': lang_ts.typescript,
        'displayName': 'TS',
      },
      {'name': 'JSON', 'highlight': json, 'displayName': 'JSON'},
      {'name': 'Python', 'highlight': python, 'displayName': 'Python'},
      {'name': 'HTML', 'highlight': xml, 'displayName': 'HTML'},
      {'name': 'CSS', 'highlight': css, 'displayName': 'CSS'},
      {'name': 'Dart', 'highlight': dart, 'displayName': 'Dart'},
      {'name': 'C++', 'highlight': cpp, 'displayName': 'C++'},
      {'name': 'Java', 'highlight': lang_java.java, 'displayName': 'Java'},
      {'name': 'Go', 'highlight': lang_go.go, 'displayName': 'Go'},
      {'name': 'Rust', 'highlight': lang_rust.rust, 'displayName': 'Rust'},
      {'name': 'Kotlin', 'highlight': lang_kt.kotlin, 'displayName': 'Kotlin'},
      {'name': 'Ruby', 'highlight': lang_ruby.ruby, 'displayName': 'Ruby'},
      {'name': 'PHP', 'highlight': lang_php.php, 'displayName': 'PHP'},
      {'name': 'C#', 'highlight': lang_cs.cs, 'displayName': 'C#'},
      {'name': 'SQL', 'highlight': lang_sql.sql, 'displayName': 'SQL'},
      {'name': 'YAML', 'highlight': lang_yaml.yaml, 'displayName': 'YAML'},
      {'name': 'Bash', 'highlight': lang_bash.bash, 'displayName': 'Bash'},
      {'name': 'Markdown', 'highlight': markdown, 'displayName': 'Markdown'},
    ];

    final activeIndex = _tabController.activeTabIndex;

    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecionar Modo de Linguagem',
                style: TextStyle(
                  color: _theme.textPri,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (ctx, index) {
                    final lang = languages[index];
                    final isCurrent =
                        _tabController.languageName == lang['displayName'];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        lang['name'] as String,
                        style: TextStyle(
                          color: isCurrent ? _theme.accent : _theme.textPri,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(
                              Icons.check_circle,
                              color: _theme.accent,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        _tabController.updateLanguage(
                          activeIndex,
                          lang['displayName'] as String,
                          lang['highlight'] as Mode?,
                        );
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runActiveFile() async {
    if (_tabController.activeTabIndex == -1) {
      _showToast('Nenhum arquivo aberto');
      return;
    }

    if (_activePath == null) {
      _showToast('Por favor, salve o arquivo antes de rodar!');
      return;
    }

    // Se o arquivo tiver alterações não salvas, salva antes de rodar!
    if (_tabController.hasUnsavedChanges) {
      _showToast('Salvando alterações...');
      await _saveFile();
    }

    // Garante que o terminal está visível
    if (!_isTerminalVisible) {
      setState(() {
        _isTerminalVisible = true;
        _hasTerminalBeenOpened = true;
      });
      // Dá um tempinho para o terminal renderizar se for a primeira vez
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (_activeTerminalState == null) {
      _showToast('Aguardando inicialização do terminal...');
      return;
    }

    final physicalActivePath = FileUtils.resolveSafPath(_activePath!);
    final physicalProjectPath = _projectPath != null
        ? FileUtils.resolveSafPath(_projectPath!)
        : null;

    String fileRunPath = '';
    if (physicalProjectPath != null &&
        physicalActivePath.startsWith(physicalProjectPath)) {
      fileRunPath = p.relative(physicalActivePath, from: physicalProjectPath);
      if (!fileRunPath.startsWith('.')) {
        fileRunPath = './$fileRunPath';
      }
    } else {
      fileRunPath = physicalActivePath;
    }

    final ext = p.extension(physicalActivePath).toLowerCase();
    String command = '';
    switch (ext) {
      case '.js':
      case '.mjs':
        command = 'node "$fileRunPath"';
        break;
      case '.py':
      case '.pyw':
        command = 'python "$fileRunPath"';
        break;
      case '.dart':
        command = 'dart run "$fileRunPath"';
        break;
      case '.cpp':
      case '.cc':
        final binName = p.basenameWithoutExtension(fileRunPath);
        final parentPath = p.dirname(fileRunPath);
        final outBin = parentPath == '.'
            ? './$binName'
            : '$parentPath/$binName';
        command = 'clang++ "$fileRunPath" -o "$outBin" && "$outBin"';
        break;
      case '.c':
        final cBinName = p.basenameWithoutExtension(fileRunPath);
        final cParentPath = p.dirname(fileRunPath);
        final cOutBin = cParentPath == '.'
            ? './$cBinName'
            : '$cParentPath/$cBinName';
        command = 'clang "$fileRunPath" -o "$cOutBin" && "$cOutBin"';
        break;
      case '.sh':
        command = 'bash "$fileRunPath"';
        break;
      case '.html':
      case '.htm':
        _showToast('Iniciando servidor Web na porta 8000...');
        command = 'python -m http.server 8000';
        break;
      default:
        command = 'cat "$fileRunPath"';
        break;
    }

    if (command.isNotEmpty) {
      _activeTerminalState!.sendInput('$command\n');
    }
  }

  Future<void> _openFileFromExplorer(String path) async {
    try {
      String content;
      if (path.startsWith('content://')) {
        content = await _termuxChannel.invokeMethod('readSafFile', {
          'uri': path,
        });
      } else if (_isRemoteProject && _activeSshSession != null) {
        content = await _activeSshSession!.readFile(path);
      } else {
        content = await FileService.readFile(path);
      }
      _addTab(path, content, isRemote: _isRemoteProject);
      _moduleManager.onFileOpened(path);

      // Fecha o drawer usando a chave global do Scaffold
      _scaffoldKey.currentState?.closeDrawer();
    } catch (e) {
      _showToast('Erro ao abrir arquivo: $e', type: _ToastType.error);
    }
  }

  void _addTab(String path, String content, {bool isRemote = false}) {
    _tabController.addOrActivateTab(path, content, isRemote: isRemote);
  }

  Future<void> _writeFileContent(
    String path,
    String content,
    bool isRemote,
  ) async {
    if (path.startsWith('content://')) {
      await _termuxChannel.invokeMethod('writeSafFile', {
        'uri': path,
        'content': content,
      });
    } else if (isRemote && _activeSshSession != null) {
      await _activeSshSession!.writeFile(path, content);
    } else {
      await File(path).writeAsString(content);
    }

    if (_debugAutoSave) {
      await _verifyWrittenFile(path, content, isRemote);
    }
  }

  Future<void> _saveFile() async {
    if (_tabController.activeTabIndex == -1) return;
    if (_activePath == null) {
      await _saveFileAs();
      return;
    }
    if (_currentSave != null) {
      debugPrint('JALIDE_SAVE_BLOCKED: Save already in progress');
      _debugAutoSaveLog('SKIP_BUSY', path: _activePath, busy: true);
      return;
    }

    if (_autoFormatOnSave) {
      _formatCode(silent: true);
    }

    final controller = _activeController!;
    final text = controller.text;
    _debugAutoSaveLog(
      'SEND',
      path: _activePath,
      textLen: text.length,
      textHash: text.hashCode,
      cursor: controller.selection.isValid
          ? controller.selection.baseOffset
          : -1,
      composing: controller.value.composing.isValid &&
          !controller.value.composing.isCollapsed,
      busy: _currentSave != null,
    );

    final future = _writeFileContent(
      _activePath!,
      text,
      _tabController.activeTab?.isRemote ?? false,
    );
    _currentSave = future;
    try {
      await future;
      if (!mounted) return;

      final textMovedOn = controller.text != text;
      _debugAutoSaveLog(
        textMovedOn ? 'MARK_CLEAN_STALE' : 'MARK_CLEAN_OK',
        path: _activePath,
        textLen: controller.text.length,
        textHash: controller.text.hashCode,
        detail: textMovedOn ? 'texto mudou durante a gravacao' : null,
      );

      _tabController.markTabSaved(_tabController.activeTabIndex);
      _moduleManager.onFileSaved(_activePath);
      _showToast('Salvo com sucesso', type: _ToastType.success);
    } catch (e) {
      _showToast('Erro ao salvar: $e', type: _ToastType.error);
      debugPrint('JALIDE_SAVE_ERROR: $e');
    } finally {
      _currentSave = null;
    }
  }

  Future<void> _saveFileAs() async {
    if (_tabController.activeTabIndex == -1) return;

    final currentName = _activePath == null
        ? 'untitled.js'
        : p.basename(_activePath!);

    final nameController = TextEditingController(text: currentName);

    final confirmedName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _theme.surface,
        title: Text('Salvar como', style: TextStyle(color: _theme.textPri)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: _theme.textPri, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: 'Nome do arquivo',
            labelStyle: TextStyle(color: _theme.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _theme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _theme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: _theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: Text('Salvar', style: TextStyle(color: _theme.accent)),
          ),
        ],
      ),
    );

    if (confirmedName == null || confirmedName.trim().isEmpty) {
      _showToast('Cancelado');
      return;
    }

    // Aviso se salvar sem extensão (syntax highlight não vai funcionar)
    final hasExtension = confirmedName.trim().contains('.');
    if (!hasExtension) {
      _showToast(
        '⚠️ Arquivo sem extensão — o realce de sintaxe pode não funcionar.',
        type: _ToastType.info,
      );
    }

    if (_autoFormatOnSave) {
      _formatCode(silent: true);
    }

    // Resolve o diretório de destino:
    // 1. Se há projeto aberto, salva lá
    // 2. Caso contrário, salva na pasta de documentos do app
    String dirPath;
    if (_projectPath != null) {
      dirPath = _projectPath!;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dirPath = docDir.path;
    }

    final finalPath = p.join(dirPath, confirmedName.trim());
    debugPrint('JALIDE_SAVE_AS_PATH: $finalPath');

    try {
      final controller = _activeController!;
      final content = controller.text;
      _debugAutoSaveLog(
        'SEND',
        path: finalPath,
        textLen: content.length,
        textHash: content.hashCode,
        cursor: controller.selection.isValid
            ? controller.selection.baseOffset
            : -1,
        composing: controller.value.composing.isValid &&
            !controller.value.composing.isCollapsed,
      );
      final activeTab = _tabController.activeTab;
      // BUG1 FIX: usa _writeFileContent para suportar SSH/SAF corretamente
      await _writeFileContent(finalPath, content, activeTab?.isRemote ?? false);
      _tabController.updateTabPath(_tabController.activeTabIndex, finalPath);
      _tabController.updateTabLanguageFromPath(
        _tabController.activeTabIndex,
        finalPath,
      );
      final textMovedOn = controller.text != content;
      _debugAutoSaveLog(
        textMovedOn ? 'MARK_CLEAN_STALE' : 'MARK_CLEAN_OK',
        path: finalPath,
        textLen: controller.text.length,
        textHash: controller.text.hashCode,
        detail: textMovedOn ? 'texto mudou durante a gravacao' : null,
      );
      _tabController.markTabSaved(_tabController.activeTabIndex);
      _saveTabsPreference();
      // Atualiza o explorer se o arquivo foi salvo na pasta do projeto
      if (_projectPath != null) await _loadProjectFiles(_projectPath!);
      _showToast(
        'Salvo como ${p.basename(finalPath)}',
        type: _ToastType.success,
      );
    } catch (e) {
      _showToast('Erro ao salvar como: $e', type: _ToastType.error);
      debugPrint('JALIDE_SAVE_AS_ERROR: $e');
    }
  }

  // ─── Instrumentação temporária para caçar o bug de auto-save ───────────────
  // Remove estas helpers junto com os logs JALIDE_AUTOSAVE_DEBUG após o diagnóstico.
  static const bool _debugAutoSave = true;

  void _debugAutoSaveLog(
    String event, {
    String? path,
    int? textLen,
    int? textHash,
    int? cursor,
    bool? composing,
    bool? busy,
    int? diskLen,
    int? diskHash,
    String? detail,
  }) {
    if (!_debugAutoSave) return;
    final sb = StringBuffer('JALIDE_AUTOSAVE_DEBUG [$event]');
    sb.write(' path=${path ?? '-'}');
    if (textLen != null) sb.write(' textLen=$textLen');
    if (textHash != null) sb.write(' textHash=$textHash');
    if (cursor != null) sb.write(' cursor=$cursor');
    if (composing != null) sb.write(' composing=$composing');
    if (busy != null) sb.write(' busy=$busy');
    if (diskLen != null) sb.write(' diskLen=$diskLen');
    if (diskHash != null) sb.write(' diskHash=$diskHash');
    if (detail != null) sb.write(' detail=$detail');
    debugPrint(sb.toString());
  }

  String _diffSummary(String a, String b) {
    final len = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < len && a[i] == b[i]) {
      i++;
    }
    if (i >= len) return 'prefixo igual (len=$len)';
    final start = i - 20 < 0 ? 0 : i - 20;
    final endA = (i + 20) > a.length ? a.length : (i + 20);
    final endB = (i + 20) > b.length ? b.length : (i + 20);
    return 'firstDiff@$i esperado="...${a.substring(start, endA)}..." recebido="...${b.substring(start, endB)}..."';
  }

  Future<void> _verifyWrittenFile(String path, String expected, bool isRemote) async {
    try {
      String? onDisk;
      if (path.startsWith('content://')) {
        final result = await _termuxChannel.invokeMethod('readSafFile', {
          'uri': path,
        });
        if (result is String) onDisk = result;
      } else if (isRemote && _activeSshSession != null) {
        onDisk = await _activeSshSession!.readFile(path);
      } else {
        onDisk = await File(path).readAsString();
      }

      if (onDisk == null) {
        _debugAutoSaveLog('VERIFY_SKIP', path: path, detail: 'read-back indisponivel');
        return;
      }

      final ok = onDisk == expected;
      _debugAutoSaveLog(
        ok ? 'VERIFY_OK' : 'VERIFY_MISMATCH',
        path: path,
        textLen: expected.length,
        textHash: expected.hashCode,
        diskLen: onDisk.length,
        diskHash: onDisk.hashCode,
        detail: ok ? null : _diffSummary(expected, onDisk),
      );
    } catch (e) {
      _debugAutoSaveLog('VERIFY_ERROR', path: path, detail: '$e');
    }
  }
  // ─── Fim da instrumentação ─────────────────────────────────────────────────

  void _triggerAutoSave(EditorTab tab) {
    // BUG2 FIX: timer individual por path da aba, evita que a aba A cancele o save da aba B
    if (tab.path == null) return;

    final tabPath = tab.path!;
    _autoSaveTimers[tabPath]?.cancel();
    _autoSaveTimers[tabPath] = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      // Revalida o índice — o usuário pode ter fechado a aba enquanto o timer rodava
      final currentIndex = _tabController.openTabs.indexOf(tab);
      if (currentIndex == -1) {
        _autoSaveTimers.remove(tabPath);
        return;
      }

      final controller = tab.controller;
      final valueSnapshot = controller.value;

      _debugAutoSaveLog(
        'FIRE',
        path: tabPath,
        textLen: valueSnapshot.text.length,
        textHash: valueSnapshot.text.hashCode,
        cursor: valueSnapshot.selection.isValid
            ? valueSnapshot.selection.baseOffset
            : -1,
        composing: valueSnapshot.composing.isValid &&
            !valueSnapshot.composing.isCollapsed,
        busy: _currentSave != null,
        detail: tab.hasUnsavedChanges ? 'dirty' : 'clean',
      );

      if (_currentSave != null) {
        _debugAutoSaveLog('SKIP_BUSY', path: tabPath, busy: true);
        return;
      }

      if (tab.hasUnsavedChanges && tab.path != null) {
        final path = tab.path!;
        final isRemote = tab.isRemote;

        // Formata primeiro; _isFormatting suprime o loop de auto-save
        final isComposing = controller.value.composing.isValid &&
            !controller.value.composing.isCollapsed;

        if (_autoFormatOnSave &&
            currentIndex == _tabController.activeTabIndex &&
            !isComposing) {
          _formatCode(silent: true);
          // Aguarda o frame para que controller.text reflita o texto formatado
          await Future.microtask(() {});
          if (!mounted) return;
        }

        // Lê o texto DEPOIS da formatação
        final text = controller.text;

        _debugAutoSaveLog(
          'SEND',
          path: path,
          textLen: text.length,
          textHash: text.hashCode,
          cursor: controller.selection.isValid
              ? controller.selection.baseOffset
              : -1,
          composing: controller.value.composing.isValid &&
              !controller.value.composing.isCollapsed,
          busy: _currentSave != null,
        );

        final future = _writeFileContent(path, text, isRemote);
        _currentSave = future;
        try {
          await future;
          if (!mounted) return;

          final textMovedOn = controller.text != text;
          _debugAutoSaveLog(
            textMovedOn ? 'MARK_CLEAN_STALE' : 'MARK_CLEAN_OK',
            path: path,
            textLen: controller.text.length,
            textHash: controller.text.hashCode,
            detail: textMovedOn ? 'texto mudou durante a gravacao (digitou no meio do save)' : null,
          );

          _tabController.markTabSaved(currentIndex);
          _moduleManager.onAutoSaved(path);
        } catch (e) {
          debugPrint('Auto-save error: $e');
        } finally {
          _currentSave = null;
          _autoSaveTimers.remove(tabPath);
        }
      } else {
        _autoSaveTimers.remove(tabPath);
      }
    });
  }

  Future<void> _instantSaveTab(EditorTab tab) async {
    if (tab.hasUnsavedChanges && tab.path != null) {
      if (_currentSave != null) {
        _debugAutoSaveLog('AWAIT_BUSY', path: tab.path, busy: true);
        await _currentSave!;
        if (!mounted) return;
      }

      final path = tab.path!;
      final isRemote = tab.isRemote;

      final tabIndex = _tabController.openTabs.indexOf(tab);
      if (_autoFormatOnSave &&
          tabIndex != -1 &&
          tabIndex == _tabController.activeTabIndex) {
        _formatCode(silent: true);
        // Aguarda o frame para que controller.text reflita o texto formatado
        await Future.microtask(() {});
        if (!mounted) return;
      }

      final controller = tab.controller;
      // Lê o texto DEPOIS da formatação
      final text = controller.text;

      _debugAutoSaveLog(
        'SEND',
        path: path,
        textLen: text.length,
        textHash: text.hashCode,
        cursor: controller.selection.isValid
            ? controller.selection.baseOffset
            : -1,
        composing: controller.value.composing.isValid &&
            !controller.value.composing.isCollapsed,
        busy: _currentSave != null,
      );

      final future = _writeFileContent(path, text, isRemote);
      _currentSave = future;
      try {
        await future;
        if (!mounted) return;
        final currentTabIndex = _tabController.openTabs.indexOf(tab);
        if (currentTabIndex != -1) {
          final textMovedOn = controller.text != text;
          _debugAutoSaveLog(
            textMovedOn ? 'MARK_CLEAN_STALE' : 'MARK_CLEAN_OK',
            path: path,
            textLen: controller.text.length,
            textHash: controller.text.hashCode,
            detail: textMovedOn ? 'texto mudou durante a gravacao' : null,
          );
          _tabController.markTabSaved(currentTabIndex);
          _moduleManager.onAutoSaved(path);
        }
      } catch (e) {
        debugPrint('Instant save error: $e');
      } finally {
        _currentSave = null;
      }
    }
  }

  Future<void> _toggleAutoSave() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSaveEnabled = !_autoSaveEnabled;
    });
    await prefs.setBool('autosave_enabled', _autoSaveEnabled);
    _showToast(_autoSaveEnabled ? 'Auto-Save ativado' : 'Auto-Save desativado');
  }

  void _scrollHorizontalToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_horizontalScrollCtrl.hasClients) {
        try {
          _horizontalScrollCtrl.jumpTo(0);
        } catch (_) {}
      }
    });
  }

  void _insertSnippet(String snippet) {
    if (_tabController.activeTabIndex == -1) return;
    _tabController.forceRecordActiveTabHistory();
    final text = _activeController!.text;
    final sel = _activeController!.selection;

    // Proteção contra seleção inválida
    if (!sel.isValid) {
      final insert = snippet == '  ' ? '  ' : snippet.replaceAll(' ', '');
      _activeController!.text = text + insert;
      return;
    }

    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);

    // Descobre a indentação atual
    final linesBefore = before.split('\n');
    final currentLine = linesBefore.isNotEmpty ? linesBefore.last : '';
    final indentMatch = RegExp(r'^(\s*)').firstMatch(currentLine);
    final currentIndent = indentMatch?.group(1) ?? '';
    final innerIndent = '$currentIndent  ';

    final pairs = {
      '{ }': '{\n$innerIndent\n$currentIndent}',
      '[ ]': '[\n$innerIndent\n$currentIndent]',
      '( )': '()',
      '" "': '""',
      "' '": "''",
      '` `': '``',
      '  ': '  ',
    };

    final insert = pairs[snippet] ?? snippet.replaceAll(' ', '');
    _activeController!.text = before + insert + after;

    // Posiciona o cursor no meio dos blocos/aspas/crases
    int offset = sel.start + insert.length;
    if (snippet == '{ }' || snippet == '[ ]') {
      offset =
          sel.start + insert.indexOf('\n$innerIndent') + 1 + innerIndent.length;
    } else if (snippet == '( )' ||
        snippet == '" "' ||
        snippet == "' '" ||
        snippet == '` `') {
      offset = sel.start + 1;
    }

    _activeController!.selection = TextSelection.collapsed(offset: offset);
    _activeFocusNode!.requestFocus();
    if (snippet == '\n') {
      _scrollHorizontalToStart();
    }
  }

  void _handleAuxKeyTap(String key) {
    if (_isTerminalActive) {
      _handleTerminalKey(key);
      return;
    }

    if (_tabController.activeTabIndex == -1) return;

    if (key == 'Ctrl') {
      setState(() => _ctrlActive = !_ctrlActive);
      return;
    }

    if (_ctrlActive) {
      _handleCtrlShortcut(key);
      return;
    }

    _handleEditorKey(key);
  }

  // M4 FIX: usa null-safe para evitar crash quando _activeFocusNode é null
  bool get _isTerminalActive =>
      _isTerminalVisible &&
      _activeTerminalState != null &&
      (_tabController.activeTabIndex == -1 ||
          _activeFocusNode?.hasFocus != true);

  void _handleTerminalKey(String key) {
    if (key == 'Ctrl') {
      setState(() => _ctrlActive = !_ctrlActive);
      return;
    }

    if (_ctrlActive) {
      setState(() => _ctrlActive = false);
      if (key.startsWith('Z')) {
        _activeTerminalState!.sendInput('\x1a');
      } else if (key.startsWith('Y')) {
        _activeTerminalState!.sendInput('\x19');
      } else if (key.startsWith('A')) {
        _activeTerminalState!.sendInput('\x01');
      } else if (key.startsWith('C')) {
        _activeTerminalState!.sendInput('\x03');
        _showToast('Ctrl+C enviado');
      } else if (key.startsWith('V')) {
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          if (data?.text != null) {
            _activeTerminalState!.sendInput(data!.text!);
          }
        });
      } else if (key.startsWith('X')) {
        _activeTerminalState!.sendInput('\x18');
      } else if (key.startsWith('S')) {
        _activeTerminalState!.sendInput('\x13');
      }
      return;
    }

    switch (key) {
      case 'Tab':
        _activeTerminalState!.sendInput('\t');
        break;
      case '←':
        _activeTerminalState!.sendInput('\x1b[D');
        break;
      case '→':
        _activeTerminalState!.sendInput('\x1b[C');
        break;
      case '↑':
        _activeTerminalState!.sendInput('\x1b[A');
        break;
      case '↓':
        _activeTerminalState!.sendInput('\x1b[B');
        break;
      case 'BACKSPACE':
        _activeTerminalState!.sendInput('\x7f');
        break;
      case 'ESC':
        _activeTerminalState!.sendInput('\x1b');
        break;
      case 'HOME':
        _activeTerminalState!.sendInput('\x1b[H');
        break;
      case 'END':
        _activeTerminalState!.sendInput('\x1b[F');
        break;
      case 'ENTER':
        _activeTerminalState!.sendInput('\n');
        break;
      default:
        _activeTerminalState!.sendInput(key.replaceAll(' ', ''));
    }
  }

  void _handleCtrlShortcut(String key) {
    setState(() => _ctrlActive = false);

    if (key.startsWith('Z')) {
      _tabController.undoActiveTab();
    } else if (key.startsWith('Y')) {
      _tabController.redoActiveTab();
    } else if (key.startsWith('A')) {
      _activeController!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _activeController!.text.length,
      );
    } else if (key.startsWith('C')) {
      final sel = _activeController!.selection;
      if (sel.isValid && !sel.isCollapsed) {
        Clipboard.setData(
          ClipboardData(
            text: _activeController!.text.substring(sel.start, sel.end),
          ),
        );
        _showToast('Copiado');
      }
    } else if (key.startsWith('V')) {
      _pasteFromClipboard();
    } else if (key.startsWith('X')) {
      _cutSelection();
    } else if (key.startsWith('S')) {
      _saveFile();
    } else if (key == '↑ (MoveUp)') {
      _moveLineUp();
    } else if (key == '↓ (MoveDown)') {
      _moveLineDown();
    } else if (key.startsWith('D')) {
      _selectNextOrDuplicate();
    } else if (key.startsWith('F')) {
      _showFindReplace();
    } else if (key.startsWith('H')) {
      if (!_isFindReplaceVisible) {
        setState(() => _isFindReplaceVisible = true);
      }
    } else if (key.startsWith('G')) {
      _goToLine();
    } else if (key == '/ (Comment)') {
      _toggleComment();
    } else {
      // Atalhos registrados por módulos (ex: 'Ctrl+K') são tentados quando a
      // tecla não corresponde a nenhum atalho built-in
      final base = key.split(' ').first;
      _moduleManager.handleShortcut('Ctrl+$base');
    }
    _activeFocusNode!.requestFocus();
  }

  void _pasteFromClipboard() {
    _tabController.forceRecordActiveTabHistory();
    final controller = _activeController;
    if (controller == null) return;
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (data?.text != null && mounted) {
        final currentController = _activeController;
        if (currentController == null) return;
        final text = currentController.text;
        final sel = currentController.selection;
        if (sel.isValid) {
          currentController.value = currentController.value.copyWith(
            text:
                text.substring(0, sel.start) +
                data!.text! +
                text.substring(sel.end),
            selection: TextSelection.collapsed(
              offset: sel.start + data.text!.length,
            ),
          );
        }
      }
    });
  }

  void _cutSelection() {
    final controller = _activeController;
    if (controller == null) return;
    final sel = controller.selection;
    if (sel.isValid && !sel.isCollapsed) {
      _tabController.forceRecordActiveTabHistory();
      final text = controller.text;
      Clipboard.setData(
        ClipboardData(text: text.substring(sel.start, sel.end)),
      );
      controller.value = controller.value.copyWith(
        text: text.substring(0, sel.start) + text.substring(sel.end),
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _showToast('Recortado');
    }
  }

  void _duplicateLine() {
    _tabController.forceRecordActiveTabHistory();
    final controller = _activeController;
    if (controller == null) return;
    final text = controller.text;
    final sel = controller.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final lines = before.split('\n');
      final currentLine = lines.last;
      final lineStart = before.length - currentLine.length;
      final lineEnd = text.indexOf('\n', lineStart);
      final end = lineEnd == -1 ? text.length : lineEnd;
      final line = text.substring(lineStart, end);
      final newText = '${text.substring(0, end)}\n$line${text.substring(end)}';
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: end + 1 + line.length),
      );
    }
  }

  void _selectNextOrDuplicate() {
    final controller = _activeController;
    if (controller == null) return;
    final text = controller.text;
    final sel = controller.selection;

    if (sel.isValid && !sel.isCollapsed) {
      final selected = text.substring(sel.start, sel.end);
      if (selected.isEmpty) return;
      final fromPos = sel.end;
      final idx = text.indexOf(selected, fromPos);
      if (idx != -1) {
        controller.selection = TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: idx + selected.length,
        );
      } else {
        final wrapIdx = text.indexOf(selected, 0);
        if (wrapIdx != -1 && wrapIdx != sel.start) {
          controller.selection = TextSelection(
            baseOffset: sel.baseOffset,
            extentOffset: wrapIdx + selected.length,
          );
        } else {
          _showToast('Nenhuma outra ocorrência encontrada');
        }
      }
    } else {
      _duplicateLine();
    }
  }

  void _moveLineUp() {
    final controller = _activeController;
    if (controller == null) return;
    _tabController.forceRecordActiveTabHistory();
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;

    final before = text.substring(0, sel.start);
    final lines = before.split('\n');
    if (lines.length < 2) return;

    final currentLineIdx = lines.length - 1;
    final currentLine = lines[currentLineIdx];
    final prevLine = lines[currentLineIdx - 1];

    final lineStart = before.length - currentLine.length;
    final prevLineStart = lineStart - prevLine.length - 1;

    final newText =
        '${text.substring(0, prevLineStart)}$currentLine\n$prevLine${text.substring(lineStart + currentLine.length)}';

    final offsetDiff = currentLine.length + 1;
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (sel.start - offsetDiff).clamp(0, newText.length),
      ),
    );
  }

  void _moveLineDown() {
    final controller = _activeController;
    if (controller == null) return;
    _tabController.forceRecordActiveTabHistory();
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;

    final before = text.substring(0, sel.start);
    final lines = before.split('\n');
    final currentLineIdx = lines.length - 1;
    final currentLine = lines[currentLineIdx];

    final lineStart = before.length - currentLine.length;
    final lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1 || lineEnd >= text.length - 1) return;

    final nextLineEnd = text.indexOf('\n', lineEnd + 1);
    final end = nextLineEnd == -1 ? text.length : nextLineEnd;
    final nextLine = text.substring(lineEnd + 1, end);

    final newText =
        '${text.substring(0, lineStart)}$nextLine\n$currentLine${text.substring(end)}';

    final offsetDiff = nextLine.length + 1;
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (sel.start + offsetDiff).clamp(0, newText.length),
      ),
    );
  }

  void _handleEditorKey(String key) {
    switch (key) {
      case 'Tab':
        _insertSnippet('  ');
        break;
      case '←':
        _moveCursorLeft();
        break;
      case '→':
        _moveCursorRight();
        break;
      case '↑':
        _moveCursorUp();
        break;
      case '↓':
        _moveCursorDown();
        break;
      case 'BACKSPACE':
        _handleBackspace();
        break;
      case 'HOME':
        _moveToLineStart();
        break;
      case 'END':
        _moveToLineEnd();
        break;
      case 'ENTER':
        _insertSnippet('\n');
        break;
      case 'SEL_UP':
        _extendSelectionUp();
        break;
      case 'SEL_DOWN':
        _extendSelectionDown();
        break;
      case 'ESC':
        _activeFocusNode!.unfocus();
        return;
      case '🔍':
        _showFindReplace();
        return;
      case '//':
        _toggleComment();
        return;
      case '⊞':
        _showCommandPalette();
        return;
      default:
        _insertSnippet(key);
    }
    _activeFocusNode!.requestFocus();
  }

  void _moveCursorLeft() {
    final sel = _activeController!.selection;
    if (sel.isValid && sel.start > 0) {
      _activeController!.selection = TextSelection.collapsed(
        offset: sel.start - 1,
      );
    }
  }

  void _moveCursorRight() {
    final sel = _activeController!.selection;
    if (sel.isValid && sel.start < _activeController!.text.length) {
      _activeController!.selection = TextSelection.collapsed(
        offset: sel.start + 1,
      );
    }
  }

  void _moveCursorUp() {
    final controller = _activeController;
    if (controller == null) return;
    final text = controller.text;
    final sel = controller.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final lines = before.split('\n');
      if (lines.length > 1) {
        final col = lines.last.length;
        final prevLine = lines[lines.length - 2];
        final prevStart = (before.length - col - 1 - prevLine.length).clamp(
          0,
          before.length,
        );
        controller.selection = TextSelection.collapsed(
          offset: prevStart + col.clamp(0, prevLine.length),
        );
      }
    }
  }

  void _moveCursorDown() {
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final after = text.substring(sel.start);
      final col = before.split('\n').last.length;
      final afterLines = after.split('\n');
      if (afterLines.length > 1) {
        final nextLine = afterLines[1];
        final nextStart = before.length + afterLines[0].length + 1;
        _activeController!.selection = TextSelection.collapsed(
          offset: nextStart + col.clamp(0, nextLine.length),
        );
      }
    }
  }

  void _handleBackspace() {
    final sel = _activeController!.selection;
    if (sel.isValid) {
      _tabController.forceRecordActiveTabHistory();
      final text = _activeController!.text;
      if (!sel.isCollapsed) {
        _activeController!.value = _activeController!.value.copyWith(
          text: text.substring(0, sel.start) + text.substring(sel.end),
          selection: TextSelection.collapsed(offset: sel.start),
        );
      } else if (sel.start > 0) {
        _activeController!.value = _activeController!.value.copyWith(
          text: text.substring(0, sel.start - 1) + text.substring(sel.start),
          selection: TextSelection.collapsed(offset: sel.start - 1),
        );
      }
    }
  }

  void _moveToLineStart() {
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final lineStart = before.lastIndexOf('\n') + 1;
      _activeController!.selection = TextSelection.collapsed(offset: lineStart);
    }
  }

  void _moveToLineEnd() {
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final after = text.substring(sel.start);
      final lineEnd = after.indexOf('\n');
      final offset = lineEnd == -1 ? text.length : sel.start + lineEnd;
      _activeController!.selection = TextSelection.collapsed(offset: offset);
    }
  }

  void _extendSelectionUp() {
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final lines = before.split('\n');
      if (lines.length > 1) {
        final col = lines.last.length;
        final prevLine = lines[lines.length - 2];
        final prevStart = before.length - col - 1 - prevLine.length;
        _activeController!.selection = TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: prevStart + col.clamp(0, prevLine.length),
        );
      }
    }
  }

  void _extendSelectionDown() {
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.extentOffset);
      final after = text.substring(sel.extentOffset);
      final col = before.split('\n').last.length;
      final afterLines = after.split('\n');
      if (afterLines.length > 1) {
        final nextLine = afterLines[1];
        final nextStart = before.length + afterLines[0].length + 1;
        _activeController!.selection = TextSelection(
          baseOffset: sel.baseOffset,
          extentOffset: nextStart + col.clamp(0, nextLine.length),
        );
      }
    }
  }

  Future<void> _toggleGhostSuggestions() async {
    final newValue = !_ghostSuggestionsEnabled;
    setState(() => _ghostSuggestionsEnabled = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ghost_suggestions_enabled', newValue);
    _showToast(
      newValue ? '✨ Sugestões IA ativadas' : '🚫 Sugestões IA desativadas',
    );
  }

  void _formatCode({bool silent = false}) {
    if (_tabController.activeTabIndex == -1) return;

    final controller = _activeController!;
    final text = controller.text;
    if (text.isEmpty) return;

    final lang = _tabController.languageName;

    try {
      var formatted = CodeFormatter.format(text, lang);

      if (formatted != text) {
        _tabController.forceRecordActiveTabHistory();
        final selection = controller.selection;

        // Preserva os espaços trailing que o formatter removeria com trim().
        // O formato nunca deve remover caracteres do arquivo — apenas
        // corrigir indentação. Se após a preservação o texto for idêntico,
        // nada é aplicado (sem mexer no cursor).
        final origLines = text.split('\n');
        final trailingOf = <String>[
          for (final l in origLines) l.substring(l.trimRight().length),
        ];
        final Map<int, String> preserve = {};
        for (int i = 0; i < trailingOf.length; i++) {
          if (trailingOf[i].isNotEmpty) preserve[i] = trailingOf[i];
        }

        if (preserve.isNotEmpty) {
          final fmtLines = formatted.split('\n');
          preserve.forEach((i, ws) {
            if (i < fmtLines.length) {
              fmtLines[i] = fmtLines[i] + ws;
            }
          });
          formatted = fmtLines.join('\n');
        }

        // Se a única mudança do formatter era espaço trailing (agora
        // preservado), não há o que aplicar — evita tocar no texto/cursor.
        if (formatted == text) {
          if (!silent) {
            _showToast('O código já está formatado');
          }
          return;
        }

        TextSelection newSelection;
        if (selection.isValid) {
          if (selection.isCollapsed) {
            final newOffset = CodeFormatter.getFormattedOffset(
              text,
              formatted,
              selection.baseOffset,
            );
            newSelection = TextSelection.collapsed(offset: newOffset);
          } else {
            final newBase = CodeFormatter.getFormattedOffset(
              text,
              formatted,
              selection.baseOffset,
            );
            final newExtent = CodeFormatter.getFormattedOffset(
              text,
              formatted,
              selection.extentOffset,
            );
            newSelection = TextSelection(
              baseOffset: newBase,
              extentOffset: newExtent,
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            );
          }
        } else {
          newSelection = TextSelection.collapsed(offset: formatted.length);
        }

        _isFormatting = true;
        try {
          controller.value = controller.value.copyWith(
            text: formatted,
            selection: newSelection,
            composing: TextRange.empty,
          );
        } finally {
          _isFormatting = false;
        }

        if (!silent) {
          _showToast('Código formatado com sucesso', type: _ToastType.success);
        }
      } else {
        if (!silent) {
          _showToast('O código já está formatado');
        }
      }
    } catch (e) {
      if (!silent) {
        _showToast('Erro ao formatar: $e', type: _ToastType.error);
      }
    }
  }

  Future<void> _toggleAutoFormatOnSave() async {
    final newValue = !_autoFormatOnSave;
    setState(() => _autoFormatOnSave = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoformat_on_save', newValue);
    _showToast(
      newValue
          ? '🧹 Auto-Format ao salvar ativado'
          : '🚫 Auto-Format desativado',
    );
  }

  void _showToast(String msg, {_ToastType type = _ToastType.info}) {
    if (!mounted) return;

    final snackBarTheme = switch (type) {
      _ToastType.success => _SnackBarStyle(
        backgroundColor: const Color(0xFF1F8B4C),
        iconColor: Colors.white,
        textColor: Colors.white,
        icon: Icons.check_circle_outline,
      ),
      _ToastType.error => _SnackBarStyle(
        backgroundColor: const Color(0xFFF7768E).withValues(alpha: 0.95),
        iconColor: Colors.white,
        textColor: Colors.white,
        icon: Icons.error_outline,
      ),
      _ToastType.info => _SnackBarStyle(
        backgroundColor: _theme.surface,
        iconColor: _theme.accent,
        textColor: _theme.textPri,
        icon: Icons.info_outline,
      ),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(snackBarTheme.icon, color: snackBarTheme.iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: snackBarTheme.textColor,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: snackBarTheme.iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                icon: Icon(
                  Icons.close,
                  color: snackBarTheme.iconColor,
                  size: 18,
                ),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Fechar',
              ),
            ),
          ],
        ),
        backgroundColor: snackBarTheme.backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: type == _ToastType.info
                ? _theme.accent
                : snackBarTheme.iconColor,
            width: 1,
          ),
        ),
        duration: type == _ToastType.error
            ? const Duration(seconds: 6)
            : const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _deleteItem(
    String path,
    bool isDir,
    bool isRemote,
    bool isSaf,
  ) async {
    if (isSaf) {
      _showToast('Exclusão via SAF ainda não está disponível');
      return;
    }

    final affectedCurrentFile =
        _activePath != null &&
        (_activePath == path || (isDir && _activePath!.startsWith('$path/')));

    if (affectedCurrentFile && _tabController.hasUnsavedChanges) {
      _showToast('Salve ou feche a aba antes de excluir este item');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _theme.surface,
        title: Text(
          'Excluir ${isDir ? 'pasta' : 'arquivo'}',
          style: TextStyle(color: _theme.textPri),
        ),
        content: Text(
          'Deseja realmente excluir "${p.basename(path)}"?',
          style: TextStyle(color: _theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: _theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      if (isRemote && _activeSshSession != null) {
        await _activeSshSession!.deletePath(path, isDir: isDir);
      } else {
        if (isDir) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      }

      // BUG5 FIX: fecha TODAS as abas cujos arquivos estão dentro do item deletado
      if (isDir) {
        // Coleta todos os índices afetados (em ordem decrescente para fechar sem shift)
        final affectedIndices = <int>[];
        for (int i = 0; i < _tabController.openTabs.length; i++) {
          final tabPath = _tabController.openTabs[i].path;
          if (tabPath != null &&
              (tabPath == path || tabPath.startsWith('$path/'))) {
            affectedIndices.add(i);
          }
        }
        // Fecha do maior para o menor índice para não deslocar os anteriores
        for (final idx in affectedIndices.reversed) {
          _tabController.closeTab(idx);
        }
      } else if (affectedCurrentFile && _tabController.activeTabIndex != -1) {
        _closeTab(_tabController.activeTabIndex);
      }

      final refreshPath = isRemote ? p.posix.dirname(path) : p.dirname(path);
      if (isRemote) {
        await _loadRemoteProjectFiles(refreshPath);
      } else {
        await _loadProjectFiles(refreshPath);
      }

      _showToast(
        '${isDir ? 'Pasta' : 'Arquivo'} excluído com sucesso',
        type: _ToastType.success,
      );
    } catch (e) {
      _showToast('Erro ao excluir: $e', type: _ToastType.error);
    }
  }

  Future<void> _renameItem(
    String path,
    String newName,
    bool isDir,
    bool isRemote,
    bool isSaf,
  ) async {
    if (isSaf) {
      _showToast('Renomear via SAF ainda não está disponível');
      return;
    }

    try {
      final parentDir = isRemote ? p.posix.dirname(path) : p.dirname(path);
      final newPath = isRemote
          ? p.posix.join(parentDir, newName)
          : p.join(parentDir, newName);

      if (isRemote && _activeSshSession != null) {
        await _activeSshSession!.renamePath(path, newPath);
      } else {
        if (isDir) {
          await Directory(path).rename(newPath);
        } else {
          await File(path).rename(newPath);
        }
      }

      if (!isDir &&
          _activePath == path &&
          _tabController.activeTabIndex != -1) {
        _tabController.updateTabPath(_tabController.activeTabIndex, newPath);
      }

      final refreshPath = isRemote ? p.posix.dirname(path) : p.dirname(path);
      if (isRemote) {
        await _loadRemoteProjectFiles(refreshPath);
      } else {
        await _loadProjectFiles(refreshPath);
      }

      _showToast(
        '${isDir ? 'Pasta' : 'Arquivo'} renomeado com sucesso',
        type: _ToastType.success,
      );
    } catch (e) {
      _showToast('Erro ao renomear: $e', type: _ToastType.error);
    }
  }

  Future<void> _pickProjectFolder() async {
    if (Platform.isAndroid) {
      // Só pede permissão se ainda não tiver sido concedida
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          _showToast('Permissão de armazenamento negada');
          return;
        }
      }
    }

    String? path;
    if (Platform.isAndroid) {
      // Usa o seletor nativo SAF que implementamos para garantir a URI content://
      path = await _termuxChannel.invokeMethod('pickSafDirectory');
    } else {
      path = await FilePicker.getDirectoryPath();
    }

    if (path == null) {
      _showToast('Nenhuma pasta selecionada');
      return;
    }

    debugPrint('JALIDE_PROJECT_PATH: $path');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_project_path', path);
    await _loadProjectFiles(path);
  }

  // ─── Integração Termux ──────────────────────────────────────────────────
  static const _termuxHome = '/data/data/com.termux/files/home';
  static const _jalideWorkspace = '/sdcard/jalide-workspace';
  static const _termuxChannel = FileService.channel;

  Future<void> _openTermuxWorkspace() async {
    final pathCtrl = TextEditingController(text: '~/');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool copied = false;
        return AlertDialog(
          backgroundColor: _theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Workspace Termux',
                style: TextStyle(color: _theme.textPri, fontSize: 15),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O JALIDE vai pedir ao Termux para criar um link seguro da sua pasta no /sdcard/, tornando-a editável.',
                style: TextStyle(
                  color: _theme.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pathCtrl,
                autofocus: true,
                style: TextStyle(
                  color: _theme.textPri,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: 'Pasta no Termux',
                  hintText: '~/projetos/meu-app',
                  labelStyle: TextStyle(color: _theme.textMuted),
                  hintStyle: TextStyle(color: _theme.textMuted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _theme.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: const Color(0xFF4CAF50)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StatefulBuilder(
                builder: (ctx2, setLocalState) {
                  const setupCmd =
                      'echo "allow-external-apps = true" >> ~/.termux/termux.properties\n'
                      'termux-setup-storage';
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pré-requisito (uma vez no Termux):',
                                style: TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await Clipboard.setData(
                                  const ClipboardData(text: setupCmd),
                                );
                                if (ctx2.mounted) {
                                  setLocalState(() => copied = true);
                                }
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (ctx2.mounted) {
                                    setLocalState(() => copied = false);
                                  }
                                });
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: copied
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        key: ValueKey('check'),
                                        size: 16,
                                        color: Color(0xFF4CAF50),
                                      )
                                    : const Icon(
                                        Icons.copy_rounded,
                                        key: ValueKey('copy'),
                                        size: 16,
                                        color: Color(0xFF4CAF50),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          setupCmd,
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: _theme.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Criar Link e Abrir',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Resolve o caminho real no Termux
    String termuxPath = pathCtrl.text.trim();
    if (termuxPath == '~' || termuxPath == '~/') {
      termuxPath = _termuxHome;
    } else if (termuxPath.startsWith('~/')) {
      termuxPath = '$_termuxHome/${termuxPath.substring(2)}';
    } else if (!termuxPath.startsWith('/')) {
      termuxPath = '$_termuxHome/$termuxPath';
    }
    // Remove barra final
    termuxPath = termuxPath.endsWith('/')
        ? termuxPath.substring(0, termuxPath.length - 1)
        : termuxPath;

    final folderName = p.basename(termuxPath).isEmpty
        ? 'home'
        : p.basename(termuxPath);
    final symlinkTarget = '$_jalideWorkspace/$folderName';

    // Script bash: cria workspace e o link
    final script =
        'mkdir -p $_jalideWorkspace && '
        'rm -f "$symlinkTarget" && '
        'ln -s "$termuxPath" "$symlinkTarget"';

    debugPrint('JALIDE_TERMUX_SCRIPT: $script');
    _showToast('Enviando comando ao Termux...');

    try {
      if (Platform.isAndroid) {
        await _termuxChannel.invokeMethod('runTermuxCommand', {
          'script': script,
        });
      }
    } catch (e) {
      _showToast(
        'Erro ao enviar para o Termux: $e\nVerifique se o Termux está instalado.',
      );
      debugPrint('JALIDE_TERMUX_INTENT_ERROR: $e');
      return;
    }

    // Aguarda o Termux processar o script
    _showToast('Aguardando Termux criar o link...');
    await Future.delayed(const Duration(seconds: 2));

    final symlinkDir = Directory(symlinkTarget);
    if (await symlinkDir.exists()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_project_path', symlinkTarget);
      await _loadProjectFiles(symlinkTarget);
      _showToast('✅ Workspace "$folderName" aberto!', type: _ToastType.success);
    } else {
      // Tenta mais uma vez com delay maior
      await Future.delayed(const Duration(seconds: 3));
      if (await symlinkDir.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_project_path', symlinkTarget);
        await _loadProjectFiles(symlinkTarget);
        _showToast(
          '✅ Workspace "$folderName" aberto!',
          type: _ToastType.success,
        );
      } else {
        _showToast(
          '⚠️ Link não criado. Verifique:\n'
          '1. allow-external-apps = true no Termux\n'
          '2. termux-setup-storage foi executado\n'
          '3. Reinicie o Termux após configurar',
        );
      }
    }
  }

  Future<void> _showCreateDialog(bool isFile, String? basePath) async {
    final controller = TextEditingController();

    String displayPath = 'raiz';
    if (basePath != null && _projectPath != null && basePath != _projectPath) {
      try {
        if (_isRemoteProject) {
          displayPath = p.posix.relative(basePath, from: _projectPath);
        } else {
          displayPath = p.relative(basePath, from: _projectPath);
        }
      } catch (e) {
        displayPath = p.basename(basePath);
      }
    }

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _theme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFile ? 'Novo arquivo' : 'Nova pasta',
              style: TextStyle(color: _theme.textPri),
            ),
            const SizedBox(height: 4),
            Text(
              'Em: $displayPath',
              style: TextStyle(
                color: _theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _theme.textPri, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: isFile ? 'nome_do_arquivo.js' : 'nome_da_pasta',
            hintStyle: TextStyle(color: _theme.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _theme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _theme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: _theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Criar', style: TextStyle(color: _theme.accent)),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await _createNewEntity(name.trim(), isFile, basePath: basePath);
    }
  }

  Future<void> _createNewEntity(
    String name,
    bool isFile, {
    String? basePath,
  }) async {
    final targetBasePath = basePath ?? _projectPath;
    if (targetBasePath == null) return;
    final path = p.join(targetBasePath, name);

    try {
      if (_isRemoteProject && _activeSshSession != null) {
        if (isFile) {
          await _activeSshSession!.writeFile(path, '');
          await _loadRemoteProjectFiles(_projectPath!);
          _addTab(path, '', isRemote: true);
          _showToast('Arquivo remoto criado: $name', type: _ToastType.success);
        } else {
          // Nota: O SFTP do dartssh2 não tem mkdir direto exposto no SshSession
          // Mas podemos usar o shell ou implementar mkdir no SshSession.
          // Vou usar o SshSession e adicionar um método mkdir lá.
          await _activeSshSession!.mkdir(path);
          await _loadRemoteProjectFiles(_projectPath!);
          _showToast('Pasta remota criada: $name', type: _ToastType.success);
        }
        return;
      }

      if (isFile) {
        debugPrint('JALIDE_CREATE_FILE: $path');
        final file = File(path);
        if (await file.exists()) {
          _showToast('Arquivo já existe');
          return;
        }
        await file.create(recursive: true);
        await _loadProjectFiles(_projectPath!);
        _addTab(path, ''); // Abre o novo arquivo
        _showToast('Arquivo criado: $name', type: _ToastType.success);
      } else {
        final dir = Directory(path);
        if (await dir.exists()) {
          _showToast('Pasta já existe');
          return;
        }
        await dir.create();
        await _loadProjectFiles(_projectPath!);
      }
    } catch (e) {
      _showToast('Erro ao criar: $e', type: _ToastType.error);
    }
  }

  // _langForPath movido para EditorTabController.langForPath()

  /// Banner exibido quando há projeto remoto aberto mas SSH está desconectado.
  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: const Color(0xFF8B6914).withValues(alpha: 0.85),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFFFC107),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '✏️ Modo offline — editando cópia local. SSH será restaurado automaticamente.',
              style: TextStyle(
                color: Color(0xFFFFECB3),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final success = await _sshConnectionManager.reconnectNow();
              if (mounted) {
                _showToast(
                  success ? '✅ Reconectado!' : '❌ Falha ao reconectar',
                  type: success ? _ToastType.success : _ToastType.error,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFC107), width: 0.8),
              ),
              child: const Text(
                'Reconectar',
                style: TextStyle(
                  color: Color(0xFFFFC107),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sheet de opções SSH — aberto ao tocar no chip da status bar.
  void _showSshStatusSheet(BuildContext context) {
    final session = _sshConnectionManager.currentSession;
    final label = session?.profile.label ?? 'SSH';
    final isConnected = session?.isConnected ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: isConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF9E9E9E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: _theme.textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'conectado' : 'desconectado',
                  style: TextStyle(
                    color: isConnected
                        ? const Color(0xFF4CAF50)
                        : _theme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isConnected)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.refresh_rounded,
                  color: _theme.textPri,
                  size: 20,
                ),
                title: Text(
                  'Reconectar agora',
                  style: TextStyle(color: _theme.textPri),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await _sshConnectionManager.reconnectNow();
                  if (mounted) {
                    _showToast(
                      success ? '✅ Reconectado!' : '❌ Falha ao reconectar',
                      type: success ? _ToastType.success : _ToastType.error,
                    );
                  }
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.power_settings_new_rounded,
                color: _theme.textMuted,
                size: 20,
              ),
              title: Text(
                'Desconectar',
                style: TextStyle(color: _theme.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _sshConnectionManager.disconnect();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateActiveControllerListener();
    final isDarkTheme = ThemeProvider.of(context).themeType != ThemeType.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (isDarkTheme ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: _theme.bg,
                statusBarIconBrightness: isDarkTheme
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: _theme.surface,
                systemNavigationBarIconBrightness: isDarkTheme
                    ? Brightness.light
                    : Brightness.dark,
              ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _theme.bg,
        appBar: _buildAppBar(),
        drawer: FileExplorerDrawer(
          projectPath: _projectPath,
          projectFiles: _projectFiles,
          onFileTap: _openFileFromExplorer,
          onNavigateFolder: (path) {
            if (_isRemoteProject) {
              _loadRemoteProjectFiles(path);
            } else {
              _loadProjectFiles(path);
            }
          },
          onPickFolder: _pickProjectFolder,
          onOpenTermux: _openTermuxWorkspace,
          onCreateFile: (basePath) => _showCreateDialog(true, basePath),
          onCreateFolder: (basePath) => _showCreateDialog(false, basePath),
          onDeleteItem: _deleteItem,
          onRenameItem: _renameItem,
          termuxChannel: _termuxChannel,
          sshSession: _activeSshSession,
          isRemoteProject: _isRemoteProject,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de modo offline: projeto remoto sem conexão ativa
            // (banner sutil substituiu a faixa SSH do topo)
            if (_isRemoteProject &&
                _activeSshSession != null &&
                !(_activeSshSession!.isConnected))
              _buildOfflineBanner(),
            if (_projectConfig != null)
              EnvironmentStatusBar(
                projectConfig: _projectConfig!,
                orchestrator: _environmentOrchestrator,
                onUndo: () => _tabController.undoActiveTab(),
                onRedo: () => _tabController.redoActiveTab(),
                canUndo: _tabController.canUndoActiveTab,
                canRedo: _tabController.canRedoActiveTab,
              ),
            if (_tabController.hasTabs)
              EditorTabsBar(
                tabs: _tabController.openTabs,
                activeIndex: _tabController.activeTabIndex,
                onTabTap: (i) {
                  final activeIdx = _tabController.activeTabIndex;
                  if (activeIdx != -1 && activeIdx != i) {
                    _instantSaveTab(_tabController.openTabs[activeIdx]);
                  }
                  _tabController.setActiveTab(i);
                  _saveTabsPreference();
                },
                onCloseTab: _closeTab,
              ),
            if (_isFindReplaceVisible && _activeController != null)
              FindReplaceBar(
                editorController: _activeController!,
                onClose: () => setState(() => _isFindReplaceVisible = false),
                theme: _theme,
              ),
            Expanded(
              child: Stack(
                children: [
                  _buildEditor(),
                  if (_hasTerminalBeenOpened)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Visibility(
                        visible: _isTerminalVisible,
                        maintainState: true,
                        child: TerminalPanel(
                          key: ValueKey(
                            'term_${_terminalMode.name}_${_activeSshSession?.profile.id}',
                          ),
                          onClose: () =>
                              setState(() => _isTerminalVisible = false),
                          mode: _terminalMode,
                          sshSession: _activeSshSession,
                          projectPath: _projectPath,
                          onTerminalStateChanged: (handler) {
                            if (handler != null) {
                              _activeTerminalState = handler;
                            } else {
                              _activeTerminalState = null;
                            }
                          },
                        ),
                      ),
                    ),
                  if (_tabController.activeTabIndex != -1 &&
                      !_isTerminalVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: GhostSuggestionBar(
                        key: ValueKey('ghost_${_tabController.activeTabIndex}'),
                        controller: _activeController!,
                        languageName: _tabController.languageName,
                        enabled: _ghostSuggestionsEnabled,
                        aiService: _aiService,
                      ),
                    ),
                ],
              ),
            ),
            if (_showAuxKeyboard)
              AuxKeyboard(
                auxKeys: _currentAuxKeys,
                ctrlActive: _ctrlActive,
                onKeyTap: _handleAuxKeyTap,
                isTerminalMode: _isTerminalActive,
                onClose: () {
                  setState(() {
                    _showAuxKeyboard = false;
                  });
                },
              ),
            StatusBar(
              languageName: _languageName,
              hasUnsavedChanges: _activeHasUnsavedChanges,
              isTerminalVisible: _isTerminalVisible,
              isAuxKeyboardVisible: _showAuxKeyboard,
              isRemoteProject: _isRemoteProject,
              onAuxKeyboardToggle: () {
                setState(() {
                  _showAuxKeyboard = !_showAuxKeyboard;
                });
              },
              extraItems: _moduleManager.allStatusBarItems,
              sshConnectionManager: _isRemoteProject
                  ? _sshConnectionManager
                  : null,
              onSshTap: _isRemoteProject
                  ? () => _showSshStatusSheet(context)
                  : null,
              onTerminalToggle: () {
                setState(() {
                  _isTerminalVisible = !_isTerminalVisible;
                  if (_isTerminalVisible) {
                    _hasTerminalBeenOpened = true;
                  }
                });
                _moduleManager.onTerminalToggled(_isTerminalVisible);
              },
              onLanguageTap: _showLanguageSelector,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _theme.surface,
      elevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: _theme.textMuted, size: 20),
          onPressed: () {
            _activeFocusNode
                ?.unfocus(); // #15 FIX: fecha teclado ao abrir drawer
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _theme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fileName,
                          style: TextStyle(
                            color: _theme.textPri,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (_activeHasUnsavedChanges) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _theme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_activePath != null)
                    Text(
                      _projectPath != null &&
                              _activePath!.startsWith(_projectPath!)
                          ? _activePath!
                                .substring(_projectPath!.length)
                                .replaceFirst(RegExp(r'^[\/]'), '')
                          : _activePath!,
                      style: TextStyle(
                        color: _theme.textMuted,
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _tabController.activeTabIndex != -1
              ? _runActiveFile
              : null,
          icon: Icon(
            Icons.play_arrow_rounded,
            size: 24,
            color: _tabController.activeTabIndex != -1
                ? const Color(0xFF50FA7B)
                : _theme.textMuted,
          ),
          tooltip: _tabController.activeTabIndex != -1
              ? AppLocalizations.of(context)!.runFile
              : AppLocalizations.of(context)!.openFileToRun,
        ),

        IconButton(
          onPressed: _tabController.activeTabIndex != -1 ? _saveFile : null,
          icon: Icon(
            Icons.save_outlined,
            size: 20,
            color:
                _tabController.activeTabIndex != -1 && _activeHasUnsavedChanges
                ? _theme.accent
                : _theme.textMuted,
          ),
          tooltip: AppLocalizations.of(context)!.save,
        ),
        IconButton(
          onPressed: _openAIPanel,
          icon: Icon(
            Icons.auto_awesome_rounded,
            size: 20,
            color: Colors.amber[600],
          ),
          tooltip: AppLocalizations.of(context)!.aiAssistant,
        ),
        ..._moduleManager.allAppBarActions,
        PopupMenuButton<String>(
          color: _theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: _theme.border),
          ),
          onSelected: (v) async {
            switch (v) {
              case 'new':
                _tabController.createNewTab();
                break;
              case 'save_as':
                await _saveFileAs();
                break;
              case 'theme':
                _showThemeDialog();
                break;
              case 'zoom_in':
                _updateFontSize(_fontSize + 2);
                break;
              case 'zoom_out':
                _updateFontSize(_fontSize - 2);
                break;
              case 'ssh':
                _openSshScreen();
                break;
              case 'plugins':
                _showPluginManager();
                break;
              case 'autosave':
                _toggleAutoSave();
                break;
              case 'autoformat':
                _toggleAutoFormatOnSave();
                break;
              case 'format':
                _formatCode();
                break;
              case 'ghost':
                _toggleGhostSuggestions();
                break;
              case 'ai_settings':
                _showAISettingsDialog();
                break;
              case 'help':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                );
                break;
              case 'about':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
                break;
              case 'exit':
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _theme.surface,
                    title: Text(
                      AppLocalizations.of(context)!.exitConfirmTitle,
                      style: TextStyle(color: _theme.textPri),
                    ),
                    content: Text(
                      AppLocalizations.of(context)!.exitConfirmMessage,
                      style: TextStyle(color: _theme.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(color: _theme.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          SystemNavigator.pop();
                        },
                        child: Text(
                          AppLocalizations.of(context)!.exit,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return [
              // ── Arquivo
              _menuItem('new', l10n.newFile, Icons.add_outlined),
              _menuItem('save_as', l10n.saveAs, Icons.save_as_outlined),
              const PopupMenuDivider(),
              // ── Editor
              _menuItem('zoom_in', l10n.increaseFont, Icons.zoom_in),
              _menuItem('zoom_out', l10n.decreaseFont, Icons.zoom_out),
              _menuItem(
                'format',
                l10n.formatCode,
                Icons.format_align_left_outlined,
              ),
              _menuItem(
                'autosave',
                _autoSaveEnabled ? l10n.autoSaveOn : l10n.autoSaveOff,
                _autoSaveEnabled
                    ? Icons.toggle_on_outlined
                    : Icons.toggle_off_outlined,
              ),
              _menuItem(
                'autoformat',
                _autoFormatOnSave ? l10n.autoFormatOn : l10n.autoFormatOff,
                _autoFormatOnSave
                    ? Icons.align_horizontal_left
                    : Icons.align_horizontal_left_outlined,
              ),
              const PopupMenuDivider(),
              // ── IA
              _menuItem(
                'ai_settings',
                l10n.aiSettings,
                Icons.settings_outlined,
              ),
              _menuItem(
                'ghost',
                _ghostSuggestionsEnabled
                    ? l10n.ghostSuggestionsOn
                    : l10n.ghostSuggestionsOff,
                _ghostSuggestionsEnabled
                    ? Icons.auto_awesome
                    : Icons.auto_awesome_outlined,
              ),
              const PopupMenuDivider(),
              // ── Sessão & Suporte
              _menuItem('ssh', l10n.sshRemote, Icons.cloud_outlined),
              _menuItem('theme', l10n.changeTheme, Icons.palette_outlined),
              _menuItem('plugins', 'Plugins', Icons.extension_rounded),
              _menuItem('help', 'Ajuda', Icons.help_outline_rounded),
              _menuItem('about', l10n.about, Icons.info_outline),
              const PopupMenuDivider(),
              _menuItem('exit', l10n.exitApp, Icons.exit_to_app),
            ];
          },
          icon: Icon(Icons.more_vert, color: _theme.textMuted, size: 20),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _theme.border),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String val, String label, IconData icon) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16, color: _theme.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: _theme.textPri,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabController.tabCount) return;
    final tab = _tabController.openTabs[index];
    final bool hasUnsaved = tab.hasUnsavedChanges;

    void proceedClose() {
      _tabController.closeTab(index);
    }

    if (hasUnsaved) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _theme.surface,
          title: Text(
            AppLocalizations.of(context)!.unsavedChanges,
            style: TextStyle(color: _theme.textPri),
          ),
          content: Text(
            AppLocalizations.of(context)!.closeTabConfirm(tab.name),
            style: TextStyle(color: _theme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: _theme.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                proceedClose();
              },
              child: Text(
                AppLocalizations.of(context)!.discard,
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _instantSaveTab(tab);
                proceedClose();
              },
              child: Text(
                AppLocalizations.of(context)!.saveAndClose,
                style: TextStyle(
                  color: _theme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      proceedClose();
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final provider = ThemeProvider.of(context);
        return AlertDialog(
          backgroundColor: _theme.surface,
          title: Text(
            AppLocalizations.of(context)!.selectTheme,
            style: TextStyle(
              color: _theme.textPri,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeType.values.map((type) {
                final label = type == ThemeType.darkPurple
                    ? 'DARK PURPLE'
                    : type.name.toUpperCase();
                final themeVariant = switch (type) {
                  ThemeType.darkPurple => JalideThemeVariant.darkPurple,
                  ThemeType.dark => JalideThemeVariant.dark,
                  ThemeType.light => JalideThemeVariant.light,
                  ThemeType.dracula => JalideThemeVariant.dracula,
                };
                final isSelected = provider.themeType == type;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () {
                      provider.setTheme(type);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeVariant.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? themeVariant.accent
                              : themeVariant.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: themeVariant.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: themeVariant.textPri,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          // Pequenos blocos mostrando outras cores representativas do tema
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: themeVariant.surface,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: themeVariant.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: themeVariant.textMuted,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)!.close,
                style: TextStyle(color: _theme.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _disconnectSshSession() async {
    await _sshConnectionManager.disconnect();
    _showToast('SSH desconectado');
  }

  /// Verificação silenciosa de host key para reconexões automáticas.
  /// Aceita hosts confiáveis, rejeita hosts que mudaram (sem dialog).
  Future<bool> _silentHostKeyVerify(String type, List<int> fingerprint) async {
    final profile = _sshConnectionManager.currentSession?.profile;
    if (profile == null) return false;
    final status = await SshHostKeyService.verify(
      host: profile.host,
      port: profile.port,
      type: type,
      fingerprint: fingerprint,
    );
    return status == HostKeyStatus.trusted;
  }

  void _openSshScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SshConnectScreen(
          profileManager: _sshProfileManager,
          connectionManager: _sshConnectionManager,
          currentSession: _activeSshSession,
          onDisconnect: _disconnectSshSession,
          onConnected: (session) async {
            setState(() {
              _activeSshSession = session;
              _terminalMode = TerminalMode.ssh;
              _hasTerminalBeenOpened = true;
              _isTerminalVisible = true;
            });

            // A sessão já está gerenciada pelo SshConnectionManager (connect + health check + foreground service)
            final home = await session.getHomeDir();
            await _loadRemoteProjectFiles(home);
            await _reloadRemoteTabsContent();
            if (mounted) {
              _activeFocusNode?.unfocus();
              _scaffoldKey.currentState?.openDrawer();
              _showToast('Conectado! Explorer remoto aberto em $home');
            }
          },
        ),
      ),
    );
  }

  Future<void> _openAIPanel() async {
    // Coleta o contexto do projeto
    final activeContent = _activeController?.text ?? '';
    final activePath = _activePath ?? 'sem arquivo';
    final lang = _languageName;

    final projectPaths = _projectFiles
        .where((f) => f['isDir'] != true)
        .map((f) => (f['path'] ?? f['name']) as String)
        .toList();

    final openTabPaths = _tabController.openTabs
        .map((t) => t.path ?? 'untitled')
        .toList();

    // Monta o texto de resumo do contexto para exibir na mensagem de sistema
    final fileName = activePath != 'sem arquivo'
        ? activePath.split(RegExp(r'[/\\]')).last
        : 'sem arquivo';
    final projectLabel = _projectPath != null
        ? '${projectPaths.length} arquivo(s) no projeto'
        : 'sem projeto aberto';
    final contextSummary = '✦ Contexto: $fileName · $projectLabel';

    // Inicia sessão de chat com o contexto injetado no system prompt
    await _aiService.startChatWithContext(
      activeFileContent: activeContent,
      activeFilePath: activePath,
      languageName: lang,
      projectFilePaths: projectPaths,
      openTabsPaths: openTabPaths,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => AIChatPanel(
        aiService: _aiService,
        contextSummary: contextSummary,
        activeFileName: fileName,
        initialMessages: _chatHistory,
        onMessagesChanged: (msgs) {
          _chatHistory = List<ChatMessage>.from(msgs);
        },
        onInsertAtCursor: (text) {
          final ctrl = _activeController;
          if (ctrl == null) return;
          final sel = ctrl.selection;
          final current = ctrl.text;
          final offset = sel.isValid ? sel.baseOffset : current.length;
          final newText =
              current.substring(0, offset) + text + current.substring(offset);
          ctrl.value = ctrl.value.copyWith(
            text: newText,
            selection: TextSelection.collapsed(offset: offset + text.length),
          );
        },
      ),
    );
  }

  void _showAISettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AISettingsDialog(aiService: _aiService),
    );
  }

  void _showFindReplace() {
    setState(() => _isFindReplaceVisible = !_isFindReplaceVisible);
  }

  void _goToLine() {
    if (_activeController == null) return;
    final controller = _activeController!;
    final text = controller.text;
    final lineCount = '\n'.allMatches(text).length + 1;
    final lineController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _theme.surface,
        title: Text(
          'Ir para linha',
          style: TextStyle(color: _theme.textPri, fontSize: 15),
        ),
        content: TextField(
          controller: lineController,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: _theme.textPri, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '1-',
            hintStyle: TextStyle(color: _theme.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _theme.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _theme.accent),
            ),
          ),
          onSubmitted: (_) {
            final num = int.tryParse(lineController.text);
            if (num != null && num >= 1 && num <= lineCount) {
              final lines = text.split('\n');
              int offset = 0;
              for (int i = 0; i < num - 1 && i < lines.length; i++) {
                offset += lines[i].length + 1;
              }
              controller.selection = TextSelection.collapsed(offset: offset);
              _activeFocusNode?.requestFocus();
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: _theme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final num = int.tryParse(lineController.text);
              if (num != null && num >= 1 && num <= lineCount) {
                final lines = text.split('\n');
                int offset = 0;
                for (int i = 0; i < num - 1 && i < lines.length; i++) {
                  offset += lines[i].length + 1;
                }
                controller.selection = TextSelection.collapsed(offset: offset);
                _activeFocusNode?.requestFocus();
              }
              Navigator.pop(ctx);
            },
            child: Text('Ir', style: TextStyle(color: _theme.accent)),
          ),
        ],
      ),
    );
  }

  void _toggleComment() {
    if (_activeController == null) return;
    _tabController.forceRecordActiveTabHistory();
    final controller = _activeController!;
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;

    final commentPrefix = _getCommentPrefix();
    if (commentPrefix == null) {
      _showToast('Linguagem sem suporte a comentários');
      return;
    }

    final lineStart = text.substring(0, sel.start).lastIndexOf('\n') + 1;
    final lineEnd = sel.isCollapsed
        ? text.indexOf('\n', sel.start)
        : text.indexOf('\n', sel.extentOffset);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);
    final trimmedLine = currentLine.trimLeft();

    String newLine;
    if (trimmedLine.startsWith(commentPrefix)) {
      final commentStart = currentLine.indexOf(commentPrefix);
      newLine =
          currentLine.substring(0, commentStart) +
          currentLine.substring(commentStart + commentPrefix.length);
    } else {
      newLine = commentPrefix + currentLine;
    }

    final newText =
        text.substring(0, lineStart) + newLine + text.substring(effectiveEnd);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: sel.start + (newLine.length - currentLine.length),
      ),
    );
  }

  String? _getCommentPrefix() {
    final lang = _tabController.languageName;
    switch (lang) {
      case 'JS':
      case 'TS':
      case 'TSX':
      case 'ESM':
      case 'JSON':
      case 'Dart':
      case 'Java':
      case 'Kotlin':
      case 'C++':
      case 'C':
      case 'C/C++':
      case 'Go':
      case 'Rust':
      case 'Swift':
      case 'Scala':
      case 'PHP':
      case 'C#':
      case 'Ruby':
        return '// ';
      case 'Python':
      case 'YAML':
      case 'Bash':
        return '# ';
      case 'HTML':
      case 'Markdown':
        return '<!-- ';
      case 'CSS':
        return '/* ';
      case 'SQL':
        return '-- ';
      default:
        return '// ';
    }
  }

  void _showCommandPalette() {
    final commands = [
      CommandItem(
        label: 'Novo arquivo',
        shortcut: '',
        icon: Icons.add_outlined,
        category: 'Arquivo',
        onTap: () => _tabController.createNewTab(),
      ),
      CommandItem(
        label: 'Salvar',
        shortcut: 'Ctrl+S',
        icon: Icons.save_outlined,
        category: 'Arquivo',
        onTap: () => _saveFile(),
      ),
      CommandItem(
        label: 'Salvar como',
        shortcut: '',
        icon: Icons.save_as_outlined,
        category: 'Arquivo',
        onTap: () => _saveFileAs(),
      ),
      CommandItem(
        label: 'Fechar aba',
        shortcut: '',
        icon: Icons.close_outlined,
        category: 'Arquivo',
        onTap: () {
          if (_tabController.activeTabIndex != -1) {
            _closeTab(_tabController.activeTabIndex);
          }
        },
      ),
      CommandItem(
        label: 'Sair',
        shortcut: '',
        icon: Icons.exit_to_app,
        category: 'Arquivo',
        onTap: () => SystemNavigator.pop(),
      ),
      CommandItem(
        label: 'Buscar e Substituir',
        shortcut: 'Ctrl+F',
        icon: Icons.search,
        category: 'Editar',
        onTap: () => _showFindReplace(),
      ),
      CommandItem(
        label: 'Duplicar linha',
        shortcut: 'Ctrl+D',
        icon: Icons.copy,
        category: 'Editar',
        onTap: () => _duplicateLine(),
      ),
      CommandItem(
        label: 'Selecionar tudo',
        shortcut: 'Ctrl+A',
        icon: Icons.select_all,
        category: 'Editar',
        onTap: () {
          if (_activeController != null) {
            _activeController!.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _activeController!.text.length,
            );
          }
        },
      ),
      CommandItem(
        label: 'Comentar linha',
        shortcut: 'Ctrl+/',
        icon: Icons.comment_outlined,
        category: 'Editar',
        onTap: () => _toggleComment(),
      ),
      CommandItem(
        label: 'Ir para linha',
        shortcut: 'Ctrl+G',
        icon: Icons.tag,
        category: 'Editor',
        onTap: () => _goToLine(),
      ),
      CommandItem(
        label: 'Formatar código',
        shortcut: 'Ctrl+Shift+F',
        icon: Icons.format_align_left_outlined,
        category: 'Editor',
        onTap: () => _formatCode(),
      ),
      CommandItem(
        label: 'Tamanho da fonte +',
        shortcut: '',
        icon: Icons.zoom_in,
        category: 'Editor',
        onTap: () => _updateFontSize(_fontSize + 2),
      ),
      CommandItem(
        label: 'Tamanho da fonte -',
        shortcut: '',
        icon: Icons.zoom_out,
        category: 'Editor',
        onTap: () => _updateFontSize(_fontSize - 2),
      ),
      CommandItem(
        label: 'Auto-save',
        shortcut: '',
        icon: _autoSaveEnabled
            ? Icons.toggle_on_outlined
            : Icons.toggle_off_outlined,
        category: 'Editor',
        onTap: () => _toggleAutoSave(),
      ),
      CommandItem(
        label: 'Rodar arquivo',
        shortcut: '',
        icon: Icons.play_arrow_rounded,
        category: 'Execução',
        onTap: () => _runActiveFile(),
      ),
      CommandItem(
        label: 'Terminal',
        shortcut: '',
        icon: Icons.terminal,
        category: 'Execução',
        onTap: () {
          setState(() {
            _isTerminalVisible = !_isTerminalVisible;
            if (_isTerminalVisible) _hasTerminalBeenOpened = true;
          });
          _moduleManager.onTerminalToggled(_isTerminalVisible);
        },
      ),
      CommandItem(
        label: 'Sugestões IA',
        shortcut: '',
        icon: Icons.auto_awesome,
        category: 'IA',
        onTap: () => _toggleGhostSuggestions(),
      ),
      CommandItem(
        label: 'Configurações IA',
        shortcut: '',
        icon: Icons.settings_outlined,
        category: 'IA',
        onTap: () => _showAISettingsDialog(),
      ),
      CommandItem(
        label: 'Abrir pasta do projeto',
        shortcut: '',
        icon: Icons.folder_open_outlined,
        category: 'Projeto',
        onTap: () => _pickProjectFolder(),
      ),
      CommandItem(
        label: 'SSH / Remoto',
        shortcut: '',
        icon: Icons.cloud_outlined,
        category: 'Sessão',
        onTap: () => _openSshScreen(),
      ),
      CommandItem(
        label: 'Mudar tema',
        shortcut: '',
        icon: Icons.palette_outlined,
        category: 'Sessão',
        onTap: () => _showThemeDialog(),
      ),
      CommandItem(
        label: 'Plugins',
        shortcut: '',
        icon: Icons.extension_rounded,
        category: 'Sessão',
        onTap: () => _showPluginManager(),
      ),
    ];

    final moduleCmds = _moduleManager.allCommands.map((mc) {
      return CommandItem(
        label: mc.label,
        shortcut: '',
        icon: mc.icon ?? Icons.extension_rounded,
        onTap: mc.onTap,
        category: mc.category,
      );
    }).toList();
    commands.addAll(moduleCmds);

    CommandPalette.show(context, theme: _theme, commands: commands);
  }

  Future<void> _showPluginManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PluginManagerScreen(manager: _moduleManager),
      ),
    );
    // Reconstrói a tela para refletir módulos habilitados/desabilitados
    if (mounted) setState(() {});
  }


  Widget _buildEditor() {
    if (_tabController.activeTabIndex == -1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.code_rounded,
              size: 64,
              color: _theme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'JALIDE Editor',
              style: TextStyle(
                color: _theme.textPri,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum arquivo aberto',
              style: TextStyle(color: _theme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Container(
      color: _theme.bg,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _lastEditorTouchDown = DateTime.now();
        },
        onPointerUp: (_) {
          if (_lastEditorTouchDown != null) {
            final duration = DateTime.now().difference(_lastEditorTouchDown!);
            // Se foi um toque rápido (não foi um long press)
            if (duration.inMilliseconds < 500) {
              // Dá um tempo curto para o TextField processar o tap interno
              Future.delayed(const Duration(milliseconds: 50), () {
                if (!mounted) return;
                try {
                  final selection = _activeController!.selection;
                  // Se o TextField tentou selecionar uma palavra, forçamos o cursor simples
                  if (selection.baseOffset != selection.extentOffset) {
                    _activeController!.selection = TextSelection.collapsed(
                      offset: selection.extentOffset,
                    );
                  }
                } catch (_) {}
              });
            }
          }
        },
        child: CodeTheme(
          data: CodeThemeData(
            styles: {
              'root': TextStyle(
                color: _theme.textPri,
                backgroundColor: _theme.bg,
              ),
              'keyword': TextStyle(color: _theme.kwColor),
              'string': TextStyle(color: _theme.strColor),
              'comment': TextStyle(
                color: _theme.commentColor,
                fontStyle: FontStyle.italic,
              ),
              'number': TextStyle(color: _theme.numColor),
              'function': TextStyle(color: _theme.fnColor),
              'title': TextStyle(color: _theme.fnColor),
              'params': TextStyle(color: _theme.varColor),
              'variable': TextStyle(color: _theme.varColor),
              'attr': TextStyle(color: _theme.varColor),
              'built_in': TextStyle(color: _theme.kwColor),
              'literal': TextStyle(color: _theme.numColor),
              'type': TextStyle(color: _theme.fnColor),
              'class': TextStyle(color: _theme.fnColor),
              'tag': TextStyle(color: _theme.kwColor),
            },
          ),
          child: CodeIndentationGuides(
            controller: _activeController!,
            horizontalScrollController: _horizontalScrollCtrl,
            gutterOffset: 8 + _calculateGutterWidth(),
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: _fontSize,
              height: 1.5,
              color: _theme.textPri,
            ),
            guideColor: _theme.textMuted.withValues(alpha: 0.22),
            activeGuideColor: _theme.accent.withValues(alpha: 0.55),
            child: KeyedSubtree(
              key: _editorScrollKey,
              child: CodeField(
                key: ValueKey(_tabController.activeTabIndex),
                controller: _activeController!,
                focusNode: _activeFocusNode!,
                horizontalScrollController: _horizontalScrollCtrl,
                expands: true,
                minLines: null,
                maxLines: null,
                wrap: false,
                textStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _fontSize,
                  height: 1.5,
                  color: _theme.textPri,
                ),
                cursorColor: _theme.accent,
                gutterStyle: GutterStyle(
                  textStyle: TextStyle(
                    color: _theme.textMuted,
                    fontFamily: 'monospace',
                    fontSize: _fontSize - 3 > 8 ? _fontSize - 3 : 8,
                  ),
                  width: _calculateGutterWidth(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
