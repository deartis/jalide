import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/services/project_stack_detector.dart';

void main() {
  group('ProjectStackDetector Tests', () {
    test('Detecta stack Node.js a partir do package.json', () {
      final config = ProjectStackDetector.detectFromFilenames(
        'my-app',
        ['package.json', 'src', 'README.md'],
      );

      expect(config.stack, equals('node'));
      expect(config.displayName, equals('Node.js'));
      expect(config.startCommand, equals('npm run dev'));
    });

    test('Detecta stack PHP/Laravel a partir do composer.json', () {
      final config = ProjectStackDetector.detectFromFilenames(
        'laravel-api',
        ['composer.json', 'artisan', 'app'],
      );

      expect(config.stack, equals('php'));
      expect(config.displayName, equals('PHP / Laravel'));
      expect(config.services, contains('mysql'));
      expect(config.startCommand, equals('php artisan serve'));
    });

    test('Detecta stack Python a partir de requirements.txt', () {
      final config = ProjectStackDetector.detectFromFilenames(
        'fastapi-backend',
        ['requirements.txt', 'main.py'],
      );

      expect(config.stack, equals('python'));
      expect(config.displayName, equals('Python'));
      expect(config.services, contains('postgresql'));
      expect(config.startCommand, equals('python main.py'));
    });

    test('Lê configurações personalizadas de jalide.json bruto', () {
      const rawJson = '''
      {
        "name": "Custom Stack",
        "stack": "custom",
        "displayName": "Custom App",
        "services": ["sshd", "redis"],
        "startCommand": "custom-cli start"
      }
      ''';

      final config = ProjectStackDetector.detectFromFilenames(
        'custom-proj',
        ['jalide.json'],
        rawJalideJson: rawJson,
      );

      expect(config.name, equals('Custom Stack'));
      expect(config.stack, equals('custom'));
      expect(config.services, contains('redis'));
      expect(config.startCommand, equals('custom-cli start'));
    });
  });
}
