import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';
import '../utils/file_utils.dart';
import '../utils/path_navigator.dart';
import '../screens/donation_screen.dart';

class FileExplorerDrawer extends StatefulWidget {
  final String? projectPath;
  final List<Map<String, dynamic>> projectFiles;
  final Function(String) onFileTap;
  final Function(String) onNavigateFolder;
  final VoidCallback onPickFolder;
  final VoidCallback onOpenTermux;
  final void Function(String?) onCreateFile;
  final void Function(String?) onCreateFolder;
  final void Function(String path, bool isDir, bool isRemote, bool isSaf) onDeleteItem;
  final void Function(String path, String newName, bool isDir, bool isRemote, bool isSaf) onRenameItem;
  final MethodChannel termuxChannel;
  final SshSession? sshSession;
  final bool isRemoteProject;

  const FileExplorerDrawer({
    super.key,
    required this.projectPath,
    required this.projectFiles,
    required this.onFileTap,
    required this.onNavigateFolder,
    required this.onPickFolder,
    required this.onOpenTermux,
    required this.onCreateFile,
    required this.onCreateFolder,
    required this.onDeleteItem,
    required this.onRenameItem,
    required this.termuxChannel,
    this.sshSession,
    this.isRemoteProject = false,
  });

  @override
  State<FileExplorerDrawer> createState() => _FileExplorerDrawerState();
}

class _FileExplorerDrawerState extends State<FileExplorerDrawer> {
  late PathNavigator _pathNavigator;
  String? _currentPath;
  String? _selectedPath;
  bool _isSelectedPathDir = true;
  final Map<String, Future<List<Map<String, dynamic>>>> _expandedDirsCache = {};

  @override
  void initState() {
    super.initState();
    _pathNavigator = PathNavigator();
    _currentPath = widget.projectPath;
    _selectedPath = widget.projectPath;
    _isSelectedPathDir = true;
    if (_currentPath != null) {
      _pathNavigator.push(_currentPath!);
    }
  }

  void _navigateTo(String path) {
    if (path != _currentPath) {
      setState(() {
        _pathNavigator.push(path);
        _currentPath = path;
        _selectedPath = path;
        _isSelectedPathDir = true;
      });
      widget.onNavigateFolder(path);
    }
  }



  void _selectFolderInTree(String path) {
    setState(() {
      _selectedPath = path;
      _isSelectedPathDir = true;
    });
  }

  void _clearSelection() {
    if (widget.projectPath != null) {
      setState(() {
        _selectedPath = widget.projectPath;
        _isSelectedPathDir = true;
      });
    }
  }

  void _showItemActions({
    required String path,
    required bool isDir,
    required bool isRemote,
    required bool isSaf,
    required String label,
  }) {
    final theme = ThemeProvider.of(context).current;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.accent.withValues(alpha: 0.18),
                      theme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isDir ? Icons.folder_rounded : Icons.insert_drive_file,
                            color: theme.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: theme.textPri,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDir
                          ? 'Pasta • ações disponíveis'
                          : 'Arquivo • ações disponíveis',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Column(
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.delete_outline,
                      title: 'Excluir',
                      subtitle: isDir
                          ? 'Excluir esta pasta e o conteúdo interno'
                          : 'Excluir este arquivo',
                      accent: Colors.redAccent,
                      onTap: () async {
                        Navigator.pop(ctx);
                        String typedValue = '';
                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (confirmCtx) => PopScope(
                            canPop: false,
                            child: StatefulBuilder(
                              builder: (dialogContext, setState) {
                                final canConfirm = typedValue.trim() == label;

                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: theme.surface,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: theme.border, width: 1),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: const Icon(
                                                Icons.delete_forever,
                                                color: Colors.redAccent,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                'Confirmar exclusão',
                                                style: TextStyle(
                                                  color: theme.textPri,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Esta ação é irreversível. Digite "$label" para confirmar a exclusão de ${isDir ? 'a pasta' : 'o arquivo'}.',
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        TextField(
                                          autofocus: true,
                                          textInputAction: TextInputAction.done,
                                          onChanged: (value) {
                                            typedValue = value;
                                            setState(() {});
                                          },
                                          decoration: InputDecoration(
                                            hintText: label,
                                            hintStyle: TextStyle(color: theme.textMuted),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: theme.border),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(color: Colors.redAccent),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(confirmCtx, false),
                                              child: Text(
                                                'Cancelar',
                                                style: TextStyle(color: theme.textMuted),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: canConfirm ? () => Navigator.pop(confirmCtx, true) : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              icon: const Icon(Icons.delete_outline, size: 18),
                                              label: const Text('Excluir'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        if (confirmed == true) {
                          widget.onDeleteItem(path, isDir, isRemote, isSaf);
                        }
                      },
                    ),
                    const Divider(height: 1, color: Color(0x1FFFFFFF)),
                    _buildActionTile(
                      context,
                      icon: Icons.edit_outlined,
                      title: 'Renomear',
                      subtitle: isDir ? 'Renomear esta pasta' : 'Renomear este arquivo',
                      accent: const Color(0xFF7AA2F7),
                      onTap: () async {
                        Navigator.pop(ctx);
                        String typedValue = label;
                        final newName = await showDialog<String>(
                          context: context,
                          barrierDismissible: false,
                          builder: (confirmCtx) => StatefulBuilder(
                            builder: (dialogContext, setState) {
                              final canConfirm = typedValue.trim().isNotEmpty && typedValue.trim() != label;
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: theme.border, width: 1),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7AA2F7).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(Icons.edit, color: Color(0xFF7AA2F7), size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              'Renomear',
                                              style: TextStyle(color: theme.textPri, fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Digite o novo nome para ${isDir ? 'a pasta' : 'o arquivo'}:',
                                        style: TextStyle(color: theme.textMuted, fontSize: 14, height: 1.4),
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        autofocus: true,
                                        initialValue: label,
                                        onChanged: (value) {
                                          typedValue = value;
                                          setState(() {});
                                        },
                                        style: TextStyle(color: theme.textPri),
                                        decoration: InputDecoration(
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF7AA2F7))),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(confirmCtx, false),
                                            child: Text('Cancelar', style: TextStyle(color: theme.textMuted)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: canConfirm ? () => Navigator.pop(confirmCtx, typedValue.trim()) : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF7AA2F7),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            icon: const Icon(Icons.check, size: 18),
                                            label: const Text('Renomear'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                        if (newName != null) {
                          widget.onRenameItem(path, newName, isDir, isRemote, isSaf);
                        }
                      },
                    ),
                    if (isDir) ...[
                      const Divider(height: 1, color: Color(0x1FFFFFFF)),
                      _buildActionTile(
                        context,
                        icon: Icons.note_add_outlined,
                        title: 'Novo arquivo',
                        subtitle: 'Criar um novo arquivo dentro desta pasta',
                        accent: const Color(0xFF2AC3DE),
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onCreateFile(path);
                        },
                      ),
                      const Divider(height: 1, color: Color(0x1FFFFFFF)),
                      _buildActionTile(
                        context,
                        icon: Icons.create_new_folder_outlined,
                        title: 'Nova pasta',
                        subtitle: 'Criar uma nova subpasta dentro desta pasta',
                        accent: const Color(0xFF9ECE6A),
                        onTap: () {
                          Navigator.pop(ctx);
                          widget.onCreateFolder(path);
                        },
                      ),
                      const Divider(height: 1, color: Color(0x1FFFFFFF)),
                      _buildActionTile(
                        context,
                        icon: Icons.folder_open_outlined,
                        title: 'Navegar',
                        subtitle: 'Definir esta pasta como raiz do explorador',
                        accent: theme.accent,
                        onTap: () {
                          Navigator.pop(ctx);
                          _navigateTo(path);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Fechar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final theme = ThemeProvider.of(context).current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textPri,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant FileExplorerDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectPath != oldWidget.projectPath) {
      _expandedDirsCache.clear();
      if (widget.projectPath != null && _currentPath != widget.projectPath) {
        _pathNavigator.push(widget.projectPath!);
        _currentPath = widget.projectPath;
        _selectedPath = widget.projectPath;
        _isSelectedPathDir = true;
      }
    } else if (widget.projectFiles != oldWidget.projectFiles) {
      _expandedDirsCache.clear();
    }
  }

  Future<List<Map<String, dynamic>>> _getDirFuture(String path, bool isRemote, bool isSaf) {
    return _expandedDirsCache.putIfAbsent(path, () {
      if (isRemote) {
        return widget.sshSession
              ?.listDir(path)
              .then(
                (res) => res
                    .map(
                      (f) => {
                        'name': f.name,
                        'path': f.path,
                        'isDir': f.isDir,
                        'isSaf': false,
                        'isRemote': true,
                      },
                    )
                    .toList(),
              ) ?? Future.value([]);
      } else if (isSaf) {
        return widget.termuxChannel
              .invokeMethod('listSafDirectory', {'uri': path})
              .then(
                (res) => (res as List)
                    .map(
                      (f) => {
                        'name': f['name'] as String,
                        'path': f['uri'] as String,
                        'isDir': f['isDir'] as bool,
                        'isSaf': true,
                        'isRemote': false,
                      },
                    )
                    .toList(),
              );
      } else {
        return Directory(path).list().toList().then((list) {
          list.sort((a, b) {
            if (a is Directory && b is! Directory) return -1;
            if (a is! Directory && b is Directory) return 1;
            return a.path.compareTo(b.path);
          });
          return list
              .map(
                (e) => {
                  'name': p.basename(e.path),
                  'path': e.path,
                  'isDir': e is Directory,
                  'isSaf': false,
                  'isRemote': false,
                },
              )
              .toList();
        });
      }
    });
  }

  void _goBack() {
    final prevPath = _pathNavigator.popBack();
    if (prevPath != null) {
      setState(() {
        _currentPath = prevPath;
        _selectedPath = prevPath;
      });
      widget.onNavigateFolder(prevPath);
    }
  }

  void _goForward() {
    final nextPath = _pathNavigator.moveForward();
    if (nextPath != null) {
      setState(() {
        _currentPath = nextPath;
        _selectedPath = nextPath;
      });
      widget.onNavigateFolder(nextPath);
    }
  }

  void _goToHome() {
    String homePath;
    if (widget.isRemoteProject) {
      homePath = '/home';
    } else {
      if (Platform.isAndroid) {
        homePath = '/storage/emulated/0';
      } else if (Platform.isLinux || Platform.isMacOS) {
        homePath = Platform.environment['HOME'] ?? '/';
      } else if (Platform.isWindows) {
        homePath = Platform.environment['USERPROFILE'] ?? 'C:\\';
      } else {
        homePath = '/';
      }
    }
    _navigateTo(homePath);
  }

  void _goToRoot() {
    _navigateTo('/');
  }

  String? _getParentPath() {
    final current = _currentPath ?? widget.projectPath;
    if (current == null || current.isEmpty) return null;
    if (widget.isRemoteProject) {
      if (current == '/' || current == '.' || current == '..') return null;
      final parent = p.posix.dirname(current);
      if (parent == current || parent.isEmpty) return null;
      return parent;
    }
    if (current == '/' || current == '.' || current == '..') return null;
    final parent = p.dirname(current);
    if (parent == current || parent.isEmpty) return null;
    return parent;
  }

  List<String> _getPathSegments(String path) {
    final segments = path
        .split(Platform.pathSeparator)
        .where((s) => s.isNotEmpty)
        .toList();
    if (Platform.isWindows && path.startsWith(RegExp(r'^[A-Z]:'))) {
      segments.insert(0, path.substring(0, 2));
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    return Drawer(
      backgroundColor: theme.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 8, 8),
            color: theme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _clearSelection,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: _selectedPath == widget.projectPath
                        ? BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.accent.withValues(alpha: 0.3), width: 1),
                          )
                        : null,
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_copy_outlined,
                          color: theme.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.projectPath == null
                                ? 'EXPLORER'
                                : widget.isRemoteProject
                                ? 'REMOTE: ${p.basename(widget.projectPath!)}'
                                : FileUtils.getDisplayName(
                                    widget.projectPath!,
                                    uppercase: true,
                                  ),
                            style: TextStyle(
                              color: widget.isRemoteProject
                                  ? theme.accent
                                  : theme.textPri,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.projectPath != null) ...[
                      IconButton(
                        onPressed: () {
                          final targetPath = _isSelectedPathDir
                              ? _selectedPath
                              : (widget.isRemoteProject
                                  ? p.posix.dirname(_selectedPath!)
                                  : p.dirname(_selectedPath!));
                          widget.onCreateFile(targetPath);
                        },
                        icon: Icon(
                          Icons.note_add_outlined,
                          color: theme.textMuted,
                          size: 20,
                        ),
                        tooltip: 'Novo Arquivo',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final targetPath = _isSelectedPathDir
                              ? _selectedPath
                              : (widget.isRemoteProject
                                  ? p.posix.dirname(_selectedPath!)
                                  : p.dirname(_selectedPath!));
                          widget.onCreateFolder(targetPath);
                        },
                        icon: Icon(
                          Icons.create_new_folder_outlined,
                          color: theme.textMuted,
                          size: 20,
                        ),
                        tooltip: 'Nova Pasta',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      onPressed: widget.onPickFolder,
                      icon: Icon(
                        Icons.folder_open_outlined,
                        color: theme.textMuted,
                        size: 20,
                      ),
                      tooltip: 'Selecionar pasta projeto',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (widget.projectPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildNavigationBar(theme),
                  ),
              ],
            ),
          ),

          Expanded(
            child: widget.projectPath == null
                ? _buildEmptyState(theme)
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: widget.projectFiles
                        .map((item) => _buildExplorerNode(context, item))
                        .toList(),
                  ),
          ),
          Divider(
            height: 1,
            color: theme.accent.withValues(alpha: 0.15),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DonationScreen()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pague-me um café ☕',
                      style: TextStyle(
                        color: theme.textPri,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(JalideThemeVariant theme) {
    final segments = _getPathSegments(_currentPath ?? '/');

    return Container(
      color: theme.bg.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Botão voltar
            Tooltip(
              message: 'Voltar',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pathNavigator.canGoBack ? _goBack : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: _pathNavigator.canGoBack
                          ? theme.textPri
                          : theme.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Botão avançar
            Tooltip(
              message: 'Avançar',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pathNavigator.canGoForward ? _goForward : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: _pathNavigator.canGoForward
                          ? theme.textPri
                          : theme.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Botão subir pasta
            Tooltip(
              message: 'Subir pasta',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _getParentPath() != null
                        ? () => _navigateTo(_getParentPath()!)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: _getParentPath() != null
                          ? theme.textPri
                          : theme.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Botão home
            Tooltip(
              message: 'Home',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goToHome,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.home_rounded,
                      size: 16,
                      color: theme.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Botão raiz
            Tooltip(
              message: 'Raíz (/) ',
              child: SizedBox(
                width: 28,
                height: 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goToRoot,
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.storage_rounded,
                      size: 16,
                      color: theme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Breadcrumb
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (int i = 0; i < segments.length; i++) ...[
                    GestureDetector(
                      onTap: () {
                        final pathToNavigate = i == 0 && !Platform.isWindows
                            ? '/'
                            : segments.sublist(0, i + 1).join('/');
                        _navigateTo(pathToNavigate);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: i == segments.length - 1
                              ? theme.accent.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          segments[i].length > 15
                              ? '${segments[i].substring(0, 12)}...'
                              : segments[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: i == segments.length - 1
                                ? theme.accent
                                : theme.textMuted,
                            fontWeight: i == segments.length - 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    if (i < segments.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '/',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textMuted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(JalideThemeVariant theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 48,
            color: theme.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum projeto aberto',
            style: TextStyle(color: theme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.onPickFolder,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('ABRIR PASTA'),
          ),
          const SizedBox(height: 10),
          if (Platform.isAndroid)
            ElevatedButton.icon(
              onPressed: widget.onOpenTermux,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3A1B),
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50), width: 1),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.terminal, size: 16),
              label: const Text('ABRIR DO TERMUX'),
            ),
          if (widget.sshSession != null && widget.sshSession!.isConnected) ...[
            const SizedBox(height: 20),
            const Divider(indent: 40, endIndent: 40),
            const SizedBox(height: 10),
            Text(
              'SSH ATIVO: ${widget.sshSession!.profile.label}',
              style: TextStyle(
                color: theme.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplorerNode(BuildContext context, Map<String, dynamic> item) {
    final theme = ThemeProvider.of(context).current;
    final name = item['name'] as String;
    final path = item['path'] as String;
    final isDir = item['isDir'] as bool;
    final isSaf = item['isSaf'] as bool;
    final isRemote = item['isRemote'] as bool? ?? false;

    if (isDir) {
      if (name.startsWith('.')) return const SizedBox();

      final isSelected = path == _selectedPath;
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(path),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          iconColor: theme.accent,
          collapsedIconColor: theme.textMuted,
          childrenPadding: const EdgeInsets.only(left: 12),
          title: InkWell(
            onTap: () => _selectFolderInTree(path),
            onLongPress: () => _showItemActions(
              path: path,
              isDir: true,
              isRemote: isRemote,
              isSaf: isSaf,
              label: name,
            ),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: isSelected
                  ? BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.folder_rounded, color: theme.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: theme.textPri,
                        fontSize: 13,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          onExpansionChanged: (expanded) {
            _selectFolderInTree(path);
          },
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getDirFuture(path, isRemote, isSaf),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: snapshot.data!
                      .map((i) => _buildExplorerNode(context, i))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
    }

    final isSelected = path == _selectedPath;
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 16, right: 16),
        leading: Icon(
          FileUtils.iconForFile(name),
          color: FileUtils.colorForFile(name, theme: theme),
          size: 18,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: theme.textPri,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
        onTap: () {
          setState(() {
            _selectedPath = path;
            _isSelectedPathDir = false;
          });
          widget.onFileTap(path);
        },
        onLongPress: () => _showItemActions(
          path: path,
          isDir: false,
          isRemote: isRemote,
          isSaf: isSaf,
          label: name,
        ),
      ),
    );
  }
}
