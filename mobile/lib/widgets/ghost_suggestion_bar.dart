import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import '../l10n/app_localizations.dart';
import '../services/ai_service.dart';
import '../theme/jalide_theme.dart';

/// Barra de sugestão ghost — aparece acima do teclado auxiliar
/// quando a IA gera uma sugestão para o contexto atual do código.
class GhostSuggestionBar extends StatefulWidget {
  final CodeController controller;
  final String languageName;
  final bool enabled;
  final AIService aiService;

  const GhostSuggestionBar({
    super.key,
    required this.controller,
    required this.languageName,
    this.enabled = true,
    required this.aiService,
  });

  @override
  State<GhostSuggestionBar> createState() => _GhostSuggestionBarState();
}

class _GhostSuggestionBarState extends State<GhostSuggestionBar>
    with SingleTickerProviderStateMixin {
  AIService get _ai => widget.aiService;
  Timer? _debounce;
  String _suggestion = '';
  bool _isLoading = false;
  String _lastPromptSnapshot = '';
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(GhostSuggestionBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _clearSuggestion();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fadeCtrl.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!widget.enabled) return;

    // Cancela o debounce anterior
    _debounce?.cancel();

    // Limpa a sugestão ao digitar
    if (_suggestion.isNotEmpty) {
      _clearSuggestion();
    }

    // Aguarda 1.2s de pausa para disparar a IA
    _debounce = Timer(const Duration(milliseconds: 1200), _requestSuggestion);
  }

  Future<void> _requestSuggestion() async {
    if (!mounted || !widget.enabled) return;

    final text = widget.controller.text;
    if (text.isEmpty) return;

    // Pega o contexto até a posição do cursor
    final selection = widget.controller.selection;
    final cursorOffset =
        selection.isValid ? selection.baseOffset : text.length;
    final contextBefore = text.substring(0, cursorOffset.clamp(0, text.length));

    // Evita chamar a API com o mesmo contexto
    if (contextBefore == _lastPromptSnapshot) return;
    _lastPromptSnapshot = contextBefore;

    // Pega só as últimas ~600 chars para o prompt (mais contexto = melhor sugestão)
    final snippet = contextBefore.length > 600
        ? '...${contextBefore.substring(contextBefore.length - 600)}'
        : contextBefore;

    // Pega até 200 chars depois do cursor para contexto bidirecional
    final contextAfter = cursorOffset < text.length
        ? text.substring(cursorOffset, (cursorOffset + 200).clamp(0, text.length))
        : '';

    setState(() => _isLoading = true);

    try {
      final prompt = '''Você é um autocomplete de código. Complete o código abaixo com UMA linha apenas, sem explicações, sem markdown, sem blocos de código.
Linguagem: ${widget.languageName}

Código antes do cursor:
$snippet
${contextAfter.isNotEmpty ? '\nCódigo após o cursor (não repita isto):\n$contextAfter' : ''}
Responda APENAS com o texto que deve ser inserido no cursor. Se não souber, responda com uma string vazia.''';

      final result = await _ai.generateCompletion(prompt);

      if (!mounted) return;

      // Filtra respostas inválidas
      final clean = _cleanSuggestion(result);
      if (clean.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _suggestion = clean;
        _isLoading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _cleanSuggestion(String raw) {
    // Remove blocos markdown
    var s = raw
        .replaceAll(RegExp(r'```[\w]*\n?'), '')
        .replaceAll('```', '')
        .trim();
    // Remove mensagens de erro do AIService
    if (s.startsWith('Erro') || s.startsWith('Error')) return '';
    // Pega só a primeira linha se for multi-linha
    final lines = s.split('\n');
    return lines.first.trim();
  }

  void _clearSuggestion() {
    _fadeCtrl.reverse().then((_) {
      if (mounted) setState(() => _suggestion = '');
    });
  }

  void _acceptSuggestion() {
    if (_suggestion.isEmpty) return;

    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final text = ctrl.text;
    final offset = sel.isValid ? sel.baseOffset : text.length;

    // Insere a sugestão na posição do cursor
    final newText =
        text.substring(0, offset) + _suggestion + text.substring(offset);
    ctrl.value = ctrl.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: offset + _suggestion.length,
      ),
    );

    _clearSuggestion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool showBar = _isLoading || _suggestion.isNotEmpty;
    if (!showBar) return const SizedBox.shrink();

    final bg = theme.surface;
    final border = theme.border;
    final textColor = theme.textMuted;
    final accentColor = theme.accent;

    return FadeTransition(
      opacity: _isLoading ? const AlwaysStoppedAnimation(1.0) : _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: border, width: 1),
            bottom: BorderSide(color: border, width: 1),
          ),
        ),
        child: _isLoading
            ? _buildLoadingState(accentColor)
            : _buildSuggestionState(textColor, accentColor, isDark),
      ),
    );
  }

  Widget _buildLoadingState(Color accentColor) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.aiGenerating,
            style: TextStyle(
              fontSize: 11,
              color: accentColor.withValues(alpha: 0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionState(
    Color textColor,
    Color accentColor,
    bool isDark,
  ) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // Ícone AI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: accentColor.withValues(alpha: 0.8),
            ),
          ),
          // Texto da sugestão
          Expanded(
            child: Text(
              _suggestion,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Botão Tab/Aceitar
          _SuggestionButton(
            label: '↵ Tab',
            color: accentColor,
            onTap: _acceptSuggestion,
          ),
          // Botão Descartar
          _SuggestionButton(
            label: '✕',
            color: accentColor.withValues(alpha: 0.5),
            onTap: _clearSuggestion,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SuggestionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
