import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/editor_tab.dart';
import '../utils/code_completion.dart';
import '../utils/file_utils.dart';

class EditorTabController extends ChangeNotifier {
  final List<EditorTab> _openTabs = [];
  int _activeTabIndex = -1;

  // Callbacks que EditorScreen conecta
  void Function(int tabIndex, bool isUnsaved)? onUnsavedChanged;
  void Function(int tabIndex)? onAutoSaveTriggered;

  // ─── Getters ──────────────────────────────────────────────────────────────

  CodeController? get activeController =>
      _activeTabIndex != -1 ? _openTabs[_activeTabIndex].controller : null;

  FocusNode? get activeFocusNode =>
      _activeTabIndex != -1 ? _openTabs[_activeTabIndex].focusNode : null;

  String? get activePath =>
      _activeTabIndex != -1 ? _openTabs[_activeTabIndex].path : null;

  bool get hasUnsavedChanges => _activeTabIndex != -1
      ? _openTabs[_activeTabIndex].hasUnsavedChanges
      : false;

  List<EditorTab> get openTabs => _openTabs;
  int get activeTabIndex => _activeTabIndex;
  bool get hasTabs => _openTabs.isNotEmpty;
  int get tabCount => _openTabs.length;

  String get fileName {
    if (_activeTabIndex == -1) return 'JALIDE';
    final path = activePath;
    return path == null ? 'untitled.js' : FileUtils.getDisplayName(path);
  }

  String get languageName {
    if (_activeTabIndex == -1) return 'JS';
    return _openTabs[_activeTabIndex].languageName;
  }

  EditorTab? get activeTab =>
      _activeTabIndex != -1 ? _openTabs[_activeTabIndex] : null;

  // ─── Tab Operations ───────────────────────────────────────────────────────

  void addOrActivateTab(String path, String content, {bool isRemote = false}) {
    final existing = _openTabs.indexWhere((t) => t.path == path);
    if (existing == -1) {
      final newTab = EditorTab(
        path: path,
        name: FileUtils.getDisplayName(path),
        isRemote: isRemote,
        focusNode: FocusNode(),
        initialContent: content,
        languageName: getInitialLanguageName(path),
      );
      newTab.controller = _createController(content, langForPath(path), newTab);
      _openTabs.add(newTab);
      _activeTabIndex = _openTabs.length - 1;
    } else {
      _activeTabIndex = existing;
    }
    notifyListeners();
    unawaited(_saveTabsPreference());
  }

  void createNewTab() {
    final newTab = EditorTab(focusNode: FocusNode(), languageName: 'JS');
    newTab.controller = _createController('', javascript, newTab);
    _openTabs.add(newTab);
    _activeTabIndex = _openTabs.length - 1;
    notifyListeners();
    unawaited(_saveTabsPreference());
  }

  void setActiveTab(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
      unawaited(_saveTabsPreference());
    }
  }

  void closeTab(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    final tab = _openTabs[index];
    final controller = tab.controller;
    final focusNode = tab.focusNode;

    _openTabs.removeAt(index);
    if (_activeTabIndex == index) {
      _activeTabIndex = _openTabs.isNotEmpty ? (index > 0 ? index - 1 : 0) : -1;
    } else if (_activeTabIndex > index) {
      _activeTabIndex--;
    }

    notifyListeners();

    Future.microtask(() {
      controller.dispose();
      focusNode.dispose();
    });

    unawaited(_saveTabsPreference());
  }

  void updateLanguage(int index, String displayName, Mode? language) {
    if (index < 0 || index >= _openTabs.length) return;
    _openTabs[index].languageName = displayName;
    _openTabs[index].controller.language = language;
    applyLanguageSuggestions(_openTabs[index].controller, displayName);
    notifyListeners();
  }

  void markTabSaved(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    _openTabs[index].hasUnsavedChanges = false;
    _openTabs[index].initialContent = _openTabs[index].controller.text;
    notifyListeners();
  }

  void updateTabPath(int index, String path) {
    if (index < 0 || index >= _openTabs.length) return;
    _openTabs[index].path = path;
    _openTabs[index].name = p.basename(path);
    notifyListeners();
  }

  void updateTabLanguageFromPath(int index, String path) {
    if (index < 0 || index >= _openTabs.length) return;
    _openTabs[index].languageName = getInitialLanguageName(path);
    _openTabs[index].controller.language = langForPath(path);
    notifyListeners();
  }

  // ─── Controller Creation ──────────────────────────────────────────────────

  CodeController _createController(
    String text,
    Mode? language,
    EditorTab tab,
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

    final langName = getLanguageDisplayName(language);
    applyLanguageSuggestions(controller, langName);

    controller.addListener(() {
      final tabIndex = _openTabs.indexOf(tab);
      if (tabIndex == -1) return;

      final initial = tab.initialContent;
      final isChanged = controller.text != initial;
      if (tab.hasUnsavedChanges != isChanged) {
        tab.hasUnsavedChanges = isChanged;
        onUnsavedChanged?.call(tabIndex, isChanged);
        notifyListeners();
      }

      if (isChanged) {
        onAutoSaveTriggered?.call(tabIndex);
      }
    });

    return controller;
  }

  // ─── Language Helpers ─────────────────────────────────────────────────────

  static String getLanguageDisplayName(Mode? language) {
    if (language == null) return 'JS';
    if (language == javascript) return 'JS';
    if (language == json) return 'JSON';
    if (language == python) return 'Python';
    if (language == xml) return 'HTML';
    if (language == css) return 'CSS';
    if (language == dart) return 'Dart';
    if (language == cpp) return 'C++';
    if (language == markdown) return 'Markdown';
    return 'JS';
  }

  static Mode? langForPath(String? path) {
    if (path == null) return javascript;
    switch (p.extension(path).toLowerCase()) {
      case '.json': return json;
      case '.py':
      case '.pyw': return python;
      case '.html':
      case '.htm': return xml;
      case '.css': return css;
      case '.dart': return dart;
      case '.cpp':
      case '.hpp':
      case '.cc':
      case '.c':
      case '.h': return cpp;
      case '.md':
      case '.markdown': return markdown;
      default: return javascript;
    }
  }

  static String getInitialLanguageName(String? path) {
    if (path == null) return 'JS';
    final ext = p.extension(path).toLowerCase();
    const map = {
      '.json': 'JSON', '.js': 'JS', '.jsx': 'JS', '.ts': 'TS', '.tsx': 'TSX',
      '.mjs': 'ESM', '.py': 'Python', '.pyw': 'Python',
      '.html': 'HTML', '.htm': 'HTML', '.css': 'CSS', '.dart': 'Dart',
      '.cpp': 'C++', '.hpp': 'C++', '.cc': 'C++', '.c': 'C', '.h': 'C/C++',
      '.md': 'Markdown', '.markdown': 'Markdown',
    };
    return map[ext] ?? 'TEXT';
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  Future<void> saveTabsPreference() => _saveTabsPreference();

  Future<void> _saveTabsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final validTabs = _openTabs
        .where((t) => t.path != null && t.path!.isNotEmpty)
        .toList();
    final tabsData = validTabs.map((t) {
      return {'path': t.path, 'isRemote': t.isRemote};
    }).toList();
    await prefs.setString('persisted_open_tabs', jsonEncode(tabsData));

    if (_activeTabIndex != -1 && _activeTabIndex < _openTabs.length) {
      final activePath = _openTabs[_activeTabIndex].path;
      if (activePath != null && activePath.isNotEmpty) {
        await prefs.setString('last_active_file', activePath);
      } else {
        await prefs.remove('last_active_file');
      }
    } else {
      await prefs.remove('last_active_file');
    }
  }

  Future<void> loadTabsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedTabsStr = prefs.getString('persisted_open_tabs');
    if (persistedTabsStr != null) {
      try {
        final List<dynamic> tabsData = jsonDecode(persistedTabsStr);
        for (final tabData in tabsData) {
          final String? path = tabData['path'];
          final bool isRemote = tabData['isRemote'] as bool? ?? false;
          if (path != null && path.isNotEmpty) {
            addOrActivateTab(path, '', isRemote: isRemote);
          }
        }
      } catch (_) {}
    }

    final savedActiveFile = prefs.getString('last_active_file');
    if (savedActiveFile != null) {
      final index = _openTabs.indexWhere((t) => t.path == savedActiveFile);
      if (index != -1) {
        _activeTabIndex = index;
        notifyListeners();
      }
    }

    if (_openTabs.isEmpty) {
      createNewTab();
    }
  }

  void disposeTabs() {
    for (final tab in _openTabs) {
      tab.controller.dispose();
      tab.focusNode.dispose();
    }
    _openTabs.clear();
    _activeTabIndex = -1;
  }
}
