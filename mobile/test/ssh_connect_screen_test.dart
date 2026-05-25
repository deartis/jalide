import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/screens/ssh_connect_screen.dart';
import 'package:jalide/services/ssh_service.dart';
import 'package:jalide/theme/jalide_theme.dart';

void main() {
  testWidgets('Mostra botão de testar conexão e status online/desconectar', (tester) async {
    final profileManager = SshProfileManager();
    final offlineProfile = const SshProfile(
      id: 'offline',
      label: 'Servidor A',
      host: '192.168.0.10',
      username: 'root',
    );
    final onlineProfile = const SshProfile(
      id: 'online',
      label: 'Servidor B',
      host: 'myserver.com',
      username: 'deploy',
    );

    final onlineSession = SshSession(profile: onlineProfile)
      ..state = SshConnectionState.connected;

    profileManager.profiles
      ..add(offlineProfile)
      ..add(onlineProfile);

    await tester.pumpWidget(
      MaterialApp(
        home: ThemeProvider(
          notifier: ValueNotifier<ThemeType>(ThemeType.dark),
          child: SshConnectScreen(
            profileManager: profileManager,
            currentSession: onlineSession,
            onConnected: (_) async {},
            onDisconnect: () async {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Testar conexão'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Desconectar'), findsOneWidget);
  });
}
