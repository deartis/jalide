import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste o estado da última sessão SSH ativa.
///
/// Permite que o JALIDE retome a sessão ao reiniciar ou após queda de rede.
class SshSessionStateService {
  SshSessionStateService._();

  static const _keyProfileId    = 'ssh_active_profile_id';
  static const _keyProjectPath  = 'ssh_active_project_path';
  static const _keyIsRemote     = 'ssh_is_remote_project';

  /// Salva o estado da sessão ativa.
  /// Chame sempre que uma conexão for estabelecida com sucesso.
  static Future<void> save({
    required String profileId,
    String? projectPath,
    bool isRemoteProject = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfileId, profileId);
      await prefs.setBool(_keyIsRemote, isRemoteProject);
      if (projectPath != null) {
        await prefs.setString(_keyProjectPath, projectPath);
      } else {
        await prefs.remove(_keyProjectPath);
      }
      debugPrint('💾 Estado SSH salvo: profileId=$profileId, remote=$isRemoteProject, path=$projectPath');
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar estado SSH: $e');
    }
  }

  /// Carrega o estado salvo da última sessão.
  /// Retorna [SshPersistedState] ou `null` se não houver sessão salva.
  static Future<SshPersistedState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileId = prefs.getString(_keyProfileId);
      if (profileId == null) return null;

      return SshPersistedState(
        profileId: profileId,
        projectPath: prefs.getString(_keyProjectPath),
        isRemoteProject: prefs.getBool(_keyIsRemote) ?? false,
      );
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar estado SSH: $e');
      return null;
    }
  }

  /// Limpa o estado salvo.
  /// Chame ao desconectar intencionalmente do SSH.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyProfileId);
      await prefs.remove(_keyProjectPath);
      await prefs.remove(_keyIsRemote);
      debugPrint('🗑️ Estado SSH limpo.');
    } catch (e) {
      debugPrint('⚠️ Erro ao limpar estado SSH: $e');
    }
  }

  /// Atualiza apenas o caminho do projeto remoto ativo.
  /// Útil quando o usuário troca de projeto sem reconectar.
  static Future<void> updateProjectPath(String? projectPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (projectPath != null) {
        await prefs.setString(_keyProjectPath, projectPath);
      } else {
        await prefs.remove(_keyProjectPath);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao atualizar project path no estado SSH: $e');
    }
  }
}

/// Dados do estado da última sessão SSH persistida.
class SshPersistedState {
  final String profileId;
  final String? projectPath;
  final bool isRemoteProject;

  const SshPersistedState({
    required this.profileId,
    this.projectPath,
    this.isRemoteProject = false,
  });

  @override
  String toString() =>
      'SshPersistedState(profileId: $profileId, path: $projectPath, remote: $isRemoteProject)';
}
