import 'dart:convert';
import 'dart:io';

/// Representa a configuração de stack e ambiente de um projeto no JALIDE.
class JalideProjectConfig {
  final String name;
  final String stack; // node, php, python, java, dotnet, general
  final String displayName;
  final List<String> services; // sshd, postgresql, mysql, redis
  final Map<String, String> env;
  final List<String> preStart;
  final String? startCommand;

  const JalideProjectConfig({
    required this.name,
    required this.stack,
    required this.displayName,
    this.services = const ['sshd'],
    this.env = const {},
    this.preStart = const [],
    this.startCommand,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'stack': stack,
        'displayName': displayName,
        'services': services,
        'env': env,
        'preStart': preStart,
        if (startCommand != null) 'startCommand': startCommand,
      };

  factory JalideProjectConfig.fromJson(Map<String, dynamic> json) {
    return JalideProjectConfig(
      name: json['name'] as String? ?? 'Projeto',
      stack: json['stack'] as String? ?? 'general',
      displayName: json['displayName'] as String? ?? 'Projeto Genérico',
      services: (json['services'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['sshd'],
      env: (json['env'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const {},
      preStart: (json['preStart'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      startCommand: json['startCommand'] as String?,
    );
  }

  /// Retorna o JSON formatado com identação
  String toFormattedJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

/// Detector de Stack e Leitor de Configuração de Projetos no JALIDE.
class ProjectStackDetector {
  /// Detecta a stack a partir de um diretório local.
  static Future<JalideProjectConfig> detectLocal(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return _defaultConfig('Projeto Local');
    }

    // 1. Tenta ler o jalide.json na raiz ou em .jalide/config.json
    final configFile = File('${dir.path}/jalide.json');
    if (configFile.existsSync()) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return JalideProjectConfig.fromJson(json);
      } catch (_) {}
    }

    final hiddenConfigFile = File('${dir.path}/.jalide/config.json');
    if (hiddenConfigFile.existsSync()) {
      try {
        final content = await hiddenConfigFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return JalideProjectConfig.fromJson(json);
      } catch (_) {}
    }

    // 2. Auto-detecção por arquivos de manifesto da raiz
    final files = dir.listSync().whereType<File>().map((f) => f.path.split(Platform.pathSeparator).last).toList();

    final config = _inferConfigFromFiles(dir.path.split(Platform.pathSeparator).last, files);

    // Salva o jalide.json automaticamente na raiz se não existir
    try {
      await configFile.writeAsString(config.toFormattedJson());
    } catch (_) {}

    return config;
  }

  /// Detecta a stack a partir de uma lista de nomes de arquivos (ex: resultado de ls remoto via SFTP/SSH).
  static JalideProjectConfig detectFromFilenames(String projectName, List<String> filenames, {String? rawJalideJson}) {
    if (rawJalideJson != null && rawJalideJson.isNotEmpty) {
      try {
        final json = jsonDecode(rawJalideJson) as Map<String, dynamic>;
        return JalideProjectConfig.fromJson(json);
      } catch (_) {}
    }

    return _inferConfigFromFiles(projectName, filenames);
  }

  /// Regras de inferência por presença de arquivos de manifesto.
  static JalideProjectConfig _inferConfigFromFiles(String projectName, List<String> files) {
    final fileSet = files.map((f) => f.toLowerCase()).toSet();

    // Node.js / TypeScript / React / Vue / Vite
    if (fileSet.contains('package.json')) {
      return JalideProjectConfig(
        name: projectName,
        stack: 'node',
        displayName: 'Node.js',
        services: const ['sshd'],
        startCommand: 'npm run dev',
      );
    }

    // PHP / Laravel / Symfony
    if (fileSet.contains('composer.json') || fileSet.contains('artisan')) {
      return JalideProjectConfig(
        name: projectName,
        stack: 'php',
        displayName: 'PHP / Laravel',
        services: const ['sshd', 'mysql'],
        preStart: const ['php artisan migrate'],
        startCommand: 'php artisan serve',
      );
    }

    // Python / Django / FastAPI
    if (fileSet.contains('requirements.txt') || fileSet.contains('pyproject.toml') || fileSet.contains('manage.py')) {
      return JalideProjectConfig(
        name: projectName,
        stack: 'python',
        displayName: 'Python',
        services: const ['sshd', 'postgresql'],
        startCommand: fileSet.contains('manage.py') ? 'python manage.py runserver' : 'python main.py',
      );
    }

    // Java / Spring Boot
    if (fileSet.contains('pom.xml') || fileSet.contains('build.gradle')) {
      return JalideProjectConfig(
        name: projectName,
        stack: 'java',
        displayName: 'Java',
        services: const ['sshd', 'postgresql'],
        startCommand: fileSet.contains('pom.xml') ? './mvnw spring-boot:run' : './gradlew bootRun',
      );
    }

    // C# / .NET
    if (fileSet.any((f) => f.endsWith('.csproj') || f.endsWith('.sln'))) {
      return JalideProjectConfig(
        name: projectName,
        stack: 'dotnet',
        displayName: 'C# / .NET',
        services: const ['sshd', 'postgresql'],
        startCommand: 'dotnet run',
      );
    }

    return _defaultConfig(projectName);
  }

  static JalideProjectConfig _defaultConfig(String projectName) {
    return JalideProjectConfig(
      name: projectName,
      stack: 'general',
      displayName: 'Projeto Geral',
      services: const ['sshd'],
    );
  }
}
