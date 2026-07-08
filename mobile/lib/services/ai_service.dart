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

  late GenerativeModel _chatModel;
  late GenerativeModel _completionModel;
  late String _apiKey;
  String _selectedModel = defaultModel;
  final _storage = const FlutterSecureStorage();
  bool _isInitialized = false;

  /// Sessão de chat ativa — mantém o histórico de conversa.
  ChatSession? _chatSession;

  AIService();

  // ─── Leitura/escrita segura da chave API ────────────────────────────────

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

  // ─── Configurações de geração por modo ──────────────────────────────────

  /// Config para chat: temperatura alta, muitos tokens de saída.
  GenerationConfig get _chatConfig => GenerationConfig(
    temperature: 0.7,
    topK: 40,
    topP: 0.95,
    maxOutputTokens: 8192,
  );

  /// Config para completion inline: temperatura baixa, poucas tokens de saída.
  GenerationConfig get _completionConfig => GenerationConfig(
    temperature: 0.2,
    topK: 20,
    topP: 0.9,
    maxOutputTokens: 256,
  );

  // ─── Inicialização ───────────────────────────────────────────────────────

  /// Inicializa o serviço com a chave API
  Future<void> initialize({String? apiKey}) async {
    if (_isInitialized && apiKey == null) return;

    _selectedModel = await _readModel();

    if (apiKey != null) {
      _apiKey = apiKey;
      await _writeKey(apiKey);
    } else {
      final savedKey = await _readKey();
      if (savedKey == null) {
        throw Exception('Chave API não configurada. Use setApiKey() primeiro.');
      }
      _apiKey = savedKey;
    }

    _rebuildModels();
    _isInitialized = true;
  }

  /// Reconstrói os modelos com a chave e modelo selecionado atuais.
  void _rebuildModels() {
    _chatModel = GenerativeModel(
      model: _selectedModel,
      apiKey: _apiKey,
      generationConfig: _chatConfig,
    );
    _completionModel = GenerativeModel(
      model: _selectedModel,
      apiKey: _apiKey,
      generationConfig: _completionConfig,
    );
  }

  String getModel() => _selectedModel;

  Future<void> setModel(String modelId) async {
    _selectedModel = modelId;
    await _saveModel(modelId);
    if (_isInitialized) {
      _rebuildModels();
      // Reinicia a sessão de chat ao trocar o modelo
      _chatSession = null;
    }
  }

  Future<void> setApiKey(String apiKey) async {
    _isInitialized = false;
    await initialize(apiKey: apiKey);

    try {
      final testModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
      await testModel.generateContent([Content.text('hi')]);
    } catch (e) {
      await _deleteKey();
      _isInitialized = false;
      throw Exception('Chave inválida: $e');
    }
  }

  Future<void> clearApiKey() async {
    await _deleteKey();
    _isInitialized = false;
    _chatSession = null;
  }

  Future<bool> hasApiKey() async {
    final key = await _readKey();
    return key != null;
  }

  // ─── Chat com contexto do projeto ───────────────────────────────────────

  /// Inicia (ou reinicia) uma sessão de chat com o contexto do projeto
  /// injetado como primeira mensagem do sistema.
  Future<void> startChatWithContext({
    required String activeFileContent,
    required String activeFilePath,
    required String languageName,
    List<String> projectFilePaths = const [],
    List<String> openTabsPaths = const [],
  }) async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        // Sem chave: inicia sessão sem contexto — o painel mostrará erro
        return;
      }
    }

    final systemPrompt = _buildSystemPrompt(
      activeFileContent: activeFileContent,
      activeFilePath: activeFilePath,
      languageName: languageName,
      projectFilePaths: projectFilePaths,
      openTabsPaths: openTabsPaths,
    );

    // Injeta o contexto como primeira mensagem do modelo (papel model),
    // e o "ok" como resposta do usuário, para que o chat comece com contexto.
    _chatSession = _chatModel.startChat(
      history: [
        Content.text(systemPrompt),
        Content.model([TextPart('Contexto carregado. Pode perguntar!')]),
      ],
    );
  }

  /// Monta o system prompt com o contexto do projeto.
  String _buildSystemPrompt({
    required String activeFileContent,
    required String activeFilePath,
    required String languageName,
    required List<String> projectFilePaths,
    required List<String> openTabsPaths,
  }) {
    // Trunca o conteúdo do arquivo se for muito longo
    final maxFileChars = 6000;
    final truncated = activeFileContent.length > maxFileChars;
    final fileSnippet = truncated
        ? '${activeFileContent.substring(0, maxFileChars)}\n... (truncado — arquivo muito longo)'
        : activeFileContent;

    // Monta a árvore de arquivos do projeto (só caminhos, sem conteúdo)
    final projectTree = projectFilePaths.isEmpty
        ? '(nenhum projeto aberto)'
        : projectFilePaths.take(100).join('\n');

    final openTabs = openTabsPaths.isEmpty
        ? '(nenhuma aba aberta)'
        : openTabsPaths.join('\n');

    return '''Você é um assistente de programação integrado à IDE JAL — uma IDE mobile para Android.
Ajude o usuário com código, bugs, refatoração, explicações e dúvidas sobre o projeto.

## Arquivo ativo
Caminho: $activeFilePath
Linguagem: $languageName

```$languageName
$fileSnippet
```

## Estrutura do projeto
$projectTree

## Abas abertas
$openTabs

## Instruções
- Responda sempre em português brasileiro
- Use formatação Markdown nas respostas
- Para blocos de código, especifique sempre a linguagem (ex: ```dart)
- Seja conciso e direto; evite explicações excessivamente longas
- Quando sugerir alterações no código, mostre apenas a parte modificada, não o arquivo inteiro
- Se o usuário perguntar algo que não está relacionado a programação, redirecione educadamente''';
  }

  /// Envia uma mensagem para o chat e retorna um Stream de partes de texto
  /// (streaming de resposta — texto aparece progressivamente).
  Stream<String> sendMessage(String message) async* {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        yield 'Erro: Chave API do Gemini não configurada. Vá em ⚙️ Configurações para adicionar sua chave.';
        return;
      }
    }

    // Garante que há uma sessão ativa (caso startChatWithContext não tenha sido chamado)
    _chatSession ??= _chatModel.startChat();

    try {
      final responseStream = _chatSession!.sendMessageStream(
        Content.text(message),
      );
      await for (final chunk in responseStream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      yield '\n\n**Erro ao comunicar com a IA:** $e';
    }
  }

  /// Reinicia o chat — descarta o histórico e a sessão atual.
  void resetChat() {
    _chatSession = null;
  }

  // ─── Completion inline (ghost suggestions) ──────────────────────────────

  /// Gera completion para código inline (usada pelo GhostSuggestionBar).
  /// Usa config de baixa temperatura para precisão.
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
      final response = await _completionModel.generateContent(content);
      return response.text ?? 'Sem resposta da IA';
    } catch (e) {
      return 'Erro ao gerar resposta: $e';
    }
  }

  // ─── Pergunta sobre erro (usada externamente) ────────────────────────────

  /// Pergunta sobre um erro/problema — usa o chat ativo se disponível.
  Stream<String> askAboutError(String error) {
    final prompt = '''Recebi este erro no meu código:

```
$error
```

Me explique:
1. O que significa
2. Causas comuns
3. Como resolver''';

    return sendMessage(prompt);
  }
}
