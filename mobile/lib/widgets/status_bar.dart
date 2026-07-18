import 'package:flutter/material.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';

class StatusBar extends StatelessWidget {
  final String languageName;
  final bool hasUnsavedChanges;
  final VoidCallback onTerminalToggle;
  final VoidCallback? onLanguageTap;

  // Indicador SSH opcional — passa null quando não há sessão SSH
  final SshConnectionManager? sshConnectionManager;
  final VoidCallback? onSshTap;

  const StatusBar({
    super.key,
    required this.languageName,
    required this.hasUnsavedChanges,
    required this.onTerminalToggle,
    this.onLanguageTap,
    this.sshConnectionManager,
    this.onSshTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    return Container(
      color: theme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: GestureDetector(
              onTap: onTerminalToggle,
              behavior: HitTestBehavior.opaque,
              child: _sbChip(theme, '⬡ Terminal'),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: GestureDetector(
              onTap: onLanguageTap,
              behavior: HitTestBehavior.opaque,
              child: _sbChip(theme, languageName),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: _sbChip(theme, 'UTF-8'),
          ),
          const Spacer(),
          // Indicador SSH discreto — só aparece quando há sessão ativa
          if (sshConnectionManager != null)
            _SshStatusChip(
              manager: sshConnectionManager!,
              theme: theme,
              onTap: onSshTap,
            ),
        ],
      ),
    );
  }

  Widget _sbChip(JalideThemeVariant theme, String text) => Text(
    text,
    style: TextStyle(
      color: theme.bg,
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );
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
      initialData: manager.currentSession?.state ?? SshConnectionState.disconnected,
      builder: (context, snapshot) {
        final state = snapshot.data ?? SshConnectionState.disconnected;
        final label = manager.currentSession?.profile.label ?? 'SSH';

        final (color, icon) = switch (state) {
          SshConnectionState.connected    => (const Color(0xFF4CAF50), Icons.circle),
          SshConnectionState.connecting   => (const Color(0xFFFFC107), Icons.circle),
          SshConnectionState.error        => (const Color(0xFFFF5722), Icons.circle),
          SshConnectionState.disconnected => (const Color(0xFF9E9E9E), Icons.circle_outlined),
        };

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bolinha de status pulsante quando conectando
              if (state == SshConnectionState.connecting)
                _PulsingDot(color: color)
              else
                Icon(icon, color: color, size: 7),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: theme.bg.withValues(alpha: 0.85),
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
