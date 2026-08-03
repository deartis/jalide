import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import '../controllers/editor_tab_controller.dart';
import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';

class ModuleContext {
  final EditorTabController tabController;
  final CodeController? Function() getActiveController;
  final String? Function() getActivePath;
  final String? Function() getProjectPath;
  final JalideThemeVariant Function() getTheme;
  final bool Function() getIsRemoteProject;
  final SshSession? Function() getSshSession;
  final void Function(String message, {String type}) showToast;
  final void Function(VoidCallback fn) setState;
  final void Function(String path) openFile;
  final Future<void> Function() saveCurrentFile;
  final Future<void> Function()? formatCode;

  ModuleContext({
    required this.tabController,
    required this.getActiveController,
    required this.getActivePath,
    required this.getProjectPath,
    required this.getTheme,
    required this.getIsRemoteProject,
    required this.getSshSession,
    required this.showToast,
    required this.setState,
    required this.openFile,
    required this.saveCurrentFile,
    this.formatCode,
  });

  CodeController? get activeController => getActiveController();
  String? get activePath => getActivePath();
  String? get projectPath => getProjectPath();
  JalideThemeVariant get theme => getTheme();
  bool get isRemoteProject => getIsRemoteProject();
  SshSession? get sshSession => getSshSession();
}
