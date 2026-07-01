import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ssh_service.dart';

/// Gerencia reconexão automática e monitoramento de saúde da conexão SSH
class SshConnectionManager extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  static const String _lastSessionKey = 'last_ssh_session_id';
  static const String _autoReconnectKey = 'ssh_auto_reconnect_enabled';
  static const String _heartbeatIntervalKey = 'ssh_heartbeat_interval_seconds';

  final SshProfileManager profileManager;

  SshSession? _currentSession;
  SshProfile? _lastSuccessfulProfile;
  Timer? _healthCheckTimer;
  Timer? _reconnectTimer;

  bool _autoReconnectEnabled = true;
  int _heartbeatIntervalSeconds = 30;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final int _initialBackoffSeconds = 2;

  // Getters públicos para acessar estas propriedades
  bool get autoReconnectEnabled => _autoReconnectEnabled;
  int get heartbeatIntervalSeconds => _heartbeatIntervalSeconds;

  // Stream para notificar mudanças de estado
  final _connectionStateController = StreamController<SshConnectionState>.broadcast();
  final _reconnectAttemptsController = StreamController<int>.broadcast();

  Stream<SshConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<int> get reconnectAttemptsStream => _reconnectAttemptsController.stream;

  SshConnectionManager({required this.profileManager});

  /// Obtém a sessão atual
  SshSession? get currentSession => _currentSession;

  /// Verifica se está conectado
  bool get isConnected => _currentSession?.isConnected ?? false;

  /// Inicializa o gerenciador e carrega configurações
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _autoReconnectEnabled = prefs.getBool(_autoReconnectKey) ?? true;
    _heartbeatIntervalSeconds = prefs.getInt(_heartbeatIntervalKey) ?? 30;
  }

  /// Conecta a um perfil SSH e monitora a conexão
  Future<bool> connect(SshProfile profile) async {
    try {
      // Garante que a sessão anterior seja desconectada e limpa
      if (_currentSession != null) {
        try {
          await _currentSession!.disconnect();
        } catch (e) {
          debugPrint('⚠️ Erro ao fechar sessão SSH anterior: $e');
        }
      }

      _currentSession = SshSession(profile: profile);
      _connectionStateController.add(SshConnectionState.connecting);
      notifyListeners();

      await _currentSession!.connect();

      // Salva como última conexão bem-sucedida
      await _saveLastSession(profile.id);
      _lastSuccessfulProfile = profile;
      _reconnectAttempts = 0;

      _connectionStateController.add(_currentSession!.state);
      notifyListeners();

      // Inicia monitoramento de saúde
      _startHealthCheck();

      // Escuta fechamento reativo de conexão
      _listenToConnectionClose(_currentSession!);

      debugPrint('✅ SSH conectado com sucesso: ${profile.label}');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao conectar SSH: $e');
      if (_currentSession != null) {
        _currentSession!.state = SshConnectionState.error;
        _currentSession!.errorMessage = e.toString();
        _connectionStateController.add(SshConnectionState.error);
      }
      notifyListeners();
      return false;
    }
  }

  /// Define a sessão atual (útil para integração com editor_screen)
  void setCurrentSession(SshSession? session, SshProfile? profile) {
    _currentSession = session;
    _lastSuccessfulProfile = profile;
    if (session != null && profile != null) {
      _saveLastSession(profile.id);
      _startHealthCheck();
      _listenToConnectionClose(session);
    }
  }

  /// Abre um shell interativo
  Future<void> openShell({int width = 80, int height = 24}) async {
    if (_currentSession == null) throw Exception('Sem conexão SSH ativa');
    await _currentSession!.openShell(width: width, height: height);
  }

  /// Monitora saúde da conexão e reconecta se necessário
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      Duration(seconds: _heartbeatIntervalSeconds),
      (_) async {
        if (!isConnected) {
          debugPrint('⚠️ Conexão SSH perdida! Iniciando reconexão...');
          _healthCheckTimer?.cancel();
          if (_autoReconnectEnabled) {
            _triggerReconnection();
          }
        } else {
          // Envia heartbeat para manter a conexão ativa
          try {
            await _currentSession!.client?.run('echo "heartbeat"');
          } catch (e) {
            debugPrint('❌ Heartbeat falhou: $e');
            _healthCheckTimer?.cancel();
            if (_autoReconnectEnabled) {
              _triggerReconnection();
            }
          }
        }
      },
    );
  }

  /// Evita disparar múltiplos fluxos de reconexão concorrentes
  void _triggerReconnection() {
    if (_reconnectTimer?.isActive ?? false) {
      debugPrint('ℹ️ Re-conexão já está em progresso. Ignorando nova solicitação.');
      return;
    }
    _reconnectAttempts = 0;
    _attemptReconnect();
  }

  /// Escuta fechamento de conexão reativamente
  void _listenToConnectionClose(SshSession session) {
    session.client?.done.then((_) async {
      if (_currentSession == session && session.state == SshConnectionState.connected) {
        debugPrint('⚠️ SSHClient.done completado. Conexão perdida!');
        _healthCheckTimer?.cancel();
        session.state = SshConnectionState.disconnected;
        _connectionStateController.add(SshConnectionState.disconnected);
        notifyListeners();
        if (_autoReconnectEnabled) {
          _triggerReconnection();
        }
      }
    }).catchError((e) async {
      if (_currentSession == session && session.state == SshConnectionState.connected) {
        debugPrint('⚠️ SSHClient.done erro: $e. Conexão perdida!');
        _healthCheckTimer?.cancel();
        session.state = SshConnectionState.disconnected;
        _connectionStateController.add(SshConnectionState.disconnected);
        notifyListeners();
        if (_autoReconnectEnabled) {
          _triggerReconnection();
        }
      }
    });
  }

  /// Tenta reconectar com backoff exponencial
  Future<void> _attemptReconnect() async {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Máximo de tentativas de reconexão atingido');
      if (_currentSession != null) {
        _currentSession!.state = SshConnectionState.error;
      }
      _connectionStateController.add(SshConnectionState.error);
      notifyListeners();
      return;
    }

    if (_currentSession != null) {
      _currentSession!.state = SshConnectionState.connecting;
    }
    _connectionStateController.add(SshConnectionState.connecting);

    _reconnectAttempts++;
    _reconnectAttemptsController.add(_reconnectAttempts);
    notifyListeners();

    // Backoff exponencial: 2s, 4s, 8s, 16s, 32s
    final backoffSeconds = _initialBackoffSeconds * (1 << (_reconnectAttempts - 1));
    debugPrint('⏳ Reconectando em ${backoffSeconds}s... (tentativa $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () async {
      if (_lastSuccessfulProfile != null) {
        final success = await connect(_lastSuccessfulProfile!);
        if (!success) {
          await _attemptReconnect();
        } else {
          debugPrint('✅ Reconectado com sucesso!');
        }
      }
    });
  }

  /// Reconecta imediatamente (sem backoff)
  Future<bool> reconnectNow() async {
    if (_lastSuccessfulProfile == null) return false;
    _reconnectAttempts = 0;
    return connect(_lastSuccessfulProfile!);
  }

  /// Verifica se a conexão está realmente ativa (com ping rápido)
  Future<bool> checkConnectionHealth() async {
    final session = _currentSession;
    if (session == null || !session.isConnected) return false;

    try {
      // Executa um comando simples rápido para testar
      await session.client?.run('echo "ping"').timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      debugPrint('⚠️ Checagem de conexão falhou: $e');
      // Atualiza o estado da sessão localmente para desconectado
      session.state = SshConnectionState.disconnected;
      _connectionStateController.add(SshConnectionState.disconnected);
      notifyListeners();
      return false;
    }
  }

  /// Carrega a última sessão bem-sucedida
  Future<SshProfile?> getLastSuccessfulProfile() async {
    final lastId = await _storage.read(key: _lastSessionKey);
    if (lastId == null) return null;

    try {
      final profile = profileManager.profiles.firstWhere(
        (p) => p.id == lastId,
      );
      return profile;
    } catch (_) {
      return null;
    }
  }

  /// Salva a última sessão bem-sucedida
  Future<void> _saveLastSession(String profileId) async {
    await _storage.write(key: _lastSessionKey, value: profileId);
  }

  /// Define se deve reconectar automaticamente
  Future<void> setAutoReconnect(bool enabled) async {
    _autoReconnectEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReconnectKey, enabled);
    notifyListeners();
  }

  /// Define intervalo de heartbeat (em segundos)
  Future<void> setHeartbeatInterval(int seconds) async {
    _heartbeatIntervalSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_heartbeatIntervalKey, seconds);
    _startHealthCheck();
    notifyListeners();
  }

  /// Desconecta e limpa
  Future<void> disconnect() async {
    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    final session = _currentSession;
    _currentSession = null;
    _reconnectAttempts = 0;
    if (session != null) {
      await session.disconnect();
    }
    _connectionStateController.add(SshConnectionState.disconnected);
    notifyListeners();
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    _connectionStateController.close();
    _reconnectAttemptsController.close();
    super.dispose();
  }
}
