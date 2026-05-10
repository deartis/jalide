import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_service.dart';

// Paleta da IDE — inspirado no mockup
class JalideTheme {
  static const bg = Color(0xFF0D0D0F);
  static const surface = Color(0xFF111114);
  static const border = Color(0xFF1E1E24);
  static const accent = Color(0xFFE07B1A); // laranja JALIDE
  static const textPri = Color(0xFFCDD6F4);
  static const textMuted = Color(0xFF555566);

  static const kwColor = Color(0xFF7AA2F7);
  static const strColor = Color(0xFF9ECE6A);
  static const commentColor = Color(0xFF4A4A5A);
  static const varColor = Color(0xFF9D7CD8);
  static const numColor = Color(0xFFFF9E64);
  static const fnColor = Color(0xFF82AAFF);
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
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

  bool _isTerminalVisible = false;
  final List<String> _terminalLogs = [
    'JALIDE Terminal v0.1.0',
    'Initializing Node.js runtime...',
    'Ready.',
  ];

  // Explorer de Projeto
  String? _projectPath;
  List<FileSystemEntity> _projectFiles = [];

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
    // Aguarda o primeiro frame para evitar erro de layout (RenderBox not laid out)
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
    if (savedProjectPath != null && Directory(savedProjectPath).existsSync()) {
      await _loadProjectFiles(savedProjectPath);
    }

    // Load Last Active File
    final savedActiveFile = prefs.getString('last_active_file');
    if (savedActiveFile != null && File(savedActiveFile).existsSync()) {
      final content = await FileService.readFile(savedActiveFile);
      _addTab(savedActiveFile, content);
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
    final dir = Directory(path);
    if (!dir.existsSync()) return;
    final entities = await dir.list().toList();

    entities.sort((a, b) {
      if (a is Directory && b is! Directory) return -1;
      if (a is! Directory && b is Directory) return 1;
      return a.path.compareTo(b.path);
    });

    if (mounted) {
      setState(() {
        _projectPath = path;
        _projectFiles = entities;
      });
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
      if (!(newTab['hasUnsavedChanges'] as bool)) {
        setState(() => newTab['hasUnsavedChanges'] = true);
      }
    });

    setState(() {
      _openTabs.add(newTab);
      _activeTabIndex = _openTabs.length - 1;
    });
  }

  String get _fileName {
    if (_activeTabIndex == -1) return 'JALIDE';
    return _activePath == null ? 'untitled.js' : p.basename(_activePath!);
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

  Future<void> _openFile() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    final content = await FileService.readFile(path);
    _addTab(path, content);
  }

  void _addTab(String path, String content) {
    final existing = _openTabs.indexWhere((t) => t['path'] == path);
    if (existing == -1) {
      final Map<String, dynamic> newTab = {
        'path': path,
        'name': p.basename(path),
        'hasUnsavedChanges': false,
        'focusNode': FocusNode(),
      };
      newTab['controller'] = _createController(content, _langForPath(path), () {
        if (!(newTab['hasUnsavedChanges'] as bool)) {
          setState(() => newTab['hasUnsavedChanges'] = true);
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
    await FileService.saveFile(_activePath!, _activeController.text);
    setState(() => _openTabs[_activeTabIndex]['hasUnsavedChanges'] = false);
    if (!mounted) return;
    _showToast('Salvo');
  }

  Future<void> _saveFileAs() async {
    if (_activeTabIndex == -1) return;
    final path = await FilePicker.saveFile(
      dialogTitle: 'Salvar como',
      fileName: _activePath == null ? 'untitled.js' : p.basename(_activePath!),
    );
    if (path == null) {
      _showToast('Cancelado');
      return;
    }
    await FileService.saveFile(path, _activeController.text);
    setState(() {
      _openTabs[_activeTabIndex]['path'] = path;
      _openTabs[_activeTabIndex]['name'] = p.basename(path);
      _openTabs[_activeTabIndex]['hasUnsavedChanges'] = false;
      _activeController.language = _langForPath(path);
    });
    _showToast('Salvo como ${p.basename(path)}');
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
    final innerIndent = currentIndent + '  ';

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
        backgroundColor: JalideTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: JalideTheme.accent, width: 1),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickProjectFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_project_path', path);

    await _loadProjectFiles(path);
  }

  Future<void> _openFileFromExplorer(String path) async {
    final content = await FileService.readFile(path);
    _addTab(path, content);
    if (mounted) Navigator.pop(context); // Fecha o drawer
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
        statusBarColor: JalideTheme.bg,
        systemNavigationBarColor: JalideTheme.accent,
      ),
      child: Scaffold(
        backgroundColor: JalideTheme.bg,
        appBar: _buildAppBar(),
        drawer: _buildFileExplorer(),
        body: Column(
          children: [
            if (_openTabs.isNotEmpty) _buildTabBar(),
            Expanded(
              child: Stack(
                children: [
                  _buildEditor(),
                  if (_isTerminalVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildTerminalPanel(),
                    ),
                ],
              ),
            ),
            _buildAuxKeyboard(),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: JalideTheme.surface,
      elevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: JalideTheme.textMuted, size: 20),
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
              decoration: const BoxDecoration(
                color: JalideTheme.accent,
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
                          style: const TextStyle(
                            color: JalideTheme.textPri,
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
                          decoration: const BoxDecoration(
                            color: JalideTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_activePath != null)
                    Text(
                      _activePath!,
                      style: const TextStyle(
                        color: JalideTheme.textMuted,
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
          color: JalideTheme.textMuted,
          tooltip: 'Abrir arquivo',
        ),
        IconButton(
          onPressed: _activeHasUnsavedChanges ? _saveFile : null,
          icon: Icon(
            Icons.save_outlined,
            size: 20,
            color: _activeHasUnsavedChanges
                ? JalideTheme.accent
                : JalideTheme.textMuted,
          ),
          tooltip: 'Salvar',
        ),
        PopupMenuButton<String>(
          color: JalideTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: JalideTheme.border),
          ),
          onSelected: (v) async {
            if (v == 'new') _createNewTab();
            if (v == 'save_as') await _saveFileAs();
            if (v == 'zoom_in') _updateFontSize(_fontSize + 2);
            if (v == 'zoom_out') _updateFontSize(_fontSize - 2);
          },
          itemBuilder: (_) => [
            _menuItem('new', 'Novo arquivo', Icons.add_outlined),
            _menuItem('save_as', 'Salvar como…', Icons.save_as_outlined),
            const PopupMenuDivider(),
            _menuItem('zoom_in', 'Aumentar fonte', Icons.zoom_in),
            _menuItem('zoom_out', 'Diminuir fonte', Icons.zoom_out),
          ],
          icon: const Icon(
            Icons.more_vert,
            color: JalideTheme.textMuted,
            size: 20,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: JalideTheme.border),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String val, String label, IconData icon) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16, color: JalideTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: JalideTheme.textPri,
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
      (tab['controller'] as CodeController).dispose();
      (tab['focusNode'] as FocusNode).dispose();

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
          backgroundColor: JalideTheme.surface,
          title: const Text(
            'Alterações não salvas',
            style: TextStyle(color: JalideTheme.textPri),
          ),
          content: const Text(
            'Deseja fechar esta aba sem salvar as alterações?',
            style: TextStyle(color: JalideTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: JalideTheme.textMuted),
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

  Widget _buildTabBar() {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        border: Border(bottom: BorderSide(color: JalideTheme.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _openTabs.length,
        itemBuilder: (_, i) {
          final isActive = i == _activeTabIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _activeTabIndex = i);
              _saveActiveFilePreference(_openTabs[i]['path'] as String?);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? JalideTheme.surface : Colors.transparent,
                border: Border(
                  right: const BorderSide(color: JalideTheme.border),
                  bottom: BorderSide(
                    color: isActive ? JalideTheme.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (isActive)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: JalideTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _openTabs[i]['name']!,
                    style: TextStyle(
                      color: isActive
                          ? JalideTheme.textPri
                          : JalideTheme.textMuted,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _closeTab(i),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: isActive
                            ? JalideTheme.textPri
                            : JalideTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditor() {
    if (_activeTabIndex == -1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_rounded, size: 64, color: JalideTheme.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'JALIDE Editor',
              style: TextStyle(color: JalideTheme.textPri, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nenhum arquivo aberto',
              style: TextStyle(color: JalideTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Container(
      color: JalideTheme.bg,
      child: CodeTheme(
        data: CodeThemeData(
          keywordStyle: TextStyle(color: JalideTheme.kwColor),
          quoteStyle: TextStyle(color: JalideTheme.strColor),
          commentStyle: TextStyle(
            color: JalideTheme.commentColor,
            fontStyle: FontStyle.italic,
          ),
          variableStyle: TextStyle(color: JalideTheme.varColor),
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
            color: JalideTheme.textPri,
          ),
          cursorColor: JalideTheme.accent,
          gutterStyle: GutterStyle(
            textStyle: TextStyle(
              color: JalideTheme.textMuted,
              fontFamily: 'monospace',
              fontSize: _fontSize - 3 > 8 ? _fontSize - 3 : 8,
            ),
            width: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalPanel() {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      height: keyboardVisible ? 200 : 160,
      margin: keyboardVisible ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xEE0D0D0F), // Semi-transparente
        borderRadius: keyboardVisible
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        border: Border(
          top: BorderSide(color: JalideTheme.accent.withValues(alpha: 0.3)),
          left: keyboardVisible
              ? BorderSide(color: JalideTheme.accent.withValues(alpha: 0.3))
              : BorderSide.none,
          right: keyboardVisible
              ? BorderSide(color: JalideTheme.accent.withValues(alpha: 0.3))
              : BorderSide.none,
          bottom: keyboardVisible
              ? BorderSide(color: JalideTheme.accent.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        boxShadow: [
          if (keyboardVisible)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: keyboardVisible
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: JalideTheme.accent.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.terminal_outlined,
                    size: 14,
                    color: JalideTheme.accent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TERMINAL',
                    style: TextStyle(
                      color: JalideTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _isTerminalVisible = false),
                    icon: const Icon(
                      Icons.close,
                      size: 14,
                      color: JalideTheme.textMuted,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _terminalLogs.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '> ${_terminalLogs[i]}',
                    style: const TextStyle(
                      color: Color(0xFF9ECE6A),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Teclado auxiliar com teclas de programação — ESSENCIAL em mobile
  Widget _buildAuxKeyboard() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: JalideTheme.surface,
        border: Border(top: BorderSide(color: JalideTheme.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: _auxKeys.map((key) {
          final isSpecial = key == 'Tab';
          return GestureDetector(
            onTap: () => _insertSnippet(key),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isSpecial
                    ? JalideTheme.accent.withValues(alpha: 0.12)
                    : const Color(0xFF1A1A20),
                border: Border.all(
                  color: isSpecial ? JalideTheme.accent : JalideTheme.border,
                  width: isSpecial ? 1 : 0.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                key,
                style: TextStyle(
                  color: isSpecial ? JalideTheme.accent : JalideTheme.textMuted,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: JalideTheme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _isTerminalVisible = !_isTerminalVisible),
            child: _sbChip('⬡ Terminal'),
          ),
          const SizedBox(width: 12),
          _sbChip(_languageName),
          const SizedBox(width: 12),
          _sbChip('UTF-8'),
          const Spacer(),
          if (_activeHasUnsavedChanges)
            const Text(
              '●',
              style: TextStyle(color: Color(0xFF1A0A00), fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _sbChip(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF1A0A00),
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );

  IconData _iconForFile(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.js':
      case '.jsx':
      case '.mjs':
        return Icons.javascript;
      case '.json':
        return Icons.data_object;
      case '.md':
        return Icons.article_outlined;
      case '.html':
        return Icons.html;
      case '.css':
        return Icons.css;
      case '.png':
      case '.jpg':
      case '.svg':
      case '.ico':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _colorForFile(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.js':
      case '.jsx':
      case '.mjs':
        return const Color(0xFFE8D44D); // Yellow JS
      case '.json':
        return const Color(0xFF8BC34A); // Green JSON
      case '.md':
        return const Color(0xFF29B6F6); // Blue Markdown
      case '.html':
        return const Color(0xFFFF9800); // Orange HTML
      case '.css':
        return const Color(0xFF03A9F4); // Blue CSS
      case '.png':
      case '.jpg':
      case '.svg':
      case '.ico':
        return const Color(0xFFAB47BC); // Purple Image
      default:
        return JalideTheme.textMuted;
    }
  }

  Widget _buildExplorerNode(FileSystemEntity entity) {
    final name = p.basename(entity.path);
    final isDir = entity is Directory;

    if (isDir) {
      // Ignorar pastas ocultas comuns em projetos (como .git) para não travar
      if (name.startsWith('.')) return const SizedBox();

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(entity.path),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(
            Icons.folder_rounded,
            color: JalideTheme.accent,
            size: 18,
          ),
          title: Text(
            name,
            style: const TextStyle(
              color: JalideTheme.textPri,
              fontSize: 13,
              fontFamily: 'sans-serif',
            ),
          ),
          iconColor: JalideTheme.accent,
          collapsedIconColor: JalideTheme.textMuted,
          childrenPadding: const EdgeInsets.only(left: 12),
          children: [
            FutureBuilder<List<FileSystemEntity>>(
              future: (entity).list().toList().then((list) {
                list.sort((a, b) {
                  if (a is Directory && b is! Directory) return -1;
                  if (a is! Directory && b is Directory) return 1;
                  return a.path.compareTo(b.path);
                });
                return list;
              }),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: JalideTheme.accent,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: snapshot.data!.map(_buildExplorerNode).toList(),
                );
              },
            ),
          ],
        ),
      );
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16, right: 16),
      leading: Icon(_iconForFile(name), color: _colorForFile(name), size: 18),
      title: Text(
        name,
        style: const TextStyle(
          color: JalideTheme.textPri,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
      onTap: () => _openFileFromExplorer(entity.path),
    );
  }

  Widget _buildFileExplorer() {
    return Drawer(
      backgroundColor: JalideTheme.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            color: JalideTheme.surface,
            child: Row(
              children: [
                const Icon(
                  Icons.folder_copy_outlined,
                  color: JalideTheme.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _projectPath == null
                        ? 'EXPLORER'
                        : p.basename(_projectPath!),
                    style: const TextStyle(
                      color: JalideTheme.textPri,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _pickProjectFolder,
                  icon: const Icon(
                    Icons.create_new_folder_outlined,
                    color: JalideTheme.textMuted,
                    size: 20,
                  ),
                  tooltip: 'Selecionar pasta projeto',
                ),
              ],
            ),
          ),
          Expanded(
            child: _projectPath == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 48,
                          color: JalideTheme.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum projeto aberto',
                          style: TextStyle(
                            color: JalideTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _pickProjectFolder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: JalideTheme.accent,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('ABRIR PASTA'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _projectFiles.map(_buildExplorerNode).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
