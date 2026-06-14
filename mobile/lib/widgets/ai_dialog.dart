import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/jalide_theme.dart';
import 'ai_settings_dialog.dart';

class AIDialog extends StatefulWidget {
  final String? selectedCode;
  final String? language;
  final AIService aiService;

  const AIDialog({
    super.key,
    this.selectedCode,
    this.language,
    required this.aiService,
  });

  @override
  State<AIDialog> createState() => _AIDialogState();
}

class _AIDialogState extends State<AIDialog> {
  AIService get _aiService => widget.aiService;
  final _promptController = TextEditingController();
  String _response = '';
  bool _isLoading = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCode != null) {
      _promptController.text = widget.selectedCode!;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt() async {
    if (_promptController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      String result;

      switch (_selectedTab) {
        case 0: // Análise
          result = await _aiService.analyzeCode(
            _promptController.text,
            language: widget.language,
          );
          break;
        case 1: // Explicar
          result = await _aiService.explainCode(_promptController.text);
          break;
        case 2: // Documentação
          result = await _aiService.generateDocumentation(_promptController.text);
          break;
        case 3: // Chat Livre
          result = await _aiService.chat(_promptController.text);
          break;
        default:
          result = await _aiService.generateCompletion(_promptController.text);
      }

      setState(() => _response = result);
    } catch (e) {
      setState(() => _response = 'Erro: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Assistente Gemma',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textPri,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.settings, color: theme.textMuted),
                        tooltip: 'Configurações de IA',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AISettingsDialog(aiService: widget.aiService),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tabs
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.border),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTab('Análise', 0),
                    _buildTab('Explicar', 1),
                    _buildTab('Documentação', 2),
                    _buildTab('Chat', 3),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: Row(
                children: [
                  // Input
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Prompt',
                            style: TextStyle(color: theme.textMuted, fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _promptController,
                            maxLines: null,
                            expands: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                              filled: true,
                              fillColor: theme.surface,
                            ),
                            style: TextStyle(
                              fontFamily: 'Monaco',
                              fontSize: 12,
                              color: theme.textPri,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _sendPrompt,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                _isLoading ? 'Pensando...' : 'Enviar',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    color: theme.border,
                  ),
                  // Output
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Resposta',
                            style: TextStyle(color: theme.textMuted, fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              _response.isEmpty
                                  ? 'Resposta aparecerá aqui...'
                                  : _response,
                              style: TextStyle(
                                fontSize: 12,
                                color: _response.isEmpty
                                    ? theme.textMuted
                                    : theme.textPri,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _selectedTab == index;
    final theme = ThemeProvider.of(context).current;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? theme.accent : Colors.transparent,
                width: isActive ? 2 : 0,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? theme.accent : theme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
