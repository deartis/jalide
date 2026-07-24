import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ssh_connection_manager.dart';
import '../services/ssh_host_key_service.dart';
import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';

/// Tela de gerenciamento e conexão SSH.
/// Exibe perfis salvos e permite criar, editar e conectar.
class SshConnectScreen extends StatefulWidget {
  final SshProfileManager profileManager;
  final SshConnectionManager connectionManager;
  final Future<void> Function(SshSession session) onConnected;
  final SshSession? currentSession;
  final Future<void> Function()? onDisconnect;

  const SshConnectScreen({
    super.key,
    required this.profileManager,
    required this.connectionManager,
    required this.onConnected,
    this.currentSession,
    this.onDisconnect,
  });

  @override
  State<SshConnectScreen> createState() => _SshConnectScreenState();
}

class _SshConnectScreenState extends State<SshConnectScreen> {
  String? _connectingId;
  String? _testingId;

  JalideThemeVariant get _theme => ThemeProvider.of(context).current;

  Future<void> _connect(SshProfile profile) async {
    setState(() {
      _connectingId = profile.id;
    });

    try {
      final success = await widget.connectionManager.connect(
        profile,
        onHostKeyVerify: (type, fingerprint) => _verifyHostKey(profile, type, fingerprint),
      );
      if (!success) throw Exception('Falha ao conectar');
      final session = widget.connectionManager.currentSession;
      if (session == null) throw Exception('Sessão não disponível');
      if (!mounted) return;
      await widget.onConnected(session);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingId = null;
      });
      _showError('Falha na conexão: $e');
    }
  }

  /// Verifica host key: mostra dialog para o usuário confirmar host novo ou alerta MITM.
  Future<bool> _verifyHostKey(SshProfile profile, String type, List<int> fingerprint) async {
    final status = await SshHostKeyService.verify(
      host: profile.host,
      port: profile.port,
      type: type,
      fingerprint: fingerprint,
    );

    if (status == HostKeyStatus.trusted) return true;

    if (!mounted) return false;

    // Mostra dialog para confirmação
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              status == HostKeyStatus.changed ? Icons.warning_amber_rounded : Icons.help_outline,
              color: status == HostKeyStatus.changed ? const Color(0xFFF7768E) : const Color(0xFFF6C177),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              status == HostKeyStatus.changed ? 'Host Key Alterado!' : 'Novo Servidor',
              style: TextStyle(color: _theme.textPri, fontSize: 15),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status == HostKeyStatus.changed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'A chave deste servidor mudou desde a última conexão. '
                  'Isso pode indicar um ataque Man-in-the-Middle.',
                  style: TextStyle(color: const Color(0xFFF7768E), fontSize: 12),
                ),
              ),
            Text(
              '${profile.host}:${profile.port}',
              style: TextStyle(color: _theme.textPri, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tipo: $type',
              style: TextStyle(color: _theme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              'Fingerprint:',
              style: TextStyle(color: _theme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                SshHostKeyService.formatFingerprint(fingerprint),
                style: const TextStyle(color: Color(0xFF7AA2F7), fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Rejeitar', style: TextStyle(color: _theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == HostKeyStatus.changed
                  ? const Color(0xFFF7768E)
                  : const Color(0xFF7AA2F7),
            ),
            child: Text(
              status == HostKeyStatus.changed ? 'Conectar Mesmo Assim' : 'Conectar',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await SshHostKeyService.trust(
        host: profile.host,
        port: profile.port,
        type: type,
        fingerprint: fingerprint,
      );
      return true;
    }

    return false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Fechar',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF7768E).withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        duration: const Duration(days: 1),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Fechar',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1F8B4C).withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _testConnection(SshProfile profile) async {
    setState(() => _testingId = profile.id);

    try {
      final success = await widget.connectionManager.connect(
        profile,
        onHostKeyVerify: (type, fingerprint) => _verifyHostKey(profile, type, fingerprint),
      );
      if (!success) throw Exception('Falha ao conectar');
      await widget.connectionManager.disconnect();
      if (!mounted) return;
      setState(() => _testingId = null);
      _showSuccess('Conexão OK com ${profile.label}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testingId = null);
      _showError('Falha ao testar conexão: $e');
    }
  }

  Future<void> _showAddProfileDialog({SshProfile? existing}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final hostCtrl = TextEditingController(text: existing?.host ?? '');
    final portCtrl = TextEditingController(text: (existing?.port ?? 22).toString());
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final passCtrl = TextEditingController(text: existing?.password ?? '');
    final keyCtrl = TextEditingController(text: existing?.privateKeyPem ?? '');
    bool useKey = existing?.privateKeyPem != null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7AA2F7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_outlined, color: Color(0xFF7AA2F7), size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                existing == null ? 'Nova Conexão SSH' : 'Editar Conexão',
                style: TextStyle(color: _theme.textPri, fontSize: 15),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(ctx, labelCtrl, 'Label / Apelido', hint: 'ex: Servidor VPS'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 3, child: _field(ctx, hostCtrl, 'Host / IP', hint: '192.168.1.10')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(ctx, portCtrl, 'Porta', hint: '22', numeric: true)),
                ]),
                const SizedBox(height: 10),
                _field(ctx, userCtrl, 'Usuário', hint: 'root'),
                const SizedBox(height: 10),
                // Toggle senha / chave
                Row(
                  children: [
                    Text('Autenticação:', style: TextStyle(color: _theme.textMuted, fontSize: 12)),
                    const SizedBox(width: 10),
                    _chip('Senha', !useKey, () => setLocal(() => useKey = false)),
                    const SizedBox(width: 6),
                    _chip('Chave RSA', useKey, () => setLocal(() => useKey = true)),
                  ],
                ),
                const SizedBox(height: 10),
                if (!useKey)
                  _field(ctx, passCtrl, 'Senha', obscure: true)
                else
                  _field(ctx, keyCtrl, 'Chave PEM (conteúdo)', hint: '-----BEGIN...', maxLines: 4),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: _theme.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                final profile = SshProfile(
                  id: id,
                  label: labelCtrl.text.trim().isEmpty ? hostCtrl.text.trim() : labelCtrl.text.trim(),
                  host: hostCtrl.text.trim(),
                  port: int.tryParse(portCtrl.text) ?? 22,
                  username: userCtrl.text.trim(),
                  password: useKey ? null : passCtrl.text,
                  privateKeyPem: useKey ? keyCtrl.text.trim() : null,
                );
                await widget.profileManager.save(profile);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Salvar', style: TextStyle(color: Color(0xFF7AA2F7), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext ctx,
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool obscure = false,
    bool numeric = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: TextStyle(color: _theme.textPri, fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: _theme.textMuted, fontSize: 12),
        hintStyle: TextStyle(color: _theme.textMuted.withValues(alpha: 0.5), fontSize: 12),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _theme.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7AA2F7))),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7AA2F7).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF7AA2F7)
                : _theme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF7AA2F7) : _theme.textMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profileManager.profiles;

    return Scaffold(
      backgroundColor: _theme.bg,
      appBar: AppBar(
        backgroundColor: _theme.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF7AA2F7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_outlined, color: Color(0xFF7AA2F7), size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              'SSH Remote',
              style: TextStyle(
                color: _theme.textPri,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _theme.border),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddProfileDialog(),
            icon: const Icon(Icons.add, color: Color(0xFF7AA2F7)),
            tooltip: 'Nova conexão',
          ),
        ],
      ),
      body: profiles.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildProfileCard(profiles[i]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF7AA2F7).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_outlined, color: Color(0xFF7AA2F7), size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma conexão SSH',
            style: TextStyle(
              color: _theme.textPri,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione um servidor para acessar\narquivos e terminal remotamente.',
            style: TextStyle(color: _theme.textMuted, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _showAddProfileDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Adicionar Servidor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7AA2F7),
              foregroundColor: const Color(0xFF0D0D0F),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(SshProfile profile) {
    final isConnecting = _connectingId == profile.id;
    final isTesting = _testingId == profile.id;
    final isOnline = widget.currentSession?.profile.id == profile.id &&
        widget.currentSession!.isConnected;

    return Container(
      decoration: BoxDecoration(
        color: _theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline
              ? const Color(0xFF1F8B4C)
              : isConnecting
                  ? const Color(0xFF7AA2F7)
                  : _theme.border,
          width: isOnline || isConnecting ? 1.5 : 1,
        ),
        boxShadow: isOnline || isConnecting
            ? [
                BoxShadow(
                  color: (isOnline ? const Color(0xFF1F8B4C) : const Color(0xFF7AA2F7))
                      .withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isConnecting || isOnline ? null : () => _connect(profile),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Ícone
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7AA2F7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isConnecting
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7AA2F7),
                          ),
                        )
                      : const Icon(Icons.dns_outlined, color: Color(0xFF7AA2F7), size: 22),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.label,
                        style: TextStyle(
                          color: _theme.textPri,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.username}@${profile.host}:${profile.port}',
                        style: TextStyle(
                          color: _theme.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7AA2F7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              profile.privateKeyPem != null ? 'RSA KEY' : 'PASSWORD',
                              style: const TextStyle(
                                color: Color(0xFF7AA2F7),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isOnline
                                      ? const Color(0xFF1F8B4C)
                                      : isTesting
                                          ? const Color(0xFFF6C177)
                                          : _theme.textMuted)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOnline
                                  ? 'ONLINE'
                                  : isTesting
                                      ? 'TESTANDO...'
                                      : 'OFFLINE',
                              style: TextStyle(
                                color: isOnline
                                    ? const Color(0xFF1F8B4C)
                                    : isTesting
                                        ? const Color(0xFFF6C177)
                                        : _theme.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ações
                if (!isConnecting) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isOnline)
                        TextButton.icon(
                          onPressed: widget.onDisconnect,
                          icon: const Icon(Icons.power_settings_new_outlined, size: 16),
                          label: const Text('Desconectar', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF7768E),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: isTesting ? null : () => _testConnection(profile),
                          icon: isTesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7AA2F7)),
                                )
                              : const Icon(Icons.wifi_find_outlined, size: 16),
                          label: Text(
                            isTesting ? 'Testando...' : 'Testar conexão',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF7AA2F7),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showAddProfileDialog(existing: profile),
                            icon: Icon(Icons.edit_outlined, size: 16, color: _theme.textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                          IconButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: _theme.surface,
                                  title: Text('Excluir Conexão', style: TextStyle(color: _theme.textPri)),
                                  content: Text('Tem certeza que deseja excluir a conexão "${profile.label}"?', style: TextStyle(color: _theme.textMuted)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text('Cancelar', style: TextStyle(color: _theme.textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await widget.profileManager.delete(profile.id);
                                if (mounted) setState(() {});
                              }
                            },
                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF7768E)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
