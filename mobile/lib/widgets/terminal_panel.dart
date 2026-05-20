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
    if (widget.projectPath != oldWidget.projectPath && _ready) {
      final updatedPath = widget.projectPath;
      if (updatedPath != null) {
        if (widget.mode == TerminalMode.local) {
          var workingDir = updatedPath;
          if (workingDir.startsWith('content://')) {
            workingDir = _resolveSafPath(workingDir);
          }
          _localPty?.write(utf8.encode('cd "${workingDir.replaceAll('"', '\\"')}"\n'));
        } else if (widget.mode == TerminalMode.ssh) {
          widget.sshSession?.writeToShell('cd "${updatedPath.replaceAll('"', '\\"')}"\n');
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
      workingDir = _resolveSafPath(workingDir);
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
      throw Exception('Sessão SSH não está conectada.');
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
        remotePath = _resolveSafPath(remotePath);
      }
      Future.delayed(const Duration(milliseconds: 600), () {
        session.writeToShell('cd "$remotePath"\n');
      });
    }
  }

  Future<void> _activateTermuxMagic() async {
    const setupScript = "pkg install -y openssh nodejs && sshd";
    
    try {
      final channel = MethodChannel('com.jalide/termux');
      await channel.invokeMethod('runTermuxCommand', {
        'script': setupScript,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Comando enviado! Verifique o Termux.'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Ativar Node.js (Modo Manual)', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'O Android bloqueou o comando automático. Cole o comando abaixo no Termux para ativar o Node.js:',
                style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 13),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  setupScript,
                  style: TextStyle(color: Colors.amber, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: Color(0xFFCDD6F4))),
            ),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: setupScript));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copiado! Cole no Termux.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('COPIAR E ABRIR TERMUX', style: TextStyle(color: Colors.black)),
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
                  ? [BoxShadow(color: const Color(0xFF9ECE6A).withValues(alpha: 0.5), blurRadius: 4)]
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
              child: Icon(Icons.cleaning_services_outlined, size: 13, color: theme.textMuted),
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
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
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

  String _resolveSafPath(String safUri) {
    if (!safUri.startsWith('content://')) return safUri;
    try {
      final uri = Uri.parse(safUri);
      final decodedPath = Uri.decodeComponent(uri.path);
      
      // Encontra a parte depois de tree/ ou document/
      String? treeOrDocPart;
      final treeIndex = decodedPath.indexOf('tree/');
      if (treeIndex != -1) {
        treeOrDocPart = decodedPath.substring(treeIndex + 5);
      } else {
        final docIndex = decodedPath.indexOf('document/');
        if (docIndex != -1) {
          treeOrDocPart = decodedPath.substring(docIndex + 9);
        }
      }
      
      if (treeOrDocPart != null) {
        if (treeOrDocPart.startsWith('primary:')) {
          final relativePath = treeOrDocPart.substring(8);
          return '/storage/emulated/0/$relativePath';
        } else if (treeOrDocPart.startsWith('home:')) {
          final relativePath = treeOrDocPart.substring(5);
          return '/data/data/com.termux/files/home/$relativePath';
        } else if (treeOrDocPart.startsWith('usr:')) {
          final relativePath = treeOrDocPart.substring(4);
          return '/data/data/com.termux/files/usr/$relativePath';
        } else if (treeOrDocPart.startsWith('raw:')) {
          return treeOrDocPart.substring(4);
        } else if (treeOrDocPart.startsWith('/')) {
          return treeOrDocPart;
        }
      }
    } catch (e) {
      debugPrint('Error resolving SAF path: $e');
    }
    return safUri;
  }
}
