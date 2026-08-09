import 'package:flutter/material.dart';

import '../services/project_stack_detector.dart';
import '../services/environment_orchestrator.dart';
import '../theme/jalide_theme.dart';

class EnvironmentStatusBar extends StatelessWidget {
  final JalideProjectConfig projectConfig;
  final EnvironmentOrchestrator orchestrator;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  const EnvironmentStatusBar({
    super.key,
    required this.projectConfig,
    required this.orchestrator,
    this.onUndo,
    this.onRedo,
    this.canUndo = true,
    this.canRedo = true,
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

              // Botões de Desfazer e Refazer (Undo / Redo)
              if (onUndo != null || onRedo != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Desfazer (Ctrl+Z)',
                  child: InkWell(
                    onTap: canUndo ? onUndo : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Icon(
                        Icons.undo_rounded,
                        size: 16,
                        color: canUndo
                            ? theme.accent
                            : theme.textMuted.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Refazer (Ctrl+Y)',
                  child: InkWell(
                    onTap: canRedo ? onRedo : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Icon(
                        Icons.redo_rounded,
                        size: 16,
                        color: canRedo
                            ? theme.accent
                            : theme.textMuted.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ],
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
}
