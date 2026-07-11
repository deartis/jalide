import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ─── Callback de entrypoint do Foreground Service ───────────────────────────
// Deve ser top-level ou static — obrigatório pelo Android.
@pragma('vm:entry-point')
void _sshForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_SshKeepAliveTaskHandler());
}

// ─── Handler do Foreground Service ──────────────────────────────────────────

class _SshKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🔐 SSH Foreground Service iniciado (${starter.name})');
  }

  /// Executado a cada intervalo definido em ForegroundTaskOptions.
  /// Não precisa fazer nada aqui — o keep-alive real está no SSHClient.
  /// Este handler é apenas um "coração vazio" para manter o processo ativo.
  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🔴 SSH Foreground Service encerrado (timeout: $isTimeout)');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {
    // Botão "Desconectar" na notificação
    if (id == 'btn_disconnect') {
      FlutterForegroundTask.sendDataToMain({'action': 'disconnect'});
      FlutterForegroundTask.stopService();
    } else if (id == 'btn_exit') {
      FlutterForegroundTask.sendDataToMain({'action': 'exit'});
      FlutterForegroundTask.stopService();
      exit(0);
    }
  }

  @override
  void onNotificationPressed() {}
}

// ─── API Pública ─────────────────────────────────────────────────────────────

/// Gerencia o Android Foreground Service para manter a sessão SSH ativa.
///
/// Chame [SshForegroundService.initialize()] uma vez no `main()`.
/// Use [SshForegroundService.start()] ao conectar e [SshForegroundService.stop()]
/// ao desconectar.
class SshForegroundService {
  SshForegroundService._();

  /// Inicializa as opções do foreground service. Deve ser chamado no `main()`.
  static void initialize() {
    FlutterForegroundTask.initCommunicationPort();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'jalide_ssh_service',
        channelName: 'SSH Ativo',
        channelDescription: 'JALIDE mantém sua sessão SSH viva em background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Não precisamos de eventos periódicos — o keep-alive é feito pelo SSHClient.
        // Usamos `nothing` para minimizar consumo de bateria.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Inicia o Foreground Service com notificação para o [profileLabel] dado.
  /// Seguro chamar mais de uma vez (atualiza o serviço se já estiver rodando).
  static Future<void> start(String profileLabel) async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: '🔐 JALIDE — SSH Ativo',
          notificationText: profileLabel,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 9901,
          notificationTitle: '🔐 JALIDE — SSH Ativo',
          notificationText: profileLabel,
          notificationButtons: [
            const NotificationButton(id: 'btn_disconnect', text: 'Desconectar'),
            const NotificationButton(id: 'btn_exit', text: 'Sair'),
          ],
          callback: _sshForegroundCallback,
        );
      }
      debugPrint('✅ SSH Foreground Service iniciado para: $profileLabel');
    } catch (e) {
      debugPrint('⚠️ Falha ao iniciar SSH Foreground Service: $e');
    }
  }

  /// Para o Foreground Service (chame ao desconectar do SSH).
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        debugPrint('🔴 SSH Foreground Service parado.');
      }
    } catch (e) {
      debugPrint('⚠️ Falha ao parar SSH Foreground Service: $e');
    }
  }

  /// Solicita permissões necessárias (notificação, ignore battery optimization).
  /// Chame uma vez ao conectar pela primeira vez.
  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final permission = await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao solicitar permissões do foreground service: $e');
    }
  }

  /// Registra um callback para receber mensagens do TaskHandler.
  /// Use para escutar a ação "disconnect" da notificação.
  static void addDataCallback(Function(Object) callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  /// Remove o callback registrado.
  static void removeDataCallback(Function(Object) callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }
}
