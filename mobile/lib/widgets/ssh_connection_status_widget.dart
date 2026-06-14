import 'package:flutter/material.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_service.dart';

/// Widget que mostra status de conexão SSH e permite controlar reconexão automática
class SshConnectionStatusWidget extends StatefulWidget {
  final SshConnectionManager connectionManager;
  final VoidCallback? onReconnect;

  const SshConnectionStatusWidget({
    super.key,
    required this.connectionManager,
    this.onReconnect,
  });

  @override
  State<SshConnectionStatusWidget> createState() => _SshConnectionStatusWidgetState();
}

class _SshConnectionStatusWidgetState extends State<SshConnectionStatusWidget> {
  late Stream<SshConnectionState> _stateStream;
  late Stream<int> _attemptsStream;

  @override
  void initState() {
    super.initState();
    _stateStream = widget.connectionManager.connectionStateStream;
    _attemptsStream = widget.connectionManager.reconnectAttemptsStream;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SshConnectionState>(
      stream: _stateStream,
      initialData: widget.connectionManager.currentSession?.state,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data ?? SshConnectionState.disconnected;
        final isConnected = state == SshConnectionState.connected;
        final isConnecting = state == SshConnectionState.connecting;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFFC8E6C9)  // Light green instead of Colors.green[50]
                : isConnecting
                    ? const Color(0xFFFFE0B2)  // Light amber instead of Colors.amber[50]
                    : const Color(0xFFFFCDD2),  // Light red instead of Colors.red[50]
            border: Border(
              left: BorderSide(
                color: isConnected
                    ? Colors.green
                    : isConnecting
                        ? Colors.amber
                        : Colors.red,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              // Status Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green
                      : isConnecting
                          ? Colors.amber
                          : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Status Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(state),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isConnected
                            ? Colors.green.shade700
                            : isConnecting
                                ? Colors.amber.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                    if (isConnecting)
                      StreamBuilder<int>(
                        stream: _attemptsStream,
                        initialData: 0,
                        builder: (context, attemptsSnapshot) {
                          final attempts = attemptsSnapshot.data ?? 0;
                          return Text(
                            'Tentativa $attempts/5 de reconexão...',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade700,
                            ),
                          );
                        },
                      )
                    else if (isConnected)
                      Text(
                        widget.connectionManager.currentSession?.profile.label ?? 'Conectado',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              // Ações
              if (!isConnecting)
                Row(
                  children: [
                    if (!isConnected && widget.connectionManager.currentSession != null)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: widget.onReconnect,
                        tooltip: 'Reconectar agora',
                      ),
                    if (isConnected)
                      IconButton(
                        icon: const Icon(Icons.settings, size: 18),
                        onPressed: () => _showSettings(context),
                        tooltip: 'Configurações',
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(SshConnectionState state) {
    switch (state) {
      case SshConnectionState.connected:
        return '✅ SSH Conectado';
      case SshConnectionState.connecting:
        return '🔄 Conectando...';
      case SshConnectionState.error:
        return '❌ Erro na conexão';
      case SshConnectionState.disconnected:
        return '⭕ Desconectado';
    }
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SshConnectionSettingsSheet(
        connectionManager: widget.connectionManager,
      ),
    );
  }
}

/// Bottom sheet para configurações de reconexão
class _SshConnectionSettingsSheet extends StatefulWidget {
  final SshConnectionManager connectionManager;

  const _SshConnectionSettingsSheet({
    required this.connectionManager,
  });

  @override
  State<_SshConnectionSettingsSheet> createState() =>
      _SshConnectionSettingsSheetState();
}

class _SshConnectionSettingsSheetState
    extends State<_SshConnectionSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configurações SSH',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Auto-Reconexão'),
            subtitle: const Text('Reconectar automaticamente ao perder conexão'),
            trailing: Switch(
              value: widget.connectionManager.autoReconnectEnabled,
              onChanged: (value) async {
                await widget.connectionManager.setAutoReconnect(value);
                if (mounted) setState(() {});
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Intervalo de Heartbeat'),
            subtitle:
                Text('${widget.connectionManager.heartbeatIntervalSeconds}s'),
            onTap: () => _showHeartbeatDialog(context),
          ),
          const SizedBox(height: 10),
          ListTile(
            title: const Text('Reconectar Agora'),
            leading: const Icon(Icons.refresh),
            onTap: () async {
              if (!mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final success =
                  await widget.connectionManager.reconnectNow();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '✅ Reconectado com sucesso!'
                        : '❌ Erro ao reconectar',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showHeartbeatDialog(BuildContext context) {
    int newInterval = widget.connectionManager.heartbeatIntervalSeconds;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Intervalo de Heartbeat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Atual: ${widget.connectionManager.heartbeatIntervalSeconds}s'),
            const SizedBox(height: 20),
            Slider(
              value: newInterval.toDouble(),
              min: 10,
              max: 120,
              divisions: 11,
              label: '${newInterval}s',
              onChanged: (value) {
                setState(() => newInterval = value.toInt());
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await widget.connectionManager.setHeartbeatInterval(newInterval);
              if (!mounted) return;
              nav.pop();
              setState(() {});
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
