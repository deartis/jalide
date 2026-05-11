import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../theme/jalide_theme.dart';

class FileUtils {
  static IconData iconForFile(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.js':
      case '.jsx':
      case '.mjs':
        return Icons.javascript;
      case '.json':
        return Icons.data_object;
      case '.md':
        return Icons.article_outlined;
      case '.html':
        return Icons.html;
      case '.css':
        return Icons.css;
      case '.png':
      case '.jpg':
      case '.svg':
      case '.ico':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  static Color colorForFile(String name, {required JalideThemeVariant theme}) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.js':
      case '.jsx':
      case '.mjs':
        return const Color(0xFFE8D44D); // Yellow JS
      case '.json':
        return const Color(0xFF8BC34A); // Green JSON
      case '.md':
        return const Color(0xFF29B6F6); // Blue Markdown
      case '.html':
        return const Color(0xFFFF9800); // Orange HTML
      case '.css':
        return const Color(0xFF03A9F4); // Blue CSS
      case '.png':
      case '.jpg':
      case '.svg':
      case '.ico':
        return const Color(0xFFAB47BC); // Purple Image
      default:
        return theme.textMuted;
    }
  }

  static String getDisplayName(String path, {bool uppercase = false}) {
    String name;
    if (path.startsWith('content://')) {
      try {
        final decoded = Uri.decodeFull(path);
        final parts = decoded.split('/');
        name = parts.lastWhere((s) => s.isNotEmpty, orElse: () => 'PROJETO');
      } catch (e) {
        name = 'ARQUIVO';
      }
    } else {
      name = p.basename(path);
    }
    return uppercase ? name.toUpperCase() : name;
  }
}
