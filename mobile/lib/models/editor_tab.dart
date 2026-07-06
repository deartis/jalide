import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

class EditorTab {
  late final CodeController controller;
  final FocusNode focusNode;
  String? path;
  String name;
  bool hasUnsavedChanges;
  String? initialContent;
  bool isRemote;
  String languageName;
  final EditorTabHistory history = EditorTabHistory();

  EditorTab({
    required this.focusNode,
    this.path,
    this.name = 'untitled.js',
    this.hasUnsavedChanges = false,
    this.initialContent,
    this.isRemote = false,
    this.languageName = 'JS',
  });
}

class EditorTabHistory {
  final List<TextEditingValue> _undoStack = [];
  final List<TextEditingValue> _redoStack = [];
  static const int maxHistorySize = 100;

  TextEditingValue? _lastValue;
  Timer? _debounceTimer;
  bool isExecutingUndoRedo = false;

  void record(TextEditingValue value) {
    if (isExecutingUndoRedo) {
      _lastValue = value;
      return;
    }

    if (_lastValue == null) {
      _lastValue = value;
      return;
    }

    if (_lastValue!.text == value.text) {
      // Se o texto não mudou (apenas seleção/cursor), atualiza a última referência
      _lastValue = value;
      return;
    }

    _debounceTimer?.cancel();

    if (_shouldCommitImmediately(_lastValue!.text, value.text)) {
      _commit(value);
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 800), () {
        _commit(value);
      });
    }
  }

  bool _shouldCommitImmediately(String oldText, String newText) {
    final diff = (newText.length - oldText.length).abs();
    if (diff > 1) return true; // Colagem, deleção em lote ou inserção programática
    if (newText.endsWith(' ') || newText.endsWith('\n') || newText.endsWith('\t')) return true;
    return false;
  }

  void _commit(TextEditingValue value) {
    if (_lastValue != null) {
      if (_undoStack.isEmpty || _undoStack.last.text != _lastValue!.text) {
        _undoStack.add(_lastValue!);
        if (_undoStack.length > maxHistorySize) {
          _undoStack.removeAt(0);
        }
      }
      _redoStack.clear();
    }
    _lastValue = value;
  }

  void forceRecord(TextEditingValue value) {
    if (isExecutingUndoRedo) return;
    _debounceTimer?.cancel();
    _commit(value);
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  TextEditingValue? undo(TextEditingValue currentValue) {
    _debounceTimer?.cancel();
    if (!canUndo) return null;

    _redoStack.add(currentValue);
    final previous = _undoStack.removeLast();
    _lastValue = previous;
    return previous;
  }

  TextEditingValue? redo(TextEditingValue currentValue) {
    _debounceTimer?.cancel();
    if (!canRedo) return null;

    _undoStack.add(currentValue);
    final next = _redoStack.removeLast();
    _lastValue = next;
    return next;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _undoStack.clear();
    _redoStack.clear();
    _lastValue = null;
  }
}
