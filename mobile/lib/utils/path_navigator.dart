/// Gerenciador de histórico de navegação de pastas
class PathNavigator {
  final List<String> _history = [];
  int _currentIndex = -1;

  /// Adiciona um novo caminho ao histórico
  void push(String path) {
    // Remove histórico para frente se houver
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    
    // Não adiciona caminho duplicado
    if (_currentIndex >= 0 && _history[_currentIndex] == path) {
      return;
    }
    
    _history.add(path);
    _currentIndex++;
  }

  /// Volta para o caminho anterior
  String? popBack() {
    if (_currentIndex > 0) {
      _currentIndex--;
      return _history[_currentIndex];
    }
    return null;
  }

  /// Avança para o próximo caminho no histórico
  String? moveForward() {
    if (_currentIndex < _history.length - 1) {
      _currentIndex++;
      return _history[_currentIndex];
    }
    return null;
  }

  /// Retorna o caminho atual
  String? get current =>
      _currentIndex >= 0 && _currentIndex < _history.length
          ? _history[_currentIndex]
          : null;

  /// Verifica se pode voltar
  bool get canGoBack => _currentIndex > 0;

  /// Verifica se pode avançar
  bool get canGoForward => _currentIndex < _history.length - 1;

  /// Limpa o histórico
  void clear() {
    _history.clear();
    _currentIndex = -1;
  }
}
