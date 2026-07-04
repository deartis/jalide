import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';
import '../services/file_service.dart';
import '../utils/file_utils.dart';

// ─── Enum de Modo do Terminal ────────────────────────────────────────────────

enum TerminalMode { local, ssh }

// ─── Widget Principal ────────────────────────────────────────────────────────

class TerminalPanel extends StatefulWidget {
  final VoidCallback onClose;
  final TerminalMode mode;

  /// Sessão SSH ativa — obrigatório quando mode == TerminalMode.ssh
  final SshSession? sshSession;
  final void Function(TerminalPanelState?)? onTerminalStateChanged;

  const TerminalPanel({
    super.key,
    required this.onClose,
    this.mode = TerminalMode.local,
    this.sshSession,
    this.projectPath,
    this.onTerminalStateChanged,
  });

  final String? projectPath;

  @override
  State<TerminalPanel> createState() => TerminalPanelState();
}

class TerminalPanelState extends State<TerminalPanel> {
  late final Terminal _terminal;
  late final TerminalController _controller;

  // Local PTY
  Pty? _localPty;
  StreamSubscription<Uint8List>? _ptySubscription;

  bool _ready = false;
  String? _errorMessage;

  void sendInput(String data) {
    if (!_ready) return;
    try {
      if (widget.mode == TerminalMode.local) {
        _localPty?.write(utf8.encode(data));
      } else {
        widget.sshSession?.writeToShell(data);
      }
    } catch (e) {
      debugPrint('JALIDE_TERMINAL_SEND_INPUT_ERROR: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    widget.onTerminalStateChanged?.call(this);
    _terminal = Terminal(maxLines: 10000);
    _controller = TerminalController();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant TerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.sshSession != oldWidget.sshSession || widget.mode != oldWidget.mode) {
      // Re-inicializa o terminal se a sessão ou o modo mudar (ex: reconexão)
      _ready = false;
      _errorMessage = null;
      _ptySubscription?.cancel();
      _ptySubscription = null;
      _localPty?.kill();
      _localPty = null;
      _initialize();
    } else if (widget.projectPath != oldWidget.projectPath && _ready) {
      final updatedPath = widget.projectPath;
      if (updatedPath != null) {
        if (widget.mode == TerminalMode.local) {
          var workingDir = updatedPath;
          if (workingDir.startsWith('content://')) {
            workingDir = FileUtils.resolveSafPath(workingDir);
          }
          _localPty?.write(
            utf8.encode('cd "${workingDir.replaceAll('"', '\\"')}"\n'),
          );
        } else if (widget.mode == TerminalMode.ssh) {
          widget.sshSession?.writeToShell(
            'cd "${updatedPath.replaceAll('"', '\\"')}"\n',
          );
        }
      }
    }
  }

  Future<void> _initialize() async {
    try {
      if (widget.mode == TerminalMode.local) {
        await _initLocalShell();
      } else {
        await _initSshShell();
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  // ─── Shell Local via flutter_pty ──────────────────────────────────────────

  Future<void> _initLocalShell() async {
    const termuxBash = '/data/data/com.termux/files/usr/bin/bash';
    const androidSh = '/system/bin/sh';

    String shell = androidSh;
    if (File(termuxBash).existsSync()) {
      shell = termuxBash;
    }

    String workingDir = widget.projectPath ?? '';
    if (workingDir.startsWith('content://')) {
      workingDir = FileUtils.resolveSafPath(workingDir);
    }
    if (workingDir.isEmpty || !Directory(workingDir).existsSync()) {
      final docDir = await getApplicationDocumentsDirectory();
      workingDir = docDir.path;
    }

    _localPty = Pty.start(
      shell,
      columns: _terminal.viewWidth,
      rows: _terminal.viewHeight,
      workingDirectory: workingDir,
    );

    // PTY → terminal: decode bytes → String
    _ptySubscription = _localPty!.output.listen((data) {
      _terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // Terminal → PTY: String → encode bytes
    _terminal.onOutput = (data) {
      _localPty!.write(utf8.encode(data));
    };

    // Sincroniza tamanho quando o terminal redimensiona
    _terminal.onResize = (w, h, pw, ph) {
      _localPty!.resize(h, w);
    };
  }

  // ─── Shell SSH via dartssh2 ───────────────────────────────────────────────

  Future<void> _initSshShell() async {
    final session = widget.sshSession;
    if (session == null || !session.isConnected) {
      throw Exception(
        session?.errorMessage ?? 'Sessão SSH não está conectada. Verifique as credenciais e tente novamente.',
      );
    }

    // Abre o shell remoto com o tamanho inicial do terminal
    await session.openShell(
      width: _terminal.viewWidth,
      height: _terminal.viewHeight,
    );

    // SSH output → terminal: decode bytes → String
    _ptySubscription = session.outputStream!.listen(
      (data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      },
      onError: (e) => debugPrint('SSH terminal stream error: $e'),
      onDone: () => debugPrint('SSH terminal stream closed'),
      cancelOnError: false,
    );

    // Terminal → SSH input: String enviado diretamente
    _terminal.onOutput = (data) => session.writeToShell(data);

    // Atualiza tamanho do PTY remoto quando a UI redimensiona
    _terminal.onResize = (w, h, _, _) => session.resizePty(w, h);

    // Executa cd automático para o diretório do projeto no SSH remoto
    if (widget.projectPath != null && widget.projectPath!.isNotEmpty) {
      String remotePath = widget.projectPath!;
      if (remotePath.startsWith('content://')) {
        remotePath = FileUtils.resolveSafPath(remotePath);
      }
      Future.delayed(const Duration(milliseconds: 600), () {
        session.writeToShell('cd "$remotePath"\n');
      });
    }
  }

  Widget _buildStepRow(String step, String text, JalideThemeVariant theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: TextStyle(
                color: theme.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: theme.textPri, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateTermuxMagic() async {
    // O Super Script: Atualiza, instala pacotes, libera storage,
    // permite external apps, inicia o SSH, pede a senha e mostra o usuário.
    const setupScript =
        "pkg update -y && pkg install -y openssh nodejs git && termux-setup-storage && echo 'allow-external-apps = true' >> ~/.termux/termux.properties && sshd && echo '\\n\\e[1;32m[JALIDE] Digite uma senha para o SSH:\\e[0m' && passwd && echo '\\n\\e[1;34m[JALIDE] Seu usuario SSH e:\\e[0m' && whoami";

    try {
      final channel = FileService.channel;
      await channel.invokeMethod('runTermuxCommand', {'script': setupScript});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚡ Comando enviado! Verifique o Termux.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1F8B4C),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          duration: const Duration(days: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final theme = ThemeProvider.of(context).current;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Setup Mágico',
                style: TextStyle(
                  color: theme.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siga os passos abaixo para preparar o Termux e liberar o poder do JALIDE:',
                style: TextStyle(color: theme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildStepRow('1', 'Copie o código abaixo.', theme),
              _buildStepRow('2', 'Abra o app Termux e cole o código.', theme),
              _buildStepRow(
                '3',
                'Quando solicitado, digite uma nova senha.',
                theme,
              ),
              _buildStepRow(
                '4',
                'Anote o usuário que aparecerá no final.',
                theme,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Text(
                  setupScript,
                  style: const TextStyle(
                    color: Colors.amber,
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
              child: Text('FECHAR', style: TextStyle(color: theme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: setupScript));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_copy, color: theme.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Copiado! Cole no Termux.',
                              style: TextStyle(color: theme.textPri),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: theme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: IconButton(
                              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                              icon: Icon(Icons.close, color: theme.accent, size: 18),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              tooltip: 'Fechar',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: theme.surface,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: theme.accent, width: 1),
                      ),
                      duration: const Duration(days: 1),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'COPIAR CÓDIGO',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.onTerminalStateChanged?.call(null);
    _ptySubscription?.cancel();
    _ptySubscription = null;
    _localPty?.kill();
    _controller.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final isSSH = widget.mode == TerminalMode.ssh;

    final accentColor = isSSH ? const Color(0xFF7AA2F7) : theme.accent;

    return Container(
      height: keyboardVisible ? 260 : 200,
      margin: keyboardVisible ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xEE0D0D0F),
        borderRadius: keyboardVisible
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        border: Border(
          top: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 1),
          left: keyboardVisible
              ? BorderSide(color: accentColor.withValues(alpha: 0.3))
              : BorderSide.none,
          right: keyboardVisible
              ? BorderSide(color: accentColor.withValues(alpha: 0.3))
              : BorderSide.none,
          bottom: keyboardVisible
              ? BorderSide(color: accentColor.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        boxShadow: [
          if (keyboardVisible)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: keyboardVisible
            ? BorderRadius.circular(12)
            : BorderRadius.zero,
        child: Column(
          children: [
            _buildHeader(theme, accentColor, isSSH),
            Expanded(child: _buildBody(theme, accentColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(JalideThemeVariant theme, Color accentColor, bool isSSH) {
    final label = isSSH
        ? '${widget.sshSession?.profile.label ?? 'SSH'} — ${widget.sshSession?.profile.host ?? ''}'
        : 'TERMINAL LOCAL (${widget.projectPath != null ? "Projeto" : "Interno"})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: accentColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          // Indicador de status
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _ready ? const Color(0xFF9ECE6A) : Colors.orange,
              shape: BoxShape.circle,
              boxShadow: _ready
                  ? [
                      BoxShadow(
                        color: const Color(0xFF9ECE6A).withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isSSH ? Icons.cloud_outlined : Icons.terminal_outlined,
            size: 13,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Limpar terminal
          GestureDetector(
            onTap: () => _terminal.buffer.clear(),
            child: Icon(
              Icons.cleaning_services_outlined,
              size: 13,
              color: theme.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          if (!isSSH)
            GestureDetector(
              onTap: _activateTermuxMagic,
              child: const Icon(Icons.bolt, size: 14, color: Colors.amber),
            ),
          if (!isSSH) const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(Icons.close, size: 14, color: theme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(JalideThemeVariant theme, Color accentColor) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.mode == TerminalMode.ssh
                  ? 'Conectando ao SSH...'
                  : 'Iniciando shell...',
              style: TextStyle(
                color: theme.textMuted,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return TerminalView(
      _terminal,
      controller: _controller,
      theme: TerminalTheme(
        cursor: accentColor,
        selection: accentColor.withValues(alpha: 0.4),
        foreground: const Color(0xFFCDD6F4),
        background: Colors.transparent,
        black: const Color(0xFF414868),
        white: const Color(0xFFC0CAF5),
        brightBlack: const Color(0xFF414868),
        brightWhite: const Color(0xFFC0CAF5),
        red: const Color(0xFFF7768E),
        brightRed: const Color(0xFFF7768E),
        green: const Color(0xFF9ECE6A),
        brightGreen: const Color(0xFF9ECE6A),
        yellow: const Color(0xFFE0AF68),
        brightYellow: const Color(0xFFE0AF68),
        blue: const Color(0xFF7AA2F7),
        brightBlue: const Color(0xFF7AA2F7),
        magenta: const Color(0xFFBB9AF7),
        brightMagenta: const Color(0xFFBB9AF7),
        cyan: const Color(0xFF7DCFFF),
        brightCyan: const Color(0xFF7DCFFF),
        searchHitBackground: accentColor.withValues(alpha: 0.3),
        searchHitBackgroundCurrent: accentColor.withValues(alpha: 0.5),
        searchHitForeground: const Color(0xFF0D0D0F),
      ),
      padding: const EdgeInsets.all(8),
    );
  }

}
