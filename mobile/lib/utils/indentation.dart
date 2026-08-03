class IndentLine {
  final int indent;
  final bool isBlank;

  const IndentLine(this.indent, this.isBlank);
}

/// Calcula o nível de indentação (em colunas) e se a linha é vazia para cada
/// linha do texto. Tabs contam como [tabWidth] colunas.
List<IndentLine> computeLineIndents(String text, {int tabWidth = 4}) {
  final result = <IndentLine>[];
  for (final line in text.split('\n')) {
    var col = 0;
    var i = 0;
    while (i < line.length) {
      final c = line[i];
      if (c == ' ') {
        col++;
        i++;
      } else if (c == '\t') {
        col += tabWidth;
        i++;
      } else {
        break;
      }
    }
    result.add(IndentLine(col, line.trim().isEmpty));
  }
  return result;
}

/// Detecta o tamanho de indentação predominante do arquivo (2, 4, ...).
/// Retorna 4 quando não consegue detectar.
int detectIndentSize(List<IndentLine> lines) {
  final freq = <int, int>{};
  for (final line in lines) {
    if (line.indent > 0 && !line.isBlank) {
      freq[line.indent] = (freq[line.indent] ?? 0) + 1;
    }
  }
  if (freq.isEmpty) return 4;

  var best = 4;
  var bestCount = -1;
  for (final entry in freq.entries) {
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  if (best < 1 || best > 8) return 4;
  return best;
}
