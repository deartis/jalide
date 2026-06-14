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
