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
import 'package:jalide/services/ssh_service.dart';
import 'package:jalide/screens/donation_screen.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_service.dart';
//import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';
import '../widgets/aux_keyboard.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/file_explorer.dart';
import '../widgets/editor_tabs_bar.dart';
import '../utils/file_utils.dart';
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

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Tabs abertas
  final List<Map<String, dynamic>> _openTabs = [];
  int _activeTabIndex = -1;

  // Getters para a aba ativa com proteção para estado inicial
  CodeController get _activeController => _activeTabIndex != -1
      ? _openTabs[_activeTabIndex]['controller'] as CodeController
      : throw StateError('Nenhuma aba ativa');

  FocusNode get _activeFocusNode => _activeTabIndex != -1
      ? _openTabs[_activeTabIndex]['focusNode'] as FocusNode
      : throw StateError('Nenhuma aba ativa');

  String? get _activePath => _activeTabIndex != -1
      ? _openTabs[_activeTabIndex]['path'] as String?
      : null;

  bool get _activeHasUnsavedChanges => _activeTabIndex != -1
      ? _openTabs[_activeTabIndex]['hasUnsavedChanges'] as bool
      : false;

  JalideThemeVariant get _theme => ThemeProvider.of(context).current;

  bool _isTerminalVisible = false;
  bool _hasTerminalBeenOpened = false;
  TerminalMode _terminalMode = TerminalMode.local;
  SshSession? _activeSshSession;
  TerminalPanelState? _activeTerminalState;
  bool _isRemoteProject = false;
  bool _isSaving = false;
  final SshProfileManager _sshProfileManager = SshProfileManager();

  // Explorer de Projeto
  String? _projectPath;
  List<Map<String, dynamic>> _projectFiles = [];

  // Configurações
  double _fontSize = 14.0;
  bool _autoSaveEnabled = true;
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
    _sshProfileManager.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Auto-Save Setting
    final savedAutoSave = prefs.getBool('autosave_enabled') ?? true;
    if (mounted) {
      setState(() => _autoSaveEnabled = savedAutoSave);
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
              _addTab(path, content, isRemote: isRemote);
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
      final index = _openTabs.indexWhere((t) => t['path'] == savedActiveFile);
      if (index != -1) {
        setState(() {
          _activeTabIndex = index;
        });
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
            _addTab(savedActiveFile, content);
          } catch (_) {}
        }
      }
    }

    if (mounted && _openTabs.isEmpty) {
      _createNewTab();
    }
  }

  Future<void> _updateFontSize(double newSize) async {
    if (!mounted) return;
    setState(() => _fontSize = newSize.clamp(8.0, 32.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_font_size', _fontSize);
  }

  Future<void> _saveTabsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final validTabs = _openTabs.where((t) => t['path'] != null && (t['path'] as String).isNotEmpty).toList();
    final List<Map<String, dynamic>> tabsData = validTabs.map((t) {
      return {
        'path': t['path'] as String,
        'isRemote': t['isRemote'] as bool? ?? false,
      };
    }).toList();
    await prefs.setString('persisted_open_tabs', jsonEncode(tabsData));

    if (_activeTabIndex != -1 && _activeTabIndex < _openTabs.length) {
      final activePath = _openTabs[_activeTabIndex]['path'];
      if (activePath != null && (activePath as String).isNotEmpty) {
        await prefs.setString('last_active_file', activePath);
      } else {
        await prefs.remove('last_active_file');
      }
    } else {
      await prefs.remove('last_active_file');
    }
  }

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
      }
    } catch (e) {
      _showToast('Erro ao listar arquivos remotos: $e', type: _ToastType.error);
    }
  }

  @override
  void dispose() {
    for (final tab in _openTabs) {
      (tab['controller'] as CodeController).dispose();
      (tab['focusNode'] as FocusNode).dispose();
    }
    super.dispose();
  }

  CodeController _createController(
    String text,
    dynamic language,
    VoidCallback onChanged,
  ) {
    final controller = CodeController(
      text: text,
      language: language,
      patternMap: {
        r'\bTODO\b': const TextStyle(
          color: Color(0xFFE07B1A),
          fontWeight: FontWeight.bold,
        ),
        r'\bFIXME\b': const TextStyle(
          color: Color(0xFFFF6B6B),
          fontWeight: FontWeight.bold,
        ),
        r'\bHACK\b': const TextStyle(color: Color(0xFFFFD580)),
      },
    );
    controller.addListener(() {
      if (mounted) onChanged();
    });
    return controller;
  }

  void _createNewTab() {
    final Map<String, dynamic> newTab = {
      'path': null,
      'name': 'untitled.js',
      'hasUnsavedChanges': false,
      'focusNode': FocusNode(),
      'languageName': 'JS',
    };
    newTab['controller'] = _createController('', javascript, () {
      final isChanged = newTab['controller'].text != '';
      if (newTab['hasUnsavedChanges'] != isChanged) {
        setState(() => newTab['hasUnsavedChanges'] = isChanged);
      }
    });

    setState(() {
      _openTabs.add(newTab);
      _activeTabIndex = _openTabs.length - 1;
    });
    _saveTabsPreference();
  }

  String get _fileName {
    if (_activeTabIndex == -1) return 'JALIDE';
    return _activePath == null
        ? 'untitled.js'
        : FileUtils.getDisplayName(_activePath!);
  }

  String get _languageName {
    if (_activeTabIndex == -1) return 'JS';
    return _openTabs[_activeTabIndex]['languageName'] as String? ?? 'TEXT';
  }

  String _getInitialLanguageName(String? path) {
    if (path == null) return 'JS';
    final ext = p.extension(path).toLowerCase();
    const map = {
      '.json': 'JSON',
      '.js': 'JS',
      '.jsx': 'JS',
      '.ts': 'TS',
      '.tsx': 'TSX',
      '.mjs': 'ESM',
      '.py': 'Python',
      '.pyw': 'Python',
      '.html': 'HTML',
      '.htm': 'HTML',
      '.css': 'CSS',
      '.dart': 'Dart',
      '.cpp': 'C++',
      '.hpp': 'C++',
      '.cc': 'C++',
      '.c': 'C',
      '.h': 'C/C++',
      '.md': 'Markdown',
      '.markdown': 'Markdown',
    };
    return map[ext] ?? 'TEXT';
  }

  void _showLanguageSelector() {
    if (_activeTabIndex == -1) return;

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
                    final isCurrent = _languageName == lang['displayName'];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(
                        lang['name'] as String,
                        style: TextStyle(
                          color: isCurrent ? _theme.accent : _theme.textPri,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.check_circle, color: _theme.accent, size: 18)
                          : null,
                      onTap: () {
                        setState(() {
                          _openTabs[_activeTabIndex]['languageName'] = lang['displayName'];
                          _activeController.language = lang['highlight'] as Mode?;
                        });
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
    if (_activeTabIndex == -1) {
      _showToast('Nenhum arquivo aberto');
      return;
    }

    if (_activePath == null) {
      _showToast('Por favor, salve o arquivo antes de rodar!');
      return;
    }

    // Se o arquivo tiver alterações não salvas, salva antes de rodar!
    if (_activeHasUnsavedChanges) {
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

    final physicalActivePath = _resolveSafPath(_activePath!);
    final physicalProjectPath = _projectPath != null ? _resolveSafPath(_projectPath!) : null;

    String fileRunPath = '';
    if (physicalProjectPath != null && physicalActivePath.startsWith(physicalProjectPath)) {
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
        final outBin = parentPath == '.' ? './$binName' : '$parentPath/$binName';
        command = 'clang++ "$fileRunPath" -o "$outBin" && "$outBin"';
        break;
      case '.c':
        final cBinName = p.basenameWithoutExtension(fileRunPath);
        final cParentPath = p.dirname(fileRunPath);
        final cOutBin = cParentPath == '.' ? './$cBinName' : '$cParentPath/$cBinName';
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

  String _resolveSafPath(String safUri) {
    if (!safUri.startsWith('content://')) return safUri;
    try {
      final uri = Uri.parse(safUri);
      final decodedPath = Uri.decodeComponent(uri.path);
      
      // Encontra a parte depois de tree/ ou document/ (document/ tem precedência para URIs de arquivos sob pastas)
      String? treeOrDocPart;
      final docIndex = decodedPath.indexOf('document/');
      if (docIndex != -1) {
        treeOrDocPart = decodedPath.substring(docIndex + 9);
      } else {
        final treeIndex = decodedPath.indexOf('tree/');
        if (treeIndex != -1) {
          treeOrDocPart = decodedPath.substring(treeIndex + 5);
        }
      }
      
      if (treeOrDocPart != null) {
        if (treeOrDocPart.startsWith('primary:')) {
          final relativePath = treeOrDocPart.substring(8);
          return '/storage/emulated/0/$relativePath';
        } else if (treeOrDocPart.startsWith('home:')) {
          final relativePath = treeOrDocPart.substring(5);
          return '/data/data/com.termux/files/home/$relativePath';
        } else if (treeOrDocPart.startsWith('usr:')) {
          final relativePath = treeOrDocPart.substring(4);
          return '/data/data/com.termux/files/usr/$relativePath';
        } else if (treeOrDocPart.startsWith('raw:')) {
          return treeOrDocPart.substring(4);
        } else if (treeOrDocPart.startsWith('/')) {
          return treeOrDocPart;
        }
      }
    } catch (e) {
      debugPrint('Error resolving SAF path: $e');
    }
    return safUri;
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

  Future<void> _openFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    final content = await FileService.readFile(path);
    _addTab(path, content);
  }

  void _addTab(String path, String content, {bool isRemote = false}) {
    final existing = _openTabs.indexWhere((t) => t['path'] == path);
    if (existing == -1) {
      final Map<String, dynamic> newTab = {
        'path': path,
        'name': FileUtils.getDisplayName(path),
        'hasUnsavedChanges': false,
        'isRemote': isRemote,
        'focusNode': FocusNode(),
        'languageName': _getInitialLanguageName(path),
      };
      newTab['initialContent'] = content;
      newTab['controller'] = _createController(content, _langForPath(path), () {
        final isChanged = newTab['controller'].text != newTab['initialContent'];
        if (newTab['hasUnsavedChanges'] != isChanged) {
          setState(() => newTab['hasUnsavedChanges'] = isChanged);
        }
        if (isChanged && _autoSaveEnabled) {
          _triggerAutoSave(newTab);
        }
      });

      setState(() {
        _openTabs.add(newTab);
        _activeTabIndex = _openTabs.length - 1;
      });
    } else {
      setState(() {
        _activeTabIndex = existing;
      });
    }
    _saveTabsPreference();
  }

  Future<void> _saveFile() async {
    if (_activeTabIndex == -1) return;
    if (_activePath == null) {
      await _saveFileAs();
      return;
    }
    if (_isSaving) {
      debugPrint('JALIDE_SAVE_BLOCKED: Save already in progress');
      return;
    }

    setState(() => _isSaving = true);
    try {
      debugPrint('JALIDE_ATTEMPT_SAVE: $_activePath');

      if (_activePath!.startsWith('content://')) {
        await _termuxChannel.invokeMethod('writeSafFile', {
          'uri': _activePath,
          'content': _activeController.text,
        });
      } else if (_openTabs[_activeTabIndex]['isRemote'] == true &&
          _activeSshSession != null) {
        await _activeSshSession!.writeFile(
          _activePath!,
          _activeController.text,
        );
      } else {
        final file = File(_activePath!);
        await file.writeAsString(_activeController.text);
      }

      setState(() {
        _openTabs[_activeTabIndex]['hasUnsavedChanges'] = false;
        _openTabs[_activeTabIndex]['initialContent'] = _activeController.text;
      });
      if (!mounted) return;
      _showToast('Salvo com sucesso', type: _ToastType.success);
    } catch (e) {
      _showToast('Erro ao salvar: $e', type: _ToastType.error);
      debugPrint('JALIDE_SAVE_ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveFileAs() async {
    if (_activeTabIndex == -1) return;

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
      final content = _activeController.text;
      final file = File(finalPath);
      await file.writeAsString(content);
      setState(() {
        _openTabs[_activeTabIndex]['path'] = finalPath;
        _openTabs[_activeTabIndex]['name'] = p.basename(finalPath);
        _openTabs[_activeTabIndex]['hasUnsavedChanges'] = false;
        _openTabs[_activeTabIndex]['initialContent'] = content;
        _openTabs[_activeTabIndex]['languageName'] = _getInitialLanguageName(finalPath);
        _activeController.language = _langForPath(finalPath);
      });
      _saveTabsPreference();
      // Atualiza o explorer se o arquivo foi salvo na pasta do projeto
      if (_projectPath != null) await _loadProjectFiles(_projectPath!);
      _showToast('Salvo como ${p.basename(finalPath)}', type: _ToastType.success);
    } catch (e) {
      _showToast('Erro ao salvar como: $e', type: _ToastType.error);
      debugPrint('JALIDE_SAVE_AS_ERROR: $e');
    }
  }

  void _triggerAutoSave(Map<String, dynamic> tab) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      if (_isSaving) {
        // Se já estiver salvando, reagenda o auto-salvamento para daqui a 1.5s
        _triggerAutoSave(tab);
        return;
      }
      final tabIndex = _openTabs.indexOf(tab);
      if (tabIndex != -1 && tab['hasUnsavedChanges'] == true && tab['path'] != null) {
        setState(() => _isSaving = true);
        try {
          final path = tab['path'] as String;
          final controller = tab['controller'] as CodeController;
          final isRemote = tab['isRemote'] == true;
          
          debugPrint('JALIDE_AUTOSAVE: $path');
          
          if (path.startsWith('content://')) {
            await _termuxChannel.invokeMethod('writeSafFile', {
              'uri': path,
              'content': controller.text,
            });
          } else if (isRemote && _activeSshSession != null) {
            await _activeSshSession!.writeFile(path, controller.text);
          } else {
            final file = File(path);
            await file.writeAsString(controller.text);
          }
          
          setState(() {
            tab['hasUnsavedChanges'] = false;
            tab['initialContent'] = controller.text;
          });
        } catch (e) {
          debugPrint('Auto-save error: $e');
        } finally {
          if (mounted) {
            setState(() => _isSaving = false);
          }
        }
      }
    });
  }

  Future<void> _instantSaveTab(Map<String, dynamic> tab) async {
    if (tab['hasUnsavedChanges'] == true && tab['path'] != null) {
      if (_isSaving) {
        // Se já está salvando, aguarda até que conclua (máximo de 2 segundos)
        int retries = 0;
        while (_isSaving && retries < 10 && mounted) {
          await Future.delayed(const Duration(milliseconds: 200));
          retries++;
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = true);
      try {
        final path = tab['path'] as String;
        final controller = tab['controller'] as CodeController;
        final isRemote = tab['isRemote'] == true;
        
        debugPrint('JALIDE_INSTANT_SAVE: $path');
        
        if (path.startsWith('content://')) {
          await _termuxChannel.invokeMethod('writeSafFile', {
            'uri': path,
            'content': controller.text,
          });
        } else if (isRemote && _activeSshSession != null) {
          await _activeSshSession!.writeFile(path, controller.text);
        } else {
          final file = File(path);
          await file.writeAsString(controller.text);
        }
        
        setState(() {
          tab['hasUnsavedChanges'] = false;
          tab['initialContent'] = controller.text;
        });
      } catch (e) {
        debugPrint('Instant save error: $e');
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
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

  // Insere snippet no cursor com auto-indentação
  void _insertSnippet(String snippet) {
    if (_activeTabIndex == -1) return;
    final text = _activeController.text;
    final sel = _activeController.selection;

    // Proteção contra seleção inválida
    if (!sel.isValid) {
      final insert = snippet.replaceAll(' ', '');
      _activeController.text = text + insert;
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
    _activeController.text = before + insert + after;

    // Posiciona o cursor no meio dos blocos/aspas
    int offset = sel.start + insert.length;
    if (snippet == '{ }' || snippet == '[ ]') {
      offset =
          sel.start + insert.indexOf('\n$innerIndent') + 1 + innerIndent.length;
    } else if (snippet == '( )' || snippet == '" "' || snippet == "' '") {
      offset = sel.start + 1;
    }

    _activeController.selection = TextSelection.collapsed(offset: offset);
    _activeFocusNode.requestFocus();
  }

  void _handleAuxKeyTap(String key) {
    final bool isTerminalActive = _isTerminalVisible &&
        _activeTerminalState != null &&
        (_activeTabIndex == -1 || !_activeFocusNode.hasFocus);

    if (isTerminalActive) {
      if (key == 'Ctrl') {
        setState(() {
          _ctrlActive = !_ctrlActive;
        });
        return;
      }

      if (_ctrlActive) {
        setState(() {
          _ctrlActive = false;
        });

        if (key.startsWith('Z')) {
          _activeTerminalState!.sendInput("\x1a");
        } else if (key.startsWith('Y')) {
          _activeTerminalState!.sendInput("\x19");
        } else if (key.startsWith('A')) {
          _activeTerminalState!.sendInput("\x01");
        } else if (key.startsWith('C')) {
          _activeTerminalState!.sendInput("\x03");
          _showToast('Ctrl+C enviado');
        } else if (key.startsWith('V')) {
          Clipboard.getData(Clipboard.kTextPlain).then((data) {
            if (data != null && data.text != null) {
              _activeTerminalState!.sendInput(data.text!);
            }
          });
        } else if (key.startsWith('X')) {
          _activeTerminalState!.sendInput("\x18");
        }
        return;
      }

      if (key == 'Tab') {
        _activeTerminalState!.sendInput("\t");
      } else if (key == '←') {
        _activeTerminalState!.sendInput("\x1b[D");
      } else if (key == '→') {
        _activeTerminalState!.sendInput("\x1b[C");
      } else if (key == '↑') {
        _activeTerminalState!.sendInput("\x1b[A");
      } else if (key == '↓') {
        _activeTerminalState!.sendInput("\x1b[B");
      } else {
        _activeTerminalState!.sendInput(key.replaceAll(' ', ''));
      }
      return;
    }

    if (_activeTabIndex == -1) return;

    if (key == 'Ctrl') {
      setState(() {
        _ctrlActive = !_ctrlActive;
      });
      return;
    }

    if (_ctrlActive) {
      setState(() {
        _ctrlActive = false;
      });

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
        _activeController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _activeController.text.length,
        );
      } else if (key.startsWith('C')) {
        final sel = _activeController.selection;
        if (sel.isValid && !sel.isCollapsed) {
          Clipboard.setData(ClipboardData(
            text: _activeController.text.substring(sel.start, sel.end),
          ));
          _showToast('Copiado para a área de transferência');
        }
      } else if (key.startsWith('V')) {
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          if (data != null && data.text != null) {
            final text = _activeController.text;
            final sel = _activeController.selection;
            if (sel.isValid) {
              final before = text.substring(0, sel.start);
              final after = text.substring(sel.end);
              _activeController.text = before + data.text! + after;
              _activeController.selection = TextSelection.collapsed(
                offset: sel.start + data.text!.length,
              );
            }
          }
        });
      } else if (key.startsWith('X')) {
        final sel = _activeController.selection;
        if (sel.isValid && !sel.isCollapsed) {
          final text = _activeController.text;
          final selectedText = text.substring(sel.start, sel.end);
          Clipboard.setData(ClipboardData(text: selectedText));
          final before = text.substring(0, sel.start);
          final after = text.substring(sel.end);
          _activeController.text = before + after;
          _activeController.selection = TextSelection.collapsed(offset: sel.start);
          _showToast('Recortado');
        }
      }
      _activeFocusNode.requestFocus();
      return;
    }

    if (key == 'Tab') {
      _insertSnippet('  ');
    } else if (key == '←') {
      final sel = _activeController.selection;
      if (sel.isValid && sel.start > 0) {
        _activeController.selection = TextSelection.collapsed(
          offset: sel.start - 1,
        );
      }
    } else if (key == '→') {
      final sel = _activeController.selection;
      if (sel.isValid && sel.start < _activeController.text.length) {
        _activeController.selection = TextSelection.collapsed(
          offset: sel.start + 1,
        );
      }
    } else if (key == '↑') {
      final text = _activeController.text;
      final sel = _activeController.selection;
      if (sel.isValid) {
        final currentOffset = sel.start;
        final beforeText = text.substring(0, currentOffset);
        final linesBefore = beforeText.split('\n');
        if (linesBefore.length > 1) {
          final currentLineText = linesBefore.last;
          final currentColumn = currentLineText.length;
          final previousLineText = linesBefore[linesBefore.length - 2];
          final previousLineStart =
              beforeText.length - currentColumn - 1 - previousLineText.length;
          final targetColumn = currentColumn < previousLineText.length
              ? currentColumn
              : previousLineText.length;
          _activeController.selection = TextSelection.collapsed(
            offset: previousLineStart + targetColumn,
          );
        }
      }
    } else if (key == '↓') {
      final text = _activeController.text;
      final sel = _activeController.selection;
      if (sel.isValid) {
        final currentOffset = sel.start;
        final beforeText = text.substring(0, currentOffset);
        final afterText = text.substring(currentOffset);
        final linesBefore = beforeText.split('\n');
        final currentLineText = linesBefore.isNotEmpty ? linesBefore.last : '';
        final currentColumn = currentLineText.length;

        final linesAfter = afterText.split('\n');
        if (linesAfter.length > 1) {
          final nextLineText = linesAfter[1];
          final nextLineStart = beforeText.length + linesAfter[0].length + 1;
          final targetColumn =
              currentColumn < nextLineText.length ? currentColumn : nextLineText.length;
          _activeController.selection = TextSelection.collapsed(
            offset: nextLineStart + targetColumn,
          );
        }
      }
    } else {
      _insertSnippet(key);
    }
    _activeFocusNode.requestFocus();
  }

  void _showToast(
    String msg, {
    _ToastType type = _ToastType.info,
  }) {
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
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                icon: Icon(Icons.close, color: snackBarTheme.iconColor, size: 18),
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
            color: type == _ToastType.info ? _theme.accent : snackBarTheme.iconColor,
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

    final affectedCurrentFile = _activePath != null &&
        (_activePath == path ||
            (isDir && _activePath!.startsWith('$path/')));

    if (affectedCurrentFile && _activeHasUnsavedChanges) {
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
            child: Text(
              'Excluir',
              style: TextStyle(color: Colors.redAccent),
            ),
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

      if (affectedCurrentFile && _activeTabIndex != -1) {
        _closeTab(_activeTabIndex);
      }

      final refreshPath = isRemote ? p.posix.dirname(path) : p.dirname(path);
      if (isRemote) {
        await _loadRemoteProjectFiles(refreshPath);
      } else {
        await _loadProjectFiles(refreshPath);
      }

      _showToast('${isDir ? 'Pasta' : 'Arquivo'} excluído com sucesso', type: _ToastType.success);
    } catch (e) {
      _showToast('Erro ao excluir: $e', type: _ToastType.error);
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
  static const _termuxChannel = MethodChannel('com.jalide/termux');

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
        _showToast('✅ Workspace "$folderName" aberto!', type: _ToastType.success);
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

  Future<void> _createNewEntity(String name, bool isFile, {String? basePath}) async {
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

  dynamic _langForPath(String? path) {
    if (path == null) return javascript;
    switch (p.extension(path).toLowerCase()) {
      case '.json':
        return json;
      case '.py':
      case '.pyw':
        return python;
      case '.html':
      case '.htm':
        return xml;
      case '.css':
        return css;
      case '.dart':
        return dart;
      case '.cpp':
      case '.hpp':
      case '.cc':
      case '.c':
      case '.h':
        return cpp;
      case '.md':
      case '.markdown':
        return markdown;
      default:
        return javascript;
    }
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
          termuxChannel: _termuxChannel,
          sshSession: _activeSshSession,
          isRemoteProject: _isRemoteProject,
        ),
        body: Column(
          children: [
            if (_openTabs.isNotEmpty)
              EditorTabsBar(
                tabs: _openTabs,
                activeIndex: _activeTabIndex,
                onTabTap: (i) {
                  if (_activeTabIndex != -1 && _activeTabIndex != i) {
                    _instantSaveTab(_openTabs[_activeTabIndex]);
                  }
                  setState(() => _activeTabIndex = i);
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
                              if (_activeTerminalState != null && !_activeTerminalState!.mounted) {
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
            AuxKeyboard(
              auxKeys: _currentAuxKeys,
              ctrlActive: _ctrlActive,
              onKeyTap: _handleAuxKeyTap,
            ),
            StatusBar(
              languageName: _languageName,
              hasUnsavedChanges: _activeHasUnsavedChanges,
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
          onPressed: _activeTabIndex != -1 ? _runActiveFile : null,
          icon: Icon(
            Icons.play_arrow_rounded,
            size: 24,
            color: _activeTabIndex != -1 ? const Color(0xFF50FA7B) : _theme.textMuted,
          ),
          tooltip: 'Executar arquivo',
        ),
        IconButton(
          onPressed: _openFile,
          icon: const Icon(Icons.folder_open_outlined, size: 20),
          color: _theme.textMuted,
          tooltip: 'Abrir arquivo',
        ),
        IconButton(
          onPressed: _activeHasUnsavedChanges ? _saveFile : null,
          icon: Icon(
            Icons.save_outlined,
            size: 20,
            color: _activeHasUnsavedChanges ? _theme.accent : _theme.textMuted,
          ),
          tooltip: 'Salvar',
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DonationScreen()),
            );
          },
          icon: const Icon(Icons.favorite, size: 20, color: Colors.redAccent),
          tooltip: 'Apoiar Projeto',
        ),
        PopupMenuButton<String>(
          color: _theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: _theme.border),
          ),
          onSelected: (v) async {
            if (v == 'new') _createNewTab();
            if (v == 'save_as') await _saveFileAs();
            if (v == 'theme') _showThemeDialog();
            if (v == 'zoom_in') _updateFontSize(_fontSize + 2);
            if (v == 'zoom_out') _updateFontSize(_fontSize - 2);
            if (v == 'ssh') _openSshScreen();
            if (v == 'autosave') _toggleAutoSave();
            if (v == 'exit') SystemNavigator.pop();
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
              _autoSaveEnabled ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
            ),
            const PopupMenuDivider(),
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
    final tab = _openTabs[index];
    final bool hasUnsaved = tab['hasUnsavedChanges'] as bool;

    void proceedClose() {
      final controller = tab['controller'] as CodeController;
      final focusNode = tab['focusNode'] as FocusNode;

      setState(() {
        _openTabs.removeAt(index);
        if (_activeTabIndex == index) {
          if (_openTabs.isNotEmpty) {
            _activeTabIndex = index > 0 ? index - 1 : 0;
          } else {
            _activeTabIndex = -1;
          }
        } else if (_activeTabIndex > index) {
          _activeTabIndex--;
        }
      });

      // Adia o dispose para o próximo ciclo de microtask
      // Isso evita que o Flutter tente buildar o widget com um node já destruído
      Future.microtask(() {
        controller.dispose();
        focusNode.dispose();
      });

      _saveTabsPreference();
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
          content: RadioGroup<ThemeType>(
            groupValue: provider.themeType,
            onChanged: (ThemeType? value) {
              if (value != null) {
                provider.setTheme(value);
                Navigator.pop(context);
              }
            },
            child: Column(
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
                  activeColor: _theme.accent,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _disconnectSshSession() async {
    final session = _activeSshSession;
    if (session == null) return;

    await session.disconnect();

    if (!mounted) return;
    setState(() {
      _activeSshSession = null;
      _terminalMode = TerminalMode.local;
    });
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
            setState(() {
              _activeSshSession = session;
              _terminalMode = TerminalMode.ssh;
              _hasTerminalBeenOpened = true;
              _isTerminalVisible = true;
            });
            // Ao conectar, pergunta se quer abrir a home remota
            final home = await session.getHomeDir();
            await _loadRemoteProjectFiles(home);
            if (mounted) {
              _scaffoldKey.currentState?.openDrawer();
              _showToast('Conectado! Explorer remoto aberto em $home');
            }
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    if (_activeTabIndex == -1) {
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
          key: ValueKey(_activeTabIndex),
          controller: _activeController,
          focusNode: _activeFocusNode,
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
    );
  }
}
