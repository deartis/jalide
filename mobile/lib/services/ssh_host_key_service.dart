import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço de verificação de host keys (known_hosts).
///
/// Persiste fingerprints MD5 de servidores SSH para detectar
/// mudanças de host key (possível ataque MITM).
class SshHostKeyService {
  SshHostKeyService._();

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'ssh_known_hosts';

  /// Carrega o mapa de known_hosts do storage.
  /// Chave: "host:port" → valor: "type:fingerprint_hex"
  static Future<Map<String, String>> _loadAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null) return {};
      return Map<String, String>.from(jsonDecode(raw));
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar known_hosts: $e');
      return {};
    }
  }

  /// Salva o mapa de known_hosts no storage.
  static Future<void> _saveAll(Map<String, String> data) async {
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(data));
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar known_hosts: $e');
    }
  }

  /// Gera a chave do host no formato "host:port".
  static String _hostKey(String host, int port) => '$host:$port';

  /// Formata o fingerprint em hex para exibição.
  static String formatFingerprint(List<int> fp) {
    return fp.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  /// Verifica se o host key é conhecido e válido.
  ///
  /// Retorna:
  /// - `HostKeyStatus.trusted` se o fingerprint é igual ao salvo
  /// - `HostKeyStatus.changed` se o host é conhecido mas o fingerprint mudou (MITM!)
  /// - `HostKeyStatus.unknown` se o host é novo (primeira conexão)
  static Future<HostKeyStatus> verify({
    required String host,
    required int port,
    required String type,
    required List<int> fingerprint,
  }) async {
    final known = await _loadAll();
    final key = _hostKey(host, port);
    final stored = known[key];

    if (stored == null) return HostKeyStatus.unknown;

    final storedParts = stored.split(':');
    if (storedParts.length < 2) return HostKeyStatus.unknown;

    final storedType = storedParts[0];
    final storedHex = storedParts.sublist(1).join(':');
    final currentHex = formatFingerprint(fingerprint);

    if (storedType == type && storedHex == currentHex) {
      return HostKeyStatus.trusted;
    }

    return HostKeyStatus.changed;
  }

  /// Salva o host key como confiável.
  static Future<void> trust({
    required String host,
    required int port,
    required String type,
    required List<int> fingerprint,
  }) async {
    final known = await _loadAll();
    final key = _hostKey(host, port);
    final hex = formatFingerprint(fingerprint);
    known[key] = '$type:$hex';
    await _saveAll(known);
    debugPrint('🔐 Host key salvo: $key → $type:$hex');
  }

  /// Remove um host key do known_hosts (para forçar re-verificação).
  static Future<void> remove({
    required String host,
    required int port,
  }) async {
    final known = await _loadAll();
    known.remove(_hostKey(host, port));
    await _saveAll(known);
    debugPrint('🗑️ Host key removido: ${_hostKey(host, port)}');
  }

  /// Retorna todos os known_hosts registrados.
  static Future<List<KnownHostEntry>> listAll() async {
    final known = await _loadAll();
    return known.entries.map((e) {
      final parts = e.value.split(':');
      return KnownHostEntry(
        hostPort: e.key,
        type: parts.isNotEmpty ? parts[0] : 'unknown',
        fingerprintHex: parts.length > 1 ? parts.sublist(1).join(':') : '',
      );
    }).toList();
  }
}

/// Status da verificação de host key.
enum HostKeyStatus {
  /// Host é novo (primeira conexão) — precisa de confirmação do usuário.
  unknown,

  /// Host é conhecido e o fingerprint confere — conexão segura.
  trusted,

  /// Host é conhecido mas o fingerprint MUDOU — possível ataque MITM!
  changed,
}

/// Entrada de um known_hosts.
class KnownHostEntry {
  final String hostPort;
  final String type;
  final String fingerprintHex;

  const KnownHostEntry({
    required this.hostPort,
    required this.type,
    required this.fingerprintHex,
  });
}
