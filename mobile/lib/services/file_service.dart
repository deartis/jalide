import 'dart:io';

abstract class FileService {
  static Future<String> readFile(String path) async {
    try {
      final file = File(path);
      return await file.readAsString();
    } catch (e) {
      throw Exception('Erro ao ler arquivo: $e');
    }
  }

  static Future<void> saveFile(String path, String content) async {
    try {
      final file = File(path);
      await file.writeAsString(content);
    } catch (e) {
      throw Exception('Erro ao salvar arquivo: $e');
    }
  }
}