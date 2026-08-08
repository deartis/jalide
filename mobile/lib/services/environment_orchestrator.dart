import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'file_service.dart';
import 'project_stack_detector.dart';
import 'ssh_service.dart';

/// Estado de execução dos serviços do ambiente.
enum ServiceState { stopped, starting, running, error }

class ServiceStatus {
  final String serviceName;
  final String displayName;
  ServiceState state;
  String? detail;

  ServiceStatus({
    required this.serviceName,
    required this.displayName,
    this.state = ServiceState.stopped,
    this.detail,
  });
}

/// Orquestrador de Serviços e Ambientes do JALIDE no Termux e SSH Remote.
class EnvironmentOrchestrator {
  /// Mapeamento de comandos do Termux para inicialização de daemons conhecidos.
  static const Map<String, Map<String, String>> knownServices = {
    'sshd': {
      'name': 'SSH Daemon',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep sshd || sshd',
    },
    'postgresql': {
      'name': 'PostgreSQL',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep postgres || (pg_ctl -D /data/data/com.termux/files/usr/var/lib/postgresql start || pg_ctl -D ~/pg_data start)',
    },
    'postgres': {
      'name': 'PostgreSQL',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep postgres || (pg_ctl -D /data/data/com.termux/files/usr/var/lib/postgresql start || pg_ctl -D ~/pg_data start)',
    },
    'mysql': {
      'name': 'MySQL / MariaDB',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep mysqld || mysqld_safe &',
    },
    'mariadb': {
      'name': 'MySQL / MariaDB',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep mysqld || mysqld_safe &',
    },
    'redis': {
      'name': 'Redis Server',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep redis-server || redis-server --daemonize yes',
    },
    'php-fpm': {
      'name': 'PHP FastCGI (FPM)',
      'cmd': 'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; pgrep php-fpm || php-fpm',
    },
  };

  final Map<String, ServiceStatus> _activeStatuses = {};
  final _statusStreamController = StreamController<Map<String, ServiceStatus>>.broadcast();

  Stream<Map<String, ServiceStatus>> get statusStream => _statusStreamController.stream;
  Map<String, ServiceStatus> get currentStatuses => Map.unmodifiable(_activeStatuses);

  /// Inicializa o ambiente com base no JalideProjectConfig.
  Future<void> startEnvironment({
    required JalideProjectConfig config,
    SshSession? sshSession,
  }) async {
    debugPrint('🚀 [EnvironmentOrchestrator] Inicializando ambiente para: ${config.displayName}');

    for (final serviceKey in config.services) {
      final key = serviceKey.toLowerCase();
      final serviceInfo = knownServices[key];
      final displayName = serviceInfo?['name'] ?? key.toUpperCase();

      _activeStatuses[key] = ServiceStatus(
        serviceName: key,
        displayName: displayName,
        state: ServiceState.starting,
      );
      _notify();

      try {
        if (Platform.isAndroid && (sshSession == null || sshSession.profile.host == '127.0.0.1' || sshSession.profile.host == 'localhost')) {
          final cmd = serviceInfo?['cmd'] ??
              'export PATH=\$PATH:/data/data/com.termux/files/usr/bin; [ -f ~/.bashrc ] && source ~/.bashrc; pgrep $key || $key';
          await FileService.channel.invokeMethod('runTermuxCommand', {
            'script': cmd,
          });
          _activeStatuses[key]!.state = ServiceState.running;
          debugPrint('✅ [EnvironmentOrchestrator] Serviço $displayName iniciado via Termux.');
        } else if (sshSession != null && sshSession.isConnected) {
          final cmd = serviceInfo?['cmd'] ??
              '[ -f ~/.bashrc ] && source ~/.bashrc; pgrep $key || $key';
          sshSession.writeToShell('$cmd\n');
          _activeStatuses[key]!.state = ServiceState.running;
          debugPrint('✅ [EnvironmentOrchestrator] Comando do serviço $displayName enviado via SSH.');
        } else {
          _activeStatuses[key]!.state = ServiceState.running;
        }
      } catch (e) {
        _activeStatuses[key]!.state = ServiceState.error;
        _activeStatuses[key]!.detail = e.toString();
        debugPrint('⚠️ [EnvironmentOrchestrator] Erro ao iniciar $displayName: $e');
      }
      _notify();
    }
  }

  void _notify() {
    _statusStreamController.add(Map.unmodifiable(_activeStatuses));
  }

  void dispose() {
    _statusStreamController.close();
  }
}
