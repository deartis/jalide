import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import 'ai_settings_dialog.dart';

class AIDialog extends StatefulWidget {
  final String? selectedCode;
  final String? language;

  const AIDialog({
    super.key,
    this.selectedCode,
    this.language,
  });

  @override
  State<AIDialog> createState() => _AIDialogState();
}

class _AIDialogState extends State<AIDialog> {
  final _aiService = AIService();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252526) : Colors.grey[100],
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
                        color: Colors.amber[600],
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Assistente Gemma',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        tooltip: 'Configurações de IA',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AISettingsDialog(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
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
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
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
                            style: Theme.of(context).textTheme.labelSmall,
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
                              fillColor: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.grey[50],
                            ),
                            style: const TextStyle(
                              fontFamily: 'Monaco',
                              fontSize: 12,
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
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  // Output
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Resposta',
                            style: Theme.of(context).textTheme.labelSmall,
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
                                    ? Colors.grey[500]
                                    : null,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? Colors.blue : Colors.transparent,
                width: isActive ? 2 : 0,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.blue : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
