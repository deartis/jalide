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

  static String resolveSafPath(String safUri) {
    if (!safUri.startsWith('content://')) return safUri;
    try {
      final uri = Uri.parse(safUri);
      final decodedPath = Uri.decodeComponent(uri.path);

      // Encontra a parte depois de tree/ ou document/ (document/ tem precedência para URIs de arquivos sob pastas)
      String? treeOrDocPart;
      final docIndex = decodedPath.indexOf('document/');
      if (docIndex != -1) {
        treeOrDocPart = decodedPath.substring(docIndex + 9);
      } else {
        final treeIndex = decodedPath.indexOf('tree/');
        if (treeIndex != -1) {
          treeOrDocPart = decodedPath.substring(treeIndex + 5);
        }
      }

      if (treeOrDocPart != null) {
        if (treeOrDocPart.startsWith('primary:')) {
          final relativePath = treeOrDocPart.substring(8);
          return '/storage/emulated/0/$relativePath';
        } else if (treeOrDocPart.startsWith('home:')) {
          final relativePath = treeOrDocPart.substring(5);
          return '/data/data/com.termux/files/home/$relativePath';
        } else if (treeOrDocPart.startsWith('usr:')) {
          final relativePath = treeOrDocPart.substring(4);
          return '/data/data/com.termux/files/usr/$relativePath';
        } else if (treeOrDocPart.startsWith('raw:')) {
          return treeOrDocPart.substring(4);
        } else if (treeOrDocPart.startsWith('/')) {
          return treeOrDocPart;
        }
      }
    } catch (e) {
      debugPrint('Error resolving SAF path: $e');
    }
    return safUri;
  }
}
