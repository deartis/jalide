import 'package:flutter/material.dart';

import '../services/project_stack_detector.dart';
import '../services/environment_orchestrator.dart';
import '../services/file_service.dart';
import '../theme/jalide_theme.dart';

class EnvironmentStatusBar extends StatelessWidget {
  final JalideProjectConfig projectConfig;
  final EnvironmentOrchestrator orchestrator;
  final String? projectPath;
  final VoidCallback? onConfigUpdated;
  final Future<void> Function(String content)? onSaveConfig;

  const EnvironmentStatusBar({
    super.key,
    required this.projectConfig,
    required this.orchestrator,
    this.projectPath,
    this.onConfigUpdated,
    this.onSaveConfig,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return StreamBuilder<Map<String, ServiceStatus>>(
      stream: orchestrator.statusStream,
      initialData: orchestrator.currentStatuses,
      builder: (context, snapshot) {
        final statuses = snapshot.data ?? {};

        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(
              bottom: BorderSide(color: theme.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Badge de Stack (Ícone + Nome)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStackIcon(projectConfig.stack), size: 13, color: theme.accent),
                    const SizedBox(width: 5),
                    Text(
                      projectConfig.displayName,
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Lista de Serviços com indicativo visual (🟢 / 🟡 / 🔴)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: projectConfig.services.map((serviceKey) {
                      final status = statuses[serviceKey.toLowerCase()];
                      final state = status?.state ?? ServiceState.running;

                      final color = switch (state) {
                        ServiceState.running => const Color(0xFF50FA7B),
                        ServiceState.starting => const Color(0xFFFFB86C),
                        ServiceState.stopped => theme.textMuted,
                        ServiceState.error => const Color(0xFFFF5555),
                      };

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                serviceKey.toUpperCase(),
                                style: TextStyle(
                                  color: theme.textPri,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Botão para criar jalide.json se não existir
              InkWell(
                onTap: () => _showGenerateConfigDialog(context, theme),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_suggest_rounded, size: 14, color: theme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'jalide.json',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getStackIcon(String stack) {
    return switch (stack) {
      'node' => Icons.javascript_rounded,
      'php' => Icons.php_rounded,
      'python' => Icons.code_rounded,
      'java' => Icons.coffee_rounded,
      'dotnet' => Icons.terminal_rounded,
      _ => Icons.folder_special_rounded,
    };
  }

  void _showGenerateConfigDialog(BuildContext context, JalideThemeVariant theme) {
    final jsonContent = projectConfig.toFormattedJson();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Row(
          children: [
            Icon(Icons.terminal_rounded, color: theme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Configuração jalide.json',
              style: TextStyle(color: theme.textPri, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Abaixo está a configuração gerada para este ambiente:',
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
              child: SelectableText(
                jsonContent,
                style: const TextStyle(
                  color: Color(0xFF7DCFFF),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fechar', style: TextStyle(color: theme.textMuted)),
          ),
          if (projectPath != null)
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  if (onSaveConfig != null) {
                    await onSaveConfig!(jsonContent);
                  } else {
                    final targetPath = '$projectPath/jalide.json';
                    await FileService.saveFile(targetPath, jsonContent);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('jalide.json criado com sucesso na raiz!')),
                    );
                    onConfigUpdated?.call();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao salvar jalide.json: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Salvar na Raiz'),
            ),
        ],
      ),
    );
  }
}
