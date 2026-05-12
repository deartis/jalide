import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';
import '../utils/file_utils.dart';

class FileExplorerDrawer extends StatelessWidget {
  final String? projectPath;
  final List<Map<String, dynamic>> projectFiles;
  final Function(String) onFileTap;
  final VoidCallback onPickFolder;
  final VoidCallback onOpenTermux;
  final VoidCallback onCreateFile;
  final VoidCallback onCreateFolder;
  final MethodChannel termuxChannel;
  final SshSession? sshSession;
  final bool isRemoteProject;

  const FileExplorerDrawer({
    super.key,
    required this.projectPath,
    required this.projectFiles,
    required this.onFileTap,
    required this.onPickFolder,
    required this.onOpenTermux,
    required this.onCreateFile,
    required this.onCreateFolder,
    required this.termuxChannel,
    this.sshSession,
    this.isRemoteProject = false,
  });

  @override
  Widget build(BuildContext context) {
    final _theme = ThemeProvider.of(context).current;
    return Drawer(
      backgroundColor: _theme.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 8, 20),
            color: _theme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  color: _theme.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    projectPath == null
                        ? 'EXPLORER'
                        : isRemoteProject
                            ? 'REMOTE: ${p.basename(projectPath!)}'
                            : FileUtils.getDisplayName(
                                projectPath!,
                                uppercase: true,
                              ),
                    style: TextStyle(
                      color: isRemoteProject ? _theme.accent : _theme.textPri,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (projectPath != null) ...[
                  IconButton(
                    onPressed: onCreateFile,
                    icon: Icon(
                      Icons.note_add_outlined,
                      color: _theme.textMuted,
                      size: 20,
                    ),
                    tooltip: 'Novo Arquivo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCreateFolder,
                    icon: Icon(
                      Icons.create_new_folder_outlined,
                      color: _theme.textMuted,
                      size: 20,
                    ),
                    tooltip: 'Nova Pasta',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  onPressed: onPickFolder,
                  icon: Icon(
                    Icons.folder_open_outlined,
                    color: _theme.textMuted,
                    size: 20,
                  ),
                  tooltip: 'Selecionar pasta projeto',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Expanded(
            child: projectPath == null
                ? _buildEmptyState(_theme)
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: projectFiles
                        .map((item) => _buildExplorerNode(context, item))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(JalideThemeVariant _theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 48,
            color: _theme.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum projeto aberto',
            style: TextStyle(color: _theme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onPickFolder,
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.accent,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('ABRIR PASTA'),
          ),
          const SizedBox(height: 10),
          if (Platform.isAndroid)
            ElevatedButton.icon(
              onPressed: onOpenTermux,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3A1B),
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50), width: 1),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.terminal, size: 16),
              label: const Text('ABRIR DO TERMUX'),
            ),
          if (sshSession != null && sshSession!.isConnected) ...[
            const SizedBox(height: 20),
            const Divider(indent: 40, endIndent: 40),
            const SizedBox(height: 10),
            Text(
              'SSH ATIVO: ${sshSession!.profile.label}',
              style: TextStyle(color: _theme.accent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplorerNode(BuildContext context, Map<String, dynamic> item) {
    final _theme = ThemeProvider.of(context).current;
    final name = item['name'] as String;
    final path = item['path'] as String;
    final isDir = item['isDir'] as bool;
    final isSaf = item['isSaf'] as bool;
    final isRemote = item['isRemote'] as bool? ?? false;

    if (isDir) {
      if (name.startsWith('.')) return const SizedBox();

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(path),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(Icons.folder_rounded, color: _theme.accent, size: 18),
          title: Text(
            name,
            style: TextStyle(
              color: _theme.textPri,
              fontSize: 13,
              fontFamily: 'sans-serif',
            ),
          ),
          iconColor: _theme.accent,
          collapsedIconColor: _theme.textMuted,
          childrenPadding: const EdgeInsets.only(left: 12),
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: isRemote
                  ? sshSession?.listDir(path).then(
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
                      )
                  : isSaf
                      ? termuxChannel
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
                            )
                      : Directory(path).list().toList().then((list) {
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
                        }),
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
                          color: _theme.accent,
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

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 16, right: 16),
      leading: Icon(
        FileUtils.iconForFile(name),
        color: FileUtils.colorForFile(name, theme: _theme),
        size: 18,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: _theme.textPri,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
      onTap: () => onFileTap(path),
    );
  }
}
