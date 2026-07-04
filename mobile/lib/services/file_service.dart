import 'dart:io';
import 'package:flutter/services.dart';

abstract class FileService {
  static const channel = MethodChannel('com.jalide/termux');

  static Future<String> readFile(String path) async {
    try {
      if (path.startsWith('content://')) {
        final String content = await channel.invokeMethod('readSafFile', {'uri': path});
        return content;
      }
      final file = File(path);
      return await file.readAsString();
    } catch (e) {
      throw Exception('Erro ao ler arquivo: $e');
    }
  }

  static Future<void> saveFile(String path, String content) async {
    try {
      if (path.startsWith('content://')) {
        await channel.invokeMethod('writeSafFile', {
          'uri': path,
          'content': content,
        });
        return;
      }
      final file = File(path);
      await file.writeAsString(content);
    } catch (e) {
      throw Exception('Erro ao salvar arquivo: $e');
    }
  }
}