import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Modelo de Conexão SSH ───────────────────────────────────────────────────

class SshProfile {
  final String id;
  final String label;
  final String host;
  final int port;
  final String username;
  // Autenticação: senha ou chave PEM (apenas um deve ser não-nulo)
  final String? password;
  final String? privateKeyPem;

  const SshProfile({
    required this.id,
    required this.label,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKeyPem,
  });

  Map<String, String> toMap() => {
    'id': id,
    'label': label,
    'host': host,
    'port': port.toString(),
    'username': username,
    'password': ?password,
    'privateKeyPem': ?privateKeyPem,
  };

  factory SshProfile.fromMap(Map<String, String> m) => SshProfile(
    id: m['id']!,
    label: m['label']!,
    host: m['host']!,
    port: int.tryParse(m['port'] ?? '22') ?? 22,
    username: m['username']!,
    password: m['password'],
    privateKeyPem: m['privateKeyPem'],
  );
}

// ─── Modelo de Entrada do File Explorer Remoto ──────────────────────────────

class RemoteFileEntry {
  final String name;
  final String path;
  final bool isDir;
  final int? sizeBytes;
  final int? modifiedAt; // Unix timestamp

  const RemoteFileEntry({
    required this.name,
    required this.path,
    required this.isDir,
    this.sizeBytes,
    this.modifiedAt,
  });
}

// ─── Estado de uma Sessão SSH ────────────────────────────────────────────────

enum SshConnectionState { disconnected, connecting, connected, error }

class SshSession {
  final SshProfile profile;
  SshConnectionState state;
  String? errorMessage;

  SSHClient? _client;
  SftpClient? _sftp;
  SSHSession? _shellSession;

  // Streams bidirecionais do shell para o terminal xterm
  StreamController<Uint8List>? _outputController;
  StreamSink<Uint8List>? _inputSink;

  SshSession({required this.profile}) : state = SshConnectionState.disconnected;

  bool get isConnected => state == SshConnectionState.connected;

  /// Stream de saída do shell remoto → xterm
  Stream<Uint8List>? get outputStream => _outputController?.stream;

  /// Envia dados do teclado → shell remoto
  void writeToShell(String data) {
    _inputSink?.add(Uint8List.fromList(utf8.encode(data)));
  }

  Future<void> connect() async {
    state = SshConnectionState.connecting;

    final socket = await SSHSocket.connect(
      profile.host,
      profile.port,
      timeout: const Duration(seconds: 15),
    );

    List<SSHKeyPair> identities = [];
    if (profile.privateKeyPem != null) {
      identities = SSHKeyPair.fromPem(profile.privateKeyPem!);
    }

    _client = SSHClient(
      socket,
      username: profile.username,
      onPasswordRequest: profile.password != null
          ? () => profile.password!
          : null,
      identities: identities,
    );

    await _client!.authenticated;
    state = SshConnectionState.connected;
  }

  /// Inicia uma sessão de shell interativo para o terminal
  Future<void> openShell({int width = 80, int height = 24}) async {
    _shellSession = await _client!.shell(
      pty: SSHPtyConfig(type: 'xterm-256color', width: width, height: height),
    );

    _outputController = StreamController<Uint8List>.broadcast();
    _inputSink = _shellSession!.stdin;

    // Shell → terminal
    _shellSession!.stdout.listen(
      (data) {
        if (_outputController != null && !_outputController!.isClosed) {
          _outputController!.add(data);
        }
      },
      onError: (e) => debugPrint('SSH stdout error: $e'),
      onDone: () {
        if (_outputController != null && !_outputController!.isClosed) {
          _outputController!.close();
        }
      },
      cancelOnError: false,
    );

    _shellSession!.stderr.listen(
      (data) {
        if (_outputController != null && !_outputController!.isClosed) {
          _outputController!.add(data);
        }
      },
      onError: (e) => debugPrint('SSH stderr error: $e'),
      cancelOnError: false,
    );
  }

  /// Redimensiona o PTY remoto (quando o usuário rotaciona o device)
  void resizePty(int width, int height) {
    _shellSession?.resizeTerminal(width, height);
  }

  // ─── SFTP ────────────────────────────────────────────────────────────────

  Future<SftpClient>? _sftpFuture;

  Future<SftpClient> _getSftp() async {
    if (_sftp != null) return _sftp!;
    _sftpFuture ??= _client!.sftp();
    _sftp = await _sftpFuture;
    return _sftp!;
  }

  /// Lista um diretório remoto
  Future<List<RemoteFileEntry>> listDir(String path) async {
    final sftp = await _getSftp();
    final items = await sftp.listdir(path);
    return items
        .where((i) => i.filename != '.' && i.filename != '..')
        .map(
          (i) => RemoteFileEntry(
            name: i.filename,
            path: '$path/${i.filename}',
            isDir: i.attr.isDirectory,
            sizeBytes: i.attr.size?.toInt(),
            modifiedAt: i.attr.modifyTime,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.isDir && !b.isDir) return -1;
        if (!a.isDir && b.isDir) return 1;
        return a.name.compareTo(b.name);
      });
  }

  /// Lê conteúdo de um arquivo remoto como String
  Future<String> readFile(String path) async {
    final sftp = await _getSftp();
    final file = await sftp.open(path);
    final bytes = await file.readBytes();
    await file.close();
    return utf8.decode(bytes);
  }

  /// Salva conteúdo de volta no arquivo remoto
  Future<void> writeFile(String path, String content) async {
    final sftp = await _getSftp();
    final file = await sftp.open(
      path,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await file.writeBytes(Uint8List.fromList(utf8.encode(content)));
    await file.close();
  }

  /// Cria um diretório remoto
  Future<void> mkdir(String path) async {
    final sftp = await _getSftp();
    await sftp.mkdir(path);
  }

  String _escapeShellArg(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  /// Exclui arquivo ou pasta remota
  Future<void> deletePath(String path, {required bool isDir}) async {
    final command = isDir ? 'rm -rf' : 'rm -f';
    await _client!.run('$command ${_escapeShellArg(path)}');
  }

  /// Retorna o diretório home do usuário remoto
  Future<String> getHomeDir() async {
    final sftp = await _getSftp();
    try {
      return await sftp.absolute('.');
    } catch (_) {
      return '/home/${profile.username}';
    }
  }

  Future<void> disconnect() async {
    await _outputController?.close();
    _shellSession?.close();
    _sftp?.close();
    _client?.close();
    state = SshConnectionState.disconnected;
    _sftp = null;
    _sftpFuture = null;
    _shellSession = null;
    _client = null;
    _outputController = null;
    _inputSink = null;
  }
}

// ─── Gerenciador de Perfis SSH (persistência segura) ─────────────────────────

class SshProfileManager extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final List<SshProfile> profiles = [];

  Future<void> load() async {
    final all = await _storage.readAll();
    profiles.clear();
    final ids = (all['profile_ids'] ?? '')
        .split(',')
        .where((s) => s.isNotEmpty);
    for (final id in ids) {
      final keys = [
        'label',
        'host',
        'port',
        'username',
        'password',
        'privateKeyPem',
      ];
      final map = <String, String>{'id': id};
      for (final k in keys) {
        final v = all['$id.$k'];
        if (v != null) map[k] = v;
      }
      profiles.add(SshProfile.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> save(SshProfile profile) async {
    final existing = profiles.indexWhere((p) => p.id == profile.id);
    if (existing == -1) {
      profiles.add(profile);
    } else {
      profiles[existing] = profile;
    }

    final ids = profiles.map((p) => p.id).join(',');
    await _storage.write(key: 'profile_ids', value: ids);

    final m = profile.toMap();
    for (final entry in m.entries) {
      if (entry.key == 'id') continue;
      await _storage.write(
        key: '${profile.id}.${entry.key}',
        value: entry.value,
      );
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    profiles.removeWhere((p) => p.id == id);
    final ids = profiles.map((p) => p.id).join(',');
    await _storage.write(key: 'profile_ids', value: ids);
    // Limpa as chaves do perfil deletado
    for (final k in [
      'label',
      'host',
      'port',
      'username',
      'password',
      'privateKeyPem',
    ]) {
      await _storage.delete(key: '$id.$k');
    }
    notifyListeners();
  }
}
