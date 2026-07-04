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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_service.dart';
import '../utils/file_utils.dart';
import '../services/ai_service.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_foreground_service.dart';
import '../services/ssh_session_state_service.dart';
import '../theme/jalide_theme.dart';
import '../controllers/editor_tab_controller.dart';
import '../widgets/aux_keyboard.dart';
import '../widgets/ghost_suggestion_bar.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/file_explorer.dart';
import '../widgets/editor_tabs_bar.dart';
import '../widgets/ai_dialog.dart';
import '../widgets/ai_settings_dialog.dart';
import '../utils/code_formatter.dart';
import 'ssh_connect_screen.dart';


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

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
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
  TerminalPanelState? _activeTerminalState;
  DateTime? _lastEditorTouchDown;
  bool _isRemoteProject = false;
  Future<void>? _currentSave;
  final SshProfileManager _sshProfileManager = SshProfileManager();
  late SshConnectionManager _sshConnectionManager;

  // Explorer de Projeto
  String? _projectPath;
  List<Map<String, dynamic>> _projectFiles = [];

  // Configurações
  final AIService _aiService = AIService();
  double _fontSize = 14.0;
  bool _autoSaveEnabled = true;
  bool _ghostSuggestionsEnabled = true;
  bool _autoFormatOnSave = false;
  Timer? _autoSaveTimer;

  // Teclado auxiliar
  bool _ctrlActive = false;

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
      '; :',
      '= >',
      '=>',
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
      if (_autoSaveEnabled && mounted && index < _tabController.openTabs.length) {
        final tab = _tabController.openTabs[index];
        if (tab.hasUnsavedChanges) {
          _triggerAutoSave(tab);
        }
      }
    };
    _tabController.addListener(() {
      if (mounted) setState(() {});
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
      _loadPreferences();
    });
  }

  Future<void> _initializeSshConnectionManager() async {
    await _sshConnectionManager.initialize();

    // Garante que o sshd do Termux foi acionado/iniciado antes de tentar reconectar
    await _startTermuxSshdIfNeeded();
    // Pequeno delay para dar tempo ao daemon do sshd de inicializar e escutar a porta
    await Future.delayed(const Duration(milliseconds: 600));

    // Tenta reconectar silenciosamente à última sessão SSH ao iniciar o app
    final persistedState = await SshSessionStateService.load();
    if (persistedState != null && mounted) {
      debugPrint('📱 Estado SSH anterior encontrado: $persistedState');
      await _sshProfileManager.load();
      final profile = await _sshConnectionManager.getLastSuccessfulProfile();
      if (profile != null && mounted) {
        debugPrint('🔄 Tentando reconexão silenciosa com: ${profile.label}');
        final success = await _sshConnectionManager.connect(profile);
        if (success && mounted) {
          setState(() {
            _activeSshSession = _sshConnectionManager.currentSession;
            _terminalMode = TerminalMode.ssh;
            if (persistedState.isRemoteProject && persistedState.projectPath != null) {
              _isRemoteProject = true;
            }
          });
          if (persistedState.isRemoteProject && persistedState.projectPath != null && mounted) {
            await _loadRemoteProjectFiles(persistedState.projectPath!);
          }
          await _reloadRemoteTabsContent();
          _showToast('SSH reconectado: ${profile.label}', type: _ToastType.success);
        } else {
          debugPrint('⚠️ Reconexão silenciosa falhou. App inicia em modo local.');
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
    if (data is Map<String, dynamic> && data['action'] == 'disconnect') {
      debugPrint('📲 Botão desconectar da notificação pressionado.');
      _sshConnectionManager.disconnect();
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
    _tabController.disposeTabs();
    _tabController.dispose();
    super.dispose();
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
    if (savedProjectPath != null) {
      bool exists = false;
      if (savedProjectPath.startsWith('content://')) {
        exists = true;
      } else {
        exists = Directory(savedProjectPath).existsSync();
      }

      if (exists) {
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
              _tabController.addOrActivateTab(path, content, isRemote: isRemote);
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
      final index = _tabController.openTabs
          .indexWhere((t) => t.path == savedActiveFile);
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
        // Persiste o caminho do projeto para retomada após reinício do app
        await SshSessionStateService.updateProjectPath(path);
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
      {'name': 'JSON', 'highlight': json, 'displayName': 'JSON'},
      {'name': 'Python', 'highlight': python, 'displayName': 'Python'},
      {'name': 'HTML', 'highlight': xml, 'displayName': 'HTML'},
      {'name': 'CSS', 'highlight': css, 'displayName': 'CSS'},
      {'name': 'Dart', 'highlight': dart, 'displayName': 'Dart'},
      {'name': 'C++', 'highlight': cpp, 'displayName': 'C++'},
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
                    final isCurrent = _tabController.languageName == lang['displayName'];
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

      // Fecha o drawer usando a chave global do Scaffold
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        _scaffoldKey.currentState?.closeDrawer();
      }
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
  }

  Future<void> _saveFile() async {
    if (_tabController.activeTabIndex == -1) return;
    if (_activePath == null) {
      await _saveFileAs();
      return;
    }
    if (_currentSave != null) {
      debugPrint('JALIDE_SAVE_BLOCKED: Save already in progress');
      return;
    }

    if (_autoFormatOnSave) {
      _formatCode(silent: true);
    }

    final future = _writeFileContent(
      _activePath!,
      _activeController!.text,
      _tabController.activeTab?.isRemote ?? false,
    );
    _currentSave = future;
    try {
      await future;
      if (!mounted) return;
      _tabController.markTabSaved(_tabController.activeTabIndex);
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
      final content = _activeController!.text;
      final file = File(finalPath);
      await file.writeAsString(content);
      _tabController.updateTabPath(_tabController.activeTabIndex, finalPath);
      _tabController.updateTabLanguageFromPath(
        _tabController.activeTabIndex, finalPath,
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

  void _triggerAutoSave(EditorTab tab) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      if (_currentSave != null) return;

      final tabIndex = _tabController.openTabs.indexOf(tab);
      if (tabIndex != -1 && tab.hasUnsavedChanges && tab.path != null) {
        final path = tab.path!;
        final controller = tab.controller;
        final isRemote = tab.isRemote;

        final future = _writeFileContent(path, controller.text, isRemote);
        _currentSave = future;
        try {
          await future;
          if (!mounted) return;
          _tabController.markTabSaved(tabIndex);
        } catch (e) {
          debugPrint('Auto-save error: $e');
        } finally {
          _currentSave = null;
        }
      }
    });
  }

  Future<void> _instantSaveTab(EditorTab tab) async {
    if (tab.hasUnsavedChanges && tab.path != null) {
      if (_currentSave != null) {
        await _currentSave!;
        if (!mounted) return;
      }

      final path = tab.path!;
      final controller = tab.controller;
      final isRemote = tab.isRemote;

      final future = _writeFileContent(path, controller.text, isRemote);
      _currentSave = future;
      try {
        await future;
        if (!mounted) return;
        final tabIndex = _tabController.openTabs.indexOf(tab);
        if (tabIndex != -1) {
          _tabController.markTabSaved(tabIndex);
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

  void _insertSnippet(String snippet) {
    if (_tabController.activeTabIndex == -1) return;
    final text = _activeController!.text;
    final sel = _activeController!.selection;

    // Proteção contra seleção inválida
    if (!sel.isValid) {
      final insert = snippet.replaceAll(' ', '');
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
    };

    final insert = pairs[snippet] ?? snippet.replaceAll(' ', '');
    _activeController!.text = before + insert + after;

    // Posiciona o cursor no meio dos blocos/aspas
    int offset = sel.start + insert.length;
    if (snippet == '{ }' || snippet == '[ ]') {
      offset =
          sel.start + insert.indexOf('\n$innerIndent') + 1 + innerIndent.length;
    } else if (snippet == '( )' || snippet == '" "' || snippet == "' '") {
      offset = sel.start + 1;
    }

    _activeController!.selection = TextSelection.collapsed(offset: offset);
    _activeFocusNode!.requestFocus();
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

  bool get _isTerminalActive =>
      _isTerminalVisible &&
      _activeTerminalState != null &&
      (_tabController.activeTabIndex == -1 || !_activeFocusNode!.hasFocus);

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
      try {
        (_activeController as dynamic).undo();
      } catch (_) {
        Actions.maybeInvoke<UndoTextIntent>(
          context,
          const UndoTextIntent(SelectionChangedCause.keyboard),
        );
      }
    } else if (key.startsWith('Y')) {
      try {
        (_activeController as dynamic).redo();
      } catch (_) {
        Actions.maybeInvoke<RedoTextIntent>(
          context,
          const RedoTextIntent(SelectionChangedCause.keyboard),
        );
      }
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
    } else if (key.startsWith('D')) {
      _duplicateLine();
    } else if (key.startsWith('F')) {
      _formatCode();
    }
    _activeFocusNode!.requestFocus();
  }

  void _pasteFromClipboard() {
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (data?.text != null) {
        final text = _activeController!.text;
        final sel = _activeController!.selection;
        if (sel.isValid) {
          _activeController!.value = _activeController!.value.copyWith(
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
    final sel = _activeController!.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final text = _activeController!.text;
      Clipboard.setData(
        ClipboardData(text: text.substring(sel.start, sel.end)),
      );
      _activeController!.value = _activeController!.value.copyWith(
        text: text.substring(0, sel.start) + text.substring(sel.end),
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _showToast('Recortado');
    }
  }

  void _duplicateLine() {
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final lines = before.split('\n');
      final currentLine = lines.last;
      final lineStart = before.length - currentLine.length;
      final lineEnd = text.indexOf('\n', lineStart);
      final end = lineEnd == -1 ? text.length : lineEnd;
      final line = text.substring(lineStart, end);
      final newText = '${text.substring(0, end)}\n$line${text.substring(end)}';
      _activeController!.value = _activeController!.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: end + 1 + line.length),
      );
    }
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
        break;
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
    final text = _activeController!.text;
    final sel = _activeController!.selection;
    if (sel.isValid) {
      final before = text.substring(0, sel.start);
      final lines = before.split('\n');
      if (lines.length > 1) {
        final col = lines.last.length;
        final prevLine = lines[lines.length - 2];
        final prevStart = before.length - col - 1 - prevLine.length;
        _activeController!.selection = TextSelection.collapsed(
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
      final formatted = CodeFormatter.format(text, lang);

      if (formatted != text) {
        final selection = controller.selection;
        controller.value = controller.value.copyWith(
          text: formatted,
          selection: selection.isValid
              ? TextSelection.collapsed(
                  offset: selection.baseOffset.clamp(0, formatted.length),
                )
              : const TextSelection.collapsed(offset: -1),
        );
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
        duration: const Duration(days: 1),
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

      if (affectedCurrentFile && _tabController.activeTabIndex != -1) {
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

      if (!isDir && _activePath == path && _tabController.activeTabIndex != -1) {
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
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _theme.surface,
        title: Text(
          isFile ? 'Novo arquivo' : 'Nova pasta',
          style: TextStyle(color: _theme.textPri),
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
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFFFC107), size: 16),
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
                  isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: isConnected ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
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
                leading: Icon(Icons.refresh_rounded, color: _theme.textPri, size: 20),
                title: Text('Reconectar agora', style: TextStyle(color: _theme.textPri)),
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
              leading: Icon(Icons.power_settings_new_rounded,
                  color: _theme.textMuted, size: 20),
              title: Text('Desconectar', style: TextStyle(color: _theme.textMuted)),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _theme.bg,
        systemNavigationBarColor: _theme.accent,
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
          children: [
            // Banner de modo offline: projeto remoto sem conexão ativa
            // (banner sutil substituiu a faixa SSH do topo)
            if (_isRemoteProject &&
                _activeSshSession != null &&
                !(_activeSshSession!.isConnected))
              _buildOfflineBanner(),
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
                          onTerminalStateChanged: (state) {
                            if (state != null) {
                              _activeTerminalState = state;
                            } else {
                              if (_activeTerminalState != null &&
                                  !_activeTerminalState!.mounted) {
                                _activeTerminalState = null;
                              }
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_tabController.activeTabIndex != -1)
              GhostSuggestionBar(
                key: ValueKey('ghost_${_tabController.activeTabIndex}'),
                controller: _activeController!,
                languageName: _tabController.languageName,
                enabled: _ghostSuggestionsEnabled,
                aiService: _aiService,
              ),
            AuxKeyboard(
              auxKeys: _currentAuxKeys,
              ctrlActive: _ctrlActive,
              onKeyTap: _handleAuxKeyTap,
            ),
            StatusBar(
              languageName: _languageName,
              hasUnsavedChanges: _activeHasUnsavedChanges,
              // Mostra o chip SSH na status bar apenas com projeto remoto ativo
              sshConnectionManager: _isRemoteProject ? _sshConnectionManager : null,
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
          onPressed: () => Scaffold.of(context).openDrawer(),
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
                      _activePath!,
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
          onPressed: _tabController.activeTabIndex != -1 ? _runActiveFile : null,
          icon: Icon(
            Icons.play_arrow_rounded,
            size: 24,
            color: _tabController.activeTabIndex != -1
                ? const Color(0xFF50FA7B)
                : _theme.textMuted,
          ),
          tooltip: 'Executar arquivo',
        ),

        IconButton(
          onPressed: _tabController.hasUnsavedChanges ? _saveFile : null,
          icon: Icon(
            Icons.save_outlined,
            size: 20,
            color: _tabController.hasUnsavedChanges ? _theme.accent : _theme.textMuted,
          ),
          tooltip: 'Salvar',
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            );
          },
          icon: Icon(Icons.info_outline, size: 22, color: _theme.textMuted),
          tooltip: 'Sobre',
        ),
        IconButton(
          onPressed: _tabController.activeTabIndex != -1 ? _openAIDialog : null,
          icon: Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: _tabController.activeTabIndex != -1 ? Colors.amber[600] : _theme.textMuted,
          ),
          tooltip: 'Assistente IA (Gemma)',
        ),
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
              case 'exit':
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _theme.surface,
                    title: Text('Sair', style: TextStyle(color: _theme.textPri)),
                    content: Text(
                      'Tem certeza que deseja sair da aplicação?',
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
                        child: const Text(
                          'Sair',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                break;
            }
          },
          itemBuilder: (_) => [
            _menuItem('new', 'Novo arquivo', Icons.add_outlined),
            _menuItem('save_as', 'Salvar como…', Icons.save_as_outlined),
            const PopupMenuDivider(),
            _menuItem('zoom_in', 'Aumentar fonte', Icons.zoom_in),
            _menuItem('zoom_out', 'Diminuir fonte', Icons.zoom_out),
            const PopupMenuDivider(),
            _menuItem(
              'autosave',
              _autoSaveEnabled ? 'Auto-Save: [ON]' : 'Auto-Save: [OFF]',
              _autoSaveEnabled
                  ? Icons.toggle_on_outlined
                  : Icons.toggle_off_outlined,
            ),
            _menuItem(
              'autoformat',
              _autoFormatOnSave ? 'Auto-Format: [ON]' : 'Auto-Format: [OFF]',
              _autoFormatOnSave
                  ? Icons.align_horizontal_left
                  : Icons.align_horizontal_left_outlined,
            ),
            _menuItem(
              'format',
              'Formatar Código',
              Icons.format_align_left_outlined,
            ),
            const PopupMenuDivider(),
            _menuItem(
              'ai_settings',
              'Config. Gemma IA',
              Icons.settings_outlined,
            ),
            _menuItem(
              'ghost',
              _ghostSuggestionsEnabled
                  ? 'Sugestões IA: [ON]'
                  : 'Sugestões IA: [OFF]',
              _ghostSuggestionsEnabled
                  ? Icons.auto_awesome
                  : Icons.auto_awesome_outlined,
            ),
            _menuItem('ssh', 'SSH Remote', Icons.cloud_outlined),
            _menuItem('theme', 'Mudar Tema', Icons.palette_outlined),
            const PopupMenuDivider(),
            _menuItem('exit', 'Sair da aplicação', Icons.exit_to_app),
          ],
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
            'Alterações não salvas',
            style: TextStyle(color: _theme.textPri),
          ),
          content: Text(
            'Deseja fechar esta aba sem salvar as alterações?',
            style: TextStyle(color: _theme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: _theme.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                proceedClose();
              },
              child: const Text(
                'Fechar mesmo assim',
                style: TextStyle(color: Colors.redAccent),
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
            'Selecionar Tema',
            style: TextStyle(color: _theme.textPri),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeType.values.map((type) {
              final label = type == ThemeType.darkPurple
                  ? 'DARK PURPLE'
                  : type.name.toUpperCase();
              return RadioListTile<ThemeType>(
                title: Text(
                  label,
                  style: TextStyle(color: _theme.textPri, fontSize: 14),
                ),
                value: type,
                groupValue: provider.themeType,
                onChanged: (ThemeType? value) {
                  if (value != null) {
                    provider.setTheme(value);
                    Navigator.pop(context);
                  }
                },
                activeColor: _theme.accent,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _disconnectSshSession() async {
    await _sshConnectionManager.disconnect();
    _showToast('SSH desconectado');
  }

  void _openSshScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SshConnectScreen(
          profileManager: _sshProfileManager,
          currentSession: _activeSshSession,
          onDisconnect: _disconnectSshSession,
          onConnected: (session) async {
            // Usa o SshConnectionManager para gerenciar a conexão
            setState(() {
              _activeSshSession = session;
              _terminalMode = TerminalMode.ssh;
              _hasTerminalBeenOpened = true;
              _isTerminalVisible = true;
            });

            // Registra na sessão do gerenciador
            await _sshConnectionManager.setCurrentSession(session, session.profile);

            // Ao conectar, pergunta se quer abrir a home remota
            final home = await session.getHomeDir();
            await _loadRemoteProjectFiles(home);
            await _reloadRemoteTabsContent();
            if (mounted) {
              _scaffoldKey.currentState?.openDrawer();
              _showToast('Conectado! Explorer remoto aberto em $home');
            }
          },
        ),
      ),
    );
  }

  void _openAIDialog() {
    showDialog(
      context: context,
      builder: (_) => AIDialog(
        aiService: _aiService,
        selectedCode: _tabController.activeTabIndex != -1 ? _activeController!.text : null,
        language: _getLanguageForCurrentFile(),
      ),
    );
  }

  void _showAISettingsDialog() {
    showDialog(context: context, builder: (_) => AISettingsDialog(aiService: _aiService));
  }

  String? _getLanguageForCurrentFile() {
    if (_activePath == null) return null;
    final ext = p.extension(_activePath!).toLowerCase();
    switch (ext) {
      case '.dart':
        return 'dart';
      case '.py':
        return 'python';
      case '.js':
        return 'javascript';
      case '.ts':
        return 'typescript';
      case '.java':
        return 'java';
      case '.cpp':
      case '.cc':
        return 'cpp';
      case '.c':
        return 'c';
      case '.json':
        return 'json';
      case '.xml':
        return 'xml';
      case '.html':
        return 'html';
      case '.css':
        return 'css';
      default:
        return null;
    }
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
          child: CodeField(
            key: ValueKey(_tabController.activeTabIndex),
            controller: _activeController!,
            focusNode: _activeFocusNode!,
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
              width: 40,
            ),
          ),
        ),
      ),
    );
  }
}
