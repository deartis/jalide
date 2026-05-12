import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ssh_service.dart';
import '../theme/jalide_theme.dart';

/// Tela de gerenciamento e conexão SSH.
/// Exibe perfis salvos e permite criar, editar e conectar.
class SshConnectScreen extends StatefulWidget {
  final SshProfileManager profileManager;
  final Future<void> Function(SshSession session) onConnected;

  const SshConnectScreen({
    super.key,
    required this.profileManager,
    required this.onConnected,
  });

  @override
  State<SshConnectScreen> createState() => _SshConnectScreenState();
}

class _SshConnectScreenState extends State<SshConnectScreen> {
  SshSession? _connectingSession;
  String? _connectingId;

  JalideThemeVariant get _theme => ThemeProvider.of(context).current;

  Future<void> _connect(SshProfile profile) async {
    setState(() {
      _connectingId = profile.id;
      _connectingSession = SshSession(profile: profile);
    });

    try {
      await _connectingSession!.connect();
      if (!mounted) return;
      await widget.onConnected(_connectingSession!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingId = null;
        _connectingSession = null;
      });
      _showError('Falha na conexão: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        backgroundColor: const Color(0xFFF7768E).withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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

    return Container(
      decoration: BoxDecoration(
        color: _theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnecting
              ? const Color(0xFF7AA2F7)
              : _theme.border,
          width: isConnecting ? 1.5 : 1,
        ),
        boxShadow: isConnecting
            ? [BoxShadow(color: const Color(0xFF7AA2F7).withValues(alpha: 0.15), blurRadius: 8)]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isConnecting ? null : () => _connect(profile),
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
                      const SizedBox(height: 4),
                      Row(
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
                        ],
                      ),
                    ],
                  ),
                ),
                // Ações
                if (!isConnecting) ...[
                  IconButton(
                    onPressed: () => _showAddProfileDialog(existing: profile),
                    icon: Icon(Icons.edit_outlined, size: 16, color: _theme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () async {
                      await widget.profileManager.delete(profile.id);
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF7768E)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
