import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/jalide_theme.dart';

class AISettingsDialog extends StatefulWidget {
  final AIService aiService;

  const AISettingsDialog({super.key, required this.aiService});

  @override
  State<AISettingsDialog> createState() => _AISettingsDialogState();
}

class _AISettingsDialogState extends State<AISettingsDialog> {
  AIService get _aiService => widget.aiService;
  final _apiKeyController = TextEditingController();
  bool _hasApiKey = false;
  bool _isLoading = false;
  String _message = '';
  String _selectedModel = AIService.defaultModel;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
    _loadModel();
  }

  Future<void> _checkApiKey() async {
    final has = await _aiService.hasApiKey();
    setState(() => _hasApiKey = has);
  }

  Future<void> _loadModel() async {
    final model = _aiService.getModel();
    setState(() => _selectedModel = model);
  }

  Future<void> _onModelChanged(String? modelId) async {
    if (modelId == null) return;
    await _aiService.setModel(modelId);
    setState(() {
      _selectedModel = modelId;
      _message = '✅ Modelo alterado com sucesso!';
    });
  }

  Future<void> _saveApiKey() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite a chave API')));
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '🔄 Validando chave com a API...';
    });

    try {
      await _aiService.setApiKey(_apiKeyController.text.trim());
      setState(() {
        _hasApiKey = true;
        _message = '✅ Chave válida e salva com sucesso!';
      });
      _apiKeyController.clear();
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('API_KEY_INVALID') ||
          errorMsg.contains('invalid_argument')) {
        errorMsg = '❌ Chave inválida. Verifique se copiou corretamente.';
      } else if (errorMsg.contains('PERMISSION_DENIED')) {
        errorMsg =
            '❌ Permissão negada. A chave pode ter expirado ou não ter acesso à API Gemini.';
      } else if (errorMsg.contains('quota') ||
          errorMsg.contains('RESOURCE_EXHAUSTED')) {
        errorMsg =
            '⚠️ Cota da chave esgotada. Tente uma chave diferente ou aguarde.';
      } else {
        errorMsg = '❌ Erro: $e';
      }
      setState(() => _message = errorMsg);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeApiKey() async {
    await _aiService.clearApiKey();
    setState(() {
      _hasApiKey = false;
      _message = '🗑️ Chave removida';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return AlertDialog(
      backgroundColor: theme.bg,
      title: Text('Configuração do Gemma', style: TextStyle(color: theme.textPri)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasApiKey)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.1),
                  border: Border.all(color: theme.accent),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Chave configurada ✅',
                      style: TextStyle(color: theme.accent, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.1),
                  border: Border.all(color: theme.accent),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: theme.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chave não configurada',
                        style: TextStyle(color: theme.accent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🤖 Modelo de IA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.textPri,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedModel,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.auto_awesome, color: theme.accent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: AIService.availableModels
                      .map(
                        (m) => DropdownMenuItem(
                          value: m['id'],
                          child: Text(
                            m['label']!,
                            style: TextStyle(fontSize: 13, color: theme.textPri),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onModelChanged,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: TextStyle(color: theme.textPri),
              decoration: InputDecoration(
                labelText: 'Google Generative AI Key',
                labelStyle: TextStyle(color: theme.textMuted),
                hintText: 'Cole sua chave aqui',
                hintStyle: TextStyle(color: theme.textMuted),
                prefixIcon: Icon(Icons.vpn_key, color: theme.accent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.accent),
                ),
                filled: true,
                fillColor: theme.surface,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message,
                  style: TextStyle(fontSize: 12, color: theme.textPri),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveApiKey,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                  ),
                ),
                const SizedBox(width: 8),
                if (_hasApiKey)
                  ElevatedButton.icon(
                    onPressed: _removeApiKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text('Remover'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ Onde conseguir a chave?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textPri,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Acesse ai.google.dev\n'
                    '2. Faça login com sua conta Google\n'
                    '3. Clique em "Get API Key"\n'
                    '4. Cole a chave aqui\n\n'
                    '💚 Tier grátis: 60 req/minuto',
                    style: TextStyle(fontSize: 11, color: theme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Fechar', style: TextStyle(color: theme.accent)),
        ),
      ],
    );
  }
}
