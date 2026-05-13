import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
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
  bool _isRemoteProject = false;
  final SshProfileManager _sshProfileManager = SshProfileManager();

  // Explorer de Projeto
  String? _projectPath;
  List<Map<String, dynamic>> _projectFiles = [];

  // Configurações
  double _fontSize = 14.0;

  // Teclado auxiliar
  static const _auxKeys = [
    'Tab',
    '{ }',
    '[ ]',
    '( )',
    '" "',
    "' '",
    '; :',
    '= >',
    '=>',
    '…',
  ];

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
        exists = true; // URIs SAF serão validadas na tentativa de carregamento
      } else {
        exists = Directory(savedProjectPath).existsSync();
      }

      if (exists) {
        await _loadProjectFiles(savedProjectPath);
      }
    }

    // Load Last Active File
    final savedActiveFile = prefs.getString('last_active_file');
    if (savedActiveFile != null) {
      bool exists = false;
      if (savedActiveFile.startsWith('content://')) {
        exists = true;
      } else {
        exists = File(savedActiveFile).existsSync();
      }

      if (exists) {
        final content = await FileService.readFile(savedActiveFile);
        _addTab(savedActiveFile, content);
      }
    } else {
      if (mounted && _openTabs.isEmpty) _createNewTab();
    }
  }

  Future<void> _updateFontSize(double newSize) async {
    if (!mounted) return;
    setState(() => _fontSize = newSize.clamp(8.0, 32.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_font_size', _fontSize);
  }

  Future<void> _saveActiveFilePreference(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('last_active_file', path);
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
        _showToast('Erro ao listar pasta SAF: $e');
      }
      return;
    }

    final dir = Directory(path);
    if (!dir.existsSync()) {
      _showToast('Erro: Pasta não encontrada em $path');
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
      _showToast('Erro ao listar arquivos: $e');
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
      _showToast('Erro ao listar arquivos remotos: $e');
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
  }

  String get _fileName {
    if (_activeTabIndex == -1) return 'JALIDE';
    return _activePath == null
        ? 'untitled.js'
        : FileUtils.getDisplayName(_activePath!);
  }

  String get _languageName {
    if (_activeTabIndex == -1 || _activePath == null) return 'JS';
    final ext = p.extension(_activePath!).toLowerCase();
    const map = {
      '.json': 'JSON',
      '.js': 'JS',
      '.jsx': 'JSX',
      '.ts': 'TS',
      '.tsx': 'TSX',
      '.mjs': 'ESM',
    };
    return map[ext] ?? 'TEXT';
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
      _showToast('Erro ao abrir arquivo: $e');
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
      };
      newTab['initialContent'] = content;
      newTab['controller'] = _createController(content, _langForPath(path), () {
        final isChanged = newTab['controller'].text != newTab['initialContent'];
        if (newTab['hasUnsavedChanges'] != isChanged) {
          setState(() => newTab['hasUnsavedChanges'] = isChanged);
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
  }

  Future<void> _saveFile() async {
    if (_activeTabIndex == -1) return;
    if (_activePath == null) {
      await _saveFileAs();
      return;
    }
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

      setState(() => _openTabs[_activeTabIndex]['hasUnsavedChanges'] = false);
      if (!mounted) return;
      _showToast('Salvo com sucesso');
    } catch (e) {
      _showToast('Erro ao salvar: $e');
      debugPrint('JALIDE_SAVE_ERROR: $e');
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
        _activeController.language = _langForPath(finalPath);
      });
      // Atualiza o explorer se o arquivo foi salvo na pasta do projeto
      if (_projectPath != null) await _loadProjectFiles(_projectPath!);
      _showToast('Salvo como ${p.basename(finalPath)}');
    } catch (e) {
      _showToast('Erro ao salvar como: $e');
      debugPrint('JALIDE_SAVE_AS_ERROR: $e');
    }
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

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        backgroundColor: _theme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _theme.accent, width: 1),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
      _showToast('✅ Workspace "$folderName" aberto!');
    } else {
      // Tenta mais uma vez com delay maior
      await Future.delayed(const Duration(seconds: 3));
      if (await symlinkDir.exists()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_project_path', symlinkTarget);
        await _loadProjectFiles(symlinkTarget);
        _showToast('✅ Workspace "$folderName" aberto!');
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

  Future<void> _showCreateDialog(bool isFile) async {
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
      await _createNewEntity(name.trim(), isFile);
    }
  }

  Future<void> _createNewEntity(String name, bool isFile) async {
    if (_projectPath == null) return;
    final path = p.join(_projectPath!, name);

    try {
      if (_isRemoteProject && _activeSshSession != null) {
        if (isFile) {
          await _activeSshSession!.writeFile(path, '');
          await _loadRemoteProjectFiles(_projectPath!);
          _addTab(path, '', isRemote: true);
          _showToast('Arquivo remoto criado: $name');
        } else {
          // Nota: O SFTP do dartssh2 não tem mkdir direto exposto no SshSession
          // Mas podemos usar o shell ou implementar mkdir no SshSession.
          // Vou usar o SshSession e adicionar um método mkdir lá.
          await _activeSshSession!.mkdir(path);
          await _loadRemoteProjectFiles(_projectPath!);
          _showToast('Pasta remota criada: $name');
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
        _showToast('Arquivo criado: $name');
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
      _showToast('Erro ao criar: $e');
    }
  }

  dynamic _langForPath(String? path) {
    if (path == null) return javascript;
    switch (p.extension(path).toLowerCase()) {
      case '.json':
        return json;
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
          onPickFolder: _pickProjectFolder,
          onOpenTermux: _openTermuxWorkspace,
          onCreateFile: () => _showCreateDialog(true),
          onCreateFolder: () => _showCreateDialog(false),
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
                  setState(() => _activeTabIndex = i);
                  _saveActiveFilePreference(_openTabs[i]['path'] as String?);
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
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AuxKeyboard(auxKeys: _auxKeys, onKeyTap: _insertSnippet),
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
          },
          itemBuilder: (_) => [
            _menuItem('new', 'Novo arquivo', Icons.add_outlined),
            _menuItem('save_as', 'Salvar como…', Icons.save_as_outlined),
            const PopupMenuDivider(),
            _menuItem('zoom_in', 'Aumentar fonte', Icons.zoom_in),
            _menuItem('zoom_out', 'Diminuir fonte', Icons.zoom_out),
            const PopupMenuDivider(),
            _menuItem('ssh', 'SSH Remote', Icons.cloud_outlined),
            _menuItem('theme', 'Mudar Tema', Icons.palette_outlined),
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

      _saveActiveFilePreference(
        _activeTabIndex != -1
            ? _openTabs[_activeTabIndex]['path'] as String?
            : null,
      );
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
              return RadioListTile<ThemeType>(
                title: Text(
                  type.name.toUpperCase(),
                  style: TextStyle(color: _theme.textPri, fontSize: 14),
                ),
                value: type,
                groupValue: provider.themeType,
                activeColor: _theme.accent,
                onChanged: (ThemeType? value) {
                  if (value != null) {
                    provider.setTheme(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _openSshScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SshConnectScreen(
          profileManager: _sshProfileManager,
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
