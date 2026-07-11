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
      case '.ts':
      case '.tsx':
        return Icons.javascript; // typescript
      case '.json':
        return Icons.data_object;
      case '.md':
        return Icons.article_outlined;
      case '.html':
      case '.htm':
        return Icons.html;
      case '.css':
      case '.scss':
      case '.sass':
        return Icons.css;
      case '.py':
      case '.pyw':
        return Icons.terminal; // python
      case '.dart':
        return Icons.flutter_dash;
      case '.cpp':
      case '.cc':
      case '.cxx':
      case '.c':
      case '.h':
      case '.hpp':
        return Icons.memory;
      case '.sh':
      case '.bash':
      case '.zsh':
        return Icons.terminal;
      case '.yaml':
      case '.yml':
        return Icons.settings_outlined;
      case '.xml':
        return Icons.code;
      case '.sql':
        return Icons.storage;
      case '.rs':
        return Icons.settings; // rust
      case '.go':
        return Icons.sports_score; // go
      case '.lock':
      case '.gitignore':
      case '.env':
        return Icons.lock_outline;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.svg':
      case '.ico':
      case '.webp':
        return Icons.image_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
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
      case '.ts':
      case '.tsx':
        return const Color(0xFF3178C6); // Blue TypeScript
      case '.json':
        return const Color(0xFF8BC34A); // Green JSON
      case '.md':
        return const Color(0xFF29B6F6); // Blue Markdown
      case '.html':
      case '.htm':
        return const Color(0xFFFF9800); // Orange HTML
      case '.css':
      case '.scss':
      case '.sass':
        return const Color(0xFF03A9F4); // Blue CSS
      case '.py':
      case '.pyw':
        return const Color(0xFF4CAF50); // Green Python
      case '.dart':
        return const Color(0xFF54C5F8); // Dart blue
      case '.cpp':
      case '.cc':
      case '.cxx':
        return const Color(0xFF00BCD4); // Cyan C++
      case '.c':
      case '.h':
      case '.hpp':
        return const Color(0xFF26C6DA); // Light cyan C
      case '.sh':
      case '.bash':
      case '.zsh':
        return const Color(0xFF9CCC65); // Light green Shell
      case '.yaml':
      case '.yml':
        return const Color(0xFFFFB74D); // Orange YAML
      case '.xml':
        return const Color(0xFFEF9A9A); // Pink XML
      case '.sql':
        return const Color(0xFFCE93D8); // Purple SQL
      case '.rs':
        return const Color(0xFFFF7043); // Orange Rust
      case '.go':
        return const Color(0xFF26C6DA); // Cyan Go
      case '.lock':
      case '.gitignore':
      case '.env':
        return const Color(0xFF78909C); // Grey lock files
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.svg':
      case '.ico':
      case '.webp':
        return const Color(0xFFAB47BC); // Purple Image
      case '.pdf':
        return const Color(0xFFF44336); // Red PDF
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
