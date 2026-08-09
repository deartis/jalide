import 'package:flutter/material.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';

class StatusBar extends StatelessWidget {
  final String languageName;
  final bool hasUnsavedChanges;
  final bool isTerminalVisible;
  final VoidCallback onTerminalToggle;
  final VoidCallback? onLanguageTap;
  final bool isAuxKeyboardVisible;
  final VoidCallback onAuxKeyboardToggle;
  final bool isRemoteProject;

  // Indicador SSH opcional — passa null quando não há sessão SSH
  final SshConnectionManager? sshConnectionManager;
  final VoidCallback? onSshTap;

  final List<Widget> extraItems;

  const StatusBar({
    super.key,
    required this.languageName,
    required this.hasUnsavedChanges,
    required this.onTerminalToggle,
    required this.isAuxKeyboardVisible,
    required this.onAuxKeyboardToggle,
    this.isTerminalVisible = false,
    this.isRemoteProject = false,
    this.onLanguageTap,
    this.sshConnectionManager,
    this.onSshTap,
    this.extraItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    return Container(
      width: double.infinity,
      height: 36,
      color: theme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Indicador de Conexão: Local ou SSH
            if (isRemoteProject && sshConnectionManager != null)
              _SshStatusChip(
                manager: sshConnectionManager!,
                theme: theme,
                onTap: onSshTap,
              )
            else
              _LocalStatusChip(theme: theme),

            const SizedBox(width: 6),

            // Botão Terminal
            _sbChip(
              theme,
              text: 'Terminal',
              icon: Icons.terminal_rounded,
              isActive: isTerminalVisible,
              onTap: onTerminalToggle,
            ),

            const SizedBox(width: 6),

            // Botão Teclado Auxiliar
            _sbChip(
              theme,
              text: 'Teclado',
              icon: Icons.keyboard_rounded,
              isActive: isAuxKeyboardVisible,
              onTap: onAuxKeyboardToggle,
            ),

            const SizedBox(width: 6),

            // Linguagem Ativa
            _sbChip(
              theme,
              text: languageName,
              icon: Icons.code_rounded,
              isActive: true,
              onTap: onLanguageTap,
            ),

            // Módulos extras (Ex: contador de palavras/linhas)
            ...extraItems.map(
              (w) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Center(child: w),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sbChip(
    JalideThemeVariant theme, {
    required String text,
    IconData? icon,
    bool isActive = true,
    VoidCallback? onTap,
  }) {
    final fgColor = isActive ? theme.bg : theme.bg.withValues(alpha: 0.55);
    final bgColor = isActive
        ? theme.bg.withValues(alpha: 0.18)
        : Colors.transparent;

    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fgColor),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  color: fgColor,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Indicador Local para a status bar ───────────────────────────────────────

class _LocalStatusChip extends StatelessWidget {
  final JalideThemeVariant theme;

  const _LocalStatusChip({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.bg.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, color: Color(0xFF4CAF50), size: 7),
            const SizedBox(width: 5),
            Text(
              'Local',
              style: TextStyle(
                color: theme.bg,
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Indicador SSH compacto para a status bar ───────────────────────────────

class _SshStatusChip extends StatelessWidget {
  final SshConnectionManager manager;
  final JalideThemeVariant theme;
  final VoidCallback? onTap;

  const _SshStatusChip({
    required this.manager,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SshConnectionState>(
      stream: manager.connectionStateStream,
      initialData:
          manager.currentSession?.state ?? SshConnectionState.disconnected,
      builder: (context, snapshot) {
        final state = snapshot.data ?? SshConnectionState.disconnected;
        final label = manager.currentSession?.profile.label ?? 'SSH';

        final (color, icon) = switch (state) {
          SshConnectionState.connected => (
            const Color(0xFF4CAF50),
            Icons.circle,
          ),
          SshConnectionState.connecting => (
            const Color(0xFFFFC107),
            Icons.circle,
          ),
          SshConnectionState.error => (const Color(0xFFFF5722), Icons.circle),
          SshConnectionState.disconnected => (
            const Color(0xFF9E9E9E),
            Icons.circle_outlined,
          ),
        };

        return Center(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.bg.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state == SshConnectionState.connecting)
                    _PulsingDot(color: color)
                  else
                    Icon(icon, color: color, size: 7),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.bg,
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Bolinha animada que pulsa durante reconexão
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(Icons.circle, color: widget.color, size: 7),
    );
  }
}
