class CodeFormatter {
  /// Formata o código fornecido de forma 100% local e offline.
  /// Suporta indentação baseada em blocos e tags.
  static String format(String code, String language) {
    if (code.isEmpty) return code;
    
    final lang = language.toUpperCase();
    if (lang == 'PYTHON' || lang == 'MARKDOWN') {
      // Para python/markdown, apenas removemos espaços em branco extras no fim de cada linha,
      // sem alterar o recuo do início (que possui significado sintático).
      return code.split('\n').map((l) => l.trimRight()).join('\n');
    }

    final lines = code.split('\n');
    final formattedLines = <String>[];
    int indentLevel = 0;
    const indentStr = '  '; // 2 espaços por nível

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) {
        formattedLines.add('');
        continue;
      }

      // Contadores de chaves, colchetes e parênteses
      int openingCount = 0;
      int closingCount = 0;

      // Tratamento adicional simples para HTML/XML
      final bool isHtml = lang == 'HTML' || lang == 'XML';
      bool startsWithClosingTag = false;
      bool endsWithOpeningTag = false;

      if (isHtml) {
        startsWithClosingTag = line.startsWith('</') || line.startsWith('</ ');
        
        // Verifica se a linha abre uma tag mas não a fecha na mesma linha
        if (line.startsWith('<') && !line.startsWith('</') && line.endsWith('>')) {
          if (!line.endsWith('/>') && !line.startsWith('<!--') && !line.startsWith('<!')) {
            final tagNameMatch = RegExp(r'^<([a-zA-Z0-9-]+)').firstMatch(line);
            if (tagNameMatch != null) {
              final tagName = tagNameMatch.group(1)!;
              if (!line.contains('</$tagName>')) {
                endsWithOpeningTag = true;
              }
            }
          }
        }
      }

      // Conta aberturas e fechamentos de delimitadores comuns
      for (var charIndex = 0; charIndex < line.length; charIndex++) {
        final char = line[charIndex];
        if (char == '{' || char == '[') {
          openingCount++;
        } else if (char == '}' || char == ']') {
          closingCount++;
        }
      }

      // Reduz o nível de indentação se a linha inicia com caracteres de fechamento
      final bool startsWithClosing = line.startsWith('}') || line.startsWith(']') || startsWithClosingTag;
      if (startsWithClosing) {
        indentLevel = (indentLevel - 1).clamp(0, 99);
      }

      // Adiciona a linha com o recuo correto
      final currentIndent = indentStr * indentLevel;
      formattedLines.add(currentIndent + line);

      // Ajusta o nível de recuo para a próxima linha
      if (!startsWithClosing) {
        final netBraces = openingCount - closingCount;
        indentLevel = (indentLevel + netBraces).clamp(0, 99);
        if (endsWithOpeningTag) {
          indentLevel++;
        }
      } else {
        // Se já decrementamos antes, calculamos o saldo líquido considerando que o primeiro fechamento já foi aplicado
        final netBraces = openingCount - (closingCount - 1);
        indentLevel = (indentLevel + netBraces).clamp(0, 99);
      }
    }

    return formattedLines.join('\n');
  }
}
