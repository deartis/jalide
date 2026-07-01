import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static const String _apiKeyStorageKey = 'gemma_api_key';
  static const String _modelStorageKey = 'gemini_model';
  static const String defaultModel = 'gemini-2.5-flash';

  static const List<Map<String, String>> availableModels = [
    {'id': 'gemini-2.5-flash', 'label': 'Gemini 2.5 Flash (recomendado)'},
    {'id': 'gemini-2.5-pro', 'label': 'Gemini 2.5 Pro (mais inteligente)'},
    {'id': 'gemini-2.0-flash', 'label': 'Gemini 2.0 Flash'},
    {'id': 'gemini-1.5-flash', 'label': 'Gemini 1.5 Flash'},
    {'id': 'gemini-1.5-pro', 'label': 'Gemini 1.5 Pro'},
  ];

  late final GenerativeModel _model;
  late final String _apiKey;
  String _selectedModel = defaultModel;
  final _storage = const FlutterSecureStorage();
  bool _isInitialized = false;

  AIService();

  Future<String?> _readKey() async {
    try {
      final key = await _storage.read(key: _apiKeyStorageKey);
      if (key != null) return key;
    } catch (e) {
      debugPrint('Erro ao ler do Secure Storage: $e');
    }
    // Migração: versões antigas salvavam a chave em SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldKey = prefs.getString(_apiKeyStorageKey);
      if (oldKey != null) {
        await _storage.write(key: _apiKeyStorageKey, value: oldKey);
        await prefs.remove(_apiKeyStorageKey);
        return oldKey;
      }
    } catch (e) {
      debugPrint('Erro ao migrar chave do SharedPreferences: $e');
    }
    return null;
  }

  Future<String> _readModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_modelStorageKey) ?? defaultModel;
    } catch (e) {
      return defaultModel;
    }
  }

  Future<void> _saveModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelStorageKey, model);
    } catch (e) {
      debugPrint('Erro ao salvar modelo: $e');
    }
  }

  Future<void> _writeKey(String value) async {
    try {
      await _storage.write(key: _apiKeyStorageKey, value: value);
    } catch (e) {
      debugPrint('Erro ao gravar no Secure Storage: $e');
    }
  }

  Future<void> _deleteKey() async {
    try {
      await _storage.delete(key: _apiKeyStorageKey);
    } catch (e) {
      debugPrint('Erro ao deletar do Secure Storage: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyStorageKey);
    } catch (e) {
      debugPrint('Erro ao deletar do SharedPreferences: $e');
    }
  }

  /// Inicializa o serviço com a chave API
  Future<void> initialize({String? apiKey}) async {
    // Sempre re-inicializa se uma nova chave for fornecida
    if (_isInitialized && apiKey == null) return;

    // Carrega o modelo salvo
    _selectedModel = await _readModel();

    // Se forneceu chave, salva de forma segura
    if (apiKey != null) {
      _apiKey = apiKey;
      await _writeKey(apiKey);
    } else {
      // Tenta recuperar chave salva
      final savedKey = await _readKey();
      if (savedKey == null) {
        throw Exception('Chave API não configurada. Use setApiKey() primeiro.');
      }
      _apiKey = savedKey;
    }

    _rebuildModel();
    _isInitialized = true;
  }

  /// Reconstrói o GenerativeModel com o modelo e chave atuais
  void _rebuildModel() {
    _model = GenerativeModel(
      model: _selectedModel,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );
  }

  /// Retorna o modelo atualmente selecionado
  String getModel() => _selectedModel;

  /// Troca o modelo de IA em uso
  Future<void> setModel(String modelId) async {
    _selectedModel = modelId;
    await _saveModel(modelId);
    if (_isInitialized) {
      _rebuildModel();
    }
  }

  /// Define/atualiza a chave API e valida se ela funciona
  /// Lança exceção com a mensagem real da API se a chave for inválida
  Future<void> setApiKey(String apiKey) async {
    // Força re-inicialização mesmo que já esteja inicializado
    _isInitialized = false;
    await initialize(apiKey: apiKey);

    // Testa a chave imediatamente com uma chamada mínima
    try {
      final testModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
      await testModel.generateContent([Content.text('hi')]);
    } catch (e) {
      // Se falhar, remove a chave salva e lança o erro real da API
      await _deleteKey();
      _isInitialized = false;
      throw Exception('Chave inválida: $e');
    }
  }

  /// Remove a chave API salva
  Future<void> clearApiKey() async {
    await _deleteKey();
    _isInitialized = false;
  }

  /// Verifica se tem chave configurada
  Future<bool> hasApiKey() async {
    final key = await _readKey();
    return key != null;
  }

  /// Gera completion para código (autocompletar)
  Future<String> generateCompletion(String prompt) async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        return 'Erro: Chave API do Gemini não configurada. Por favor, clique no ícone de engrenagem para configurar sua chave API.';
      }
    }

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'Sem resposta da IA';
    } catch (e) {
      return 'Erro ao gerar resposta: $e';
    }
  }

  /// Analisa código e sugere melhorias
  Future<String> analyzeCode(String code, {String? language}) async {
    final langInfo = language != null ? ' ($language)' : '';
    final prompt = 'Analise este código$langInfo e sugira melhorias de forma concisa:\n\n'
        '```\n'
        '$code\n'
        '```\n\n'
        'Responda com:\n'
        '1. Problemas encontrados (se houver)\n'
        '2. 2-3 sugestões de melhoria\n'
        '3. Um exemplo corrigido (se relevante)';

    return generateCompletion(prompt);
  }

  /// Explica um trecho de código
  Future<String> explainCode(String code) async {
    final prompt = 'Explique este código de forma clara e concisa:\n\n'
        '```\n'
        '$code\n'
        '```\n\n'
        'Responda em máximo 3 linhas.';

    return generateCompletion(prompt);
  }

  /// Corrige erros em código
  Future<String> fixError(String code, String error) async {
    final prompt = 'Este código tem um erro:\n\n'
        '```\n'
        '$code\n'
        '```\n\n'
        'Erro: $error\n\n'
        'Forneça:\n'
        '1. O problema\n'
        '2. Código corrigido\n'
        '3. Uma breve explicação';

    return generateCompletion(prompt);
  }

  /// Sugere nome para variável/função
  Future<String> suggestName(String context, String type) async {
    final prompt = 'Dado este contexto:\n$context\n\n'
        'Sugira 3 nomes bons para uma $type. Formato: nome1, nome2, nome3';

    return generateCompletion(prompt);
  }

  /// Gera documentação para função
  Future<String> generateDocumentation(String code) async {
    final prompt = 'Gere documentação JSDoc/Dart Doc para esta função/método:\n\n'
        '```\n'
        '$code\n'
        '```\n\n'
        'Responda apenas com o comentário de documentação.';

    return generateCompletion(prompt);
  }

  /// Chat geral com Gemma
  Future<String> chat(String message) async {
    return generateCompletion(message);
  }

  /// Pergunta sobre um erro/problema
  Future<String> askAboutError(String error) async {
    final prompt = '''Sou um desenvolvedor e recebi este erro:

$error

Me explique:
1. O que significa
2. Causas comuns
3. Como resolver''';

    return generateCompletion(prompt);
  }
}
