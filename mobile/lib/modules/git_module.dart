import 'package:flutter/material.dart';
import '../services/git_service.dart';
import 'editor_module.dart';
import 'module_context.dart';

class GitModule extends EditorModule {
  @override
  String get id => 'git';

  @override
  String get name => 'Git Version Control';

  ModuleContext? _ctx;
  GitStatus? _status;
  String? _branch;

  @override
  void init(ModuleContext ctx) {
    _ctx = ctx;
    refreshStatus();
  }

  @override
  void dispose() {
    _ctx = null;
    _status = null;
    _branch = null;
  }

  Future<void> refreshStatus() async {
    final ctx = _ctx;
    if (ctx == null) return;
    final projectPath = ctx.projectPath;
    if (projectPath == null || projectPath.isEmpty) return;

    try {
      final isRepo = await GitService.isGitRepo(projectPath);
      if (!isRepo) {
        _status = null;
        _branch = null;
      } else {
        _status = await GitService.getStatus(projectPath);
        _branch = await GitService.getCurrentBranch(projectPath);
      }
    } catch (_) {
      _status = null;
      _branch = null;
    } finally {
      ctx.setState(() {});
    }
  }

  @override
  List<ModuleCommand> get commands => [
        ModuleCommand(
          label: 'Git: Atualizar Status',
          icon: Icons.refresh,
          category: 'Git',
          onTap: () {
            refreshStatus();
            _ctx?.showToast('Status do Git atualizado');
          },
        ),
        ModuleCommand(
          label: 'Git: Exibir Branch Atual',
          icon: Icons.alt_route_rounded,
          category: 'Git',
          onTap: () {
            final b = _branch ?? 'Sem repositório Git';
            _ctx?.showToast('Branch Git: $b');
          },
        ),
      ];

  @override
  Map<String, VoidCallback> get shortcuts => {
        'Ctrl+Shift+G': () {
          refreshStatus();
          _ctx?.showToast('Git: ${_branch ?? "Sem repo"}');
        },
      };

  @override
  List<Widget> get statusBarItems {
    final branch = _branch;
    if (branch == null || branch.isEmpty) return const [];

    final theme = _ctx?.theme;
    return [
      InkWell(
        onTap: refreshStatus,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.alt_route_rounded,
                size: 12,
                color: theme?.accent ?? Colors.blueAccent,
              ),
              const SizedBox(width: 4),
              Text(
                branch,
                style: TextStyle(
                  fontSize: 11,
                  color: theme?.textPri ?? Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_status != null) ...[
                const SizedBox(width: 6),
                Text(
                  '+${_status!.files.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}
