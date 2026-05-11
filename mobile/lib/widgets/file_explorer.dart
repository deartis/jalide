import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
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
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: JalideTheme.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 8, 20),
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
                    projectPath == null ? 'EXPLORER' : FileUtils.getDisplayName(projectPath!, uppercase: true),
                    style: const TextStyle(
                      color: JalideTheme.textPri,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (projectPath != null) ...[
                  IconButton(
                    onPressed: onCreateFile,
                    icon: const Icon(
                      Icons.note_add_outlined,
                      color: JalideTheme.textMuted,
                      size: 20,
                    ),
                    tooltip: 'Novo Arquivo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCreateFolder,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      color: JalideTheme.textMuted,
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
                  icon: const Icon(
                    Icons.folder_open_outlined,
                    color: JalideTheme.textMuted,
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
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: projectFiles.map((item) => _buildExplorerNode(context, item)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onPickFolder,
            style: ElevatedButton.styleFrom(
              backgroundColor: JalideTheme.accent,
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
        ],
      ),
    );
  }

  Widget _buildExplorerNode(BuildContext context, Map<String, dynamic> item) {
    final name = item['name'] as String;
    final path = item['path'] as String;
    final isDir = item['isDir'] as bool;
    final isSaf = item['isSaf'] as bool;

    if (isDir) {
      if (name.startsWith('.')) return const SizedBox();

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(path),
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
            FutureBuilder<List<Map<String, dynamic>>>(
              future: isSaf 
                ? termuxChannel.invokeMethod('listSafDirectory', {'uri': path}).then((res) => 
                    (res as List).map((f) => {
                      'name': f['name'] as String,
                      'path': f['uri'] as String,
                      'isDir': f['isDir'] as bool,
                      'isSaf': true,
                    }).toList()
                  )
                : Directory(path).list().toList().then((list) {
                    list.sort((a, b) {
                      if (a is Directory && b is! Directory) return -1;
                      if (a is! Directory && b is Directory) return 1;
                      return a.path.compareTo(b.path);
                    });
                    return list.map((e) => {
                      'name': p.basename(e.path),
                      'path': e.path,
                      'isDir': e is Directory,
                      'isSaf': false,
                    }).toList();
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
                  children: snapshot.data!.map((i) => _buildExplorerNode(context, i)).toList(),
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
      leading: Icon(FileUtils.iconForFile(name), color: FileUtils.colorForFile(name), size: 18),
      title: Text(
        name,
        style: const TextStyle(
          color: JalideTheme.textPri,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
      onTap: () => onFileTap(path),
    );
  }
}
