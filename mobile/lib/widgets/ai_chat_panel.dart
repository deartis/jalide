import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';
import '../theme/jalide_theme.dart';
import 'ai_settings_dialog.dart';

// ─── Modelos de mensagem ─────────────────────────────────────────────────────

enum _MsgRole { user, ai, system }

class _ChatMessage {
  final _MsgRole role;
  String text;
  bool isStreaming;

  _ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
  });
}

// ─── Painel principal ────────────────────────────────────────────────────────

/// Painel de chat de IA — abre como bottom sheet deslizável.
/// Recebe o contexto do projeto já injetado no [aiService] antes de ser aberto.
class AIChatPanel extends StatefulWidget {
  final AIService aiService;

  /// Texto descritivo do contexto carregado, exibido na mensagem inicial.
  final String contextSummary;

  const AIChatPanel({
    super.key,
    required this.aiService,
    required this.contextSummary,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    // Mensagem de sistema indicando que o contexto foi carregado
    _messages.add(_ChatMessage(
      role: _MsgRole.system,
      text: widget.contextSummary,
    ));
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Envio de mensagens ──────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: _MsgRole.user, text: text));
      _isSending = true;
    });
    _scrollToBottom();

    // Cria a bolha de resposta da IA (streaming — começa vazia)
    final aiMsg = _ChatMessage(
      role: _MsgRole.ai,
      text: '',
      isStreaming: true,
    );
    setState(() => _messages.add(aiMsg));

    try {
      final stream = widget.aiService.sendMessage(text);
      _streamSub = stream.listen(
        (chunk) {
          if (!mounted) return;
          setState(() => aiMsg.text += chunk);
          _scrollToBottom();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            aiMsg.isStreaming = false;
            _isSending = false;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            aiMsg.text = '**Erro:** $e';
            aiMsg.isStreaming = false;
            _isSending = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        aiMsg.text = '**Erro inesperado:** $e';
        aiMsg.isStreaming = false;
        _isSending = false;
      });
    }
  }

  void _resetChat() {
    _streamSub?.cancel();
    widget.aiService.resetChat();
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(
        role: _MsgRole.system,
        text: widget.contextSummary,
      ));
      _isSending = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(color: theme.border, width: 1),
              left: BorderSide(color: theme.border, width: 0.5),
              right: BorderSide(color: theme.border, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              _buildHandle(theme),
              _buildHeader(theme),
              const Divider(height: 1, thickness: 0.5),
              Expanded(child: _buildMessageList(theme)),
              _buildInputBar(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(JalideThemeVariant theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(JalideThemeVariant theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Ícone da IA
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.auto_awesome, size: 16, color: theme.accent),
          ),
          const SizedBox(width: 10),
          Text(
            'Assistente JAL',
            style: TextStyle(
              color: theme.textPri,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          // Botão reiniciar conversa
          Tooltip(
            message: 'Nova conversa',
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: theme.textMuted, size: 20),
              onPressed: _isSending ? null : _resetChat,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ),
          const SizedBox(width: 4),
          // Botão configurações
          Tooltip(
            message: 'Configurar chave API',
            child: IconButton(
              icon: Icon(Icons.settings_outlined, color: theme.textMuted, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AISettingsDialog(aiService: widget.aiService),
                );
              },
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ),
          const SizedBox(width: 4),
          // Botão fechar
          IconButton(
            icon: Icon(Icons.close, color: theme.textMuted, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(JalideThemeVariant theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildBubble(msg, theme);
      },
    );
  }

  Widget _buildBubble(_ChatMessage msg, JalideThemeVariant theme) {
    switch (msg.role) {
      case _MsgRole.system:
        return _SystemBubble(text: msg.text, theme: theme);
      case _MsgRole.user:
        return _UserBubble(text: msg.text, theme: theme);
      case _MsgRole.ai:
        return _AIBubble(
          msg: msg,
          theme: theme,
          onInsert: null, // Futuramente: inserir no cursor
        );
    }
  }

  Widget _buildInputBar(JalideThemeVariant theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 1,
              enabled: !_isSending,
              style: TextStyle(
                color: theme.textPri,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'Pergunte sobre o código…',
                hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSending
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(theme.accent),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send_rounded, color: theme.accent, size: 22),
                    onPressed: _sendMessage,
                    tooltip: 'Enviar',
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Bolhas de mensagem ──────────────────────────────────────────────────────

/// Mensagem de sistema — linha centralizada com info de contexto.
class _SystemBubble extends StatelessWidget {
  final String text;
  final JalideThemeVariant theme;

  const _SystemBubble({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.border, height: 1)),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.border, height: 1)),
        ],
      ),
    );
  }
}

/// Bolha do usuário — alinhada à direita.
class _UserBubble extends StatelessWidget {
  final String text;
  final JalideThemeVariant theme;

  const _UserBubble({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.18),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: theme.accent.withValues(alpha: 0.35)),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
            color: theme.textPri,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

/// Bolha da IA — alinhada à esquerda, com Markdown e botão de copiar.
class _AIBubble extends StatelessWidget {
  final _ChatMessage msg;
  final JalideThemeVariant theme;
  final VoidCallback? onInsert;

  const _AIBubble({
    required this.msg,
    required this.theme,
    this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.text.isEmpty && msg.isStreaming)
              _buildTypingIndicator()
            else
              _buildMarkdown(context),
            if (!msg.isStreaming && msg.text.isNotEmpty)
              _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context) {
    return MarkdownBody(
      data: msg.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(color: theme.textPri, fontSize: 13, height: 1.5),
        code: TextStyle(
          color: theme.strColor,
          backgroundColor: theme.bg,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.08),
          border: Border(
            left: BorderSide(color: theme.accent, width: 3),
          ),
        ),
        h1: TextStyle(color: theme.textPri, fontSize: 16, fontWeight: FontWeight.bold),
        h2: TextStyle(color: theme.textPri, fontSize: 14, fontWeight: FontWeight.bold),
        h3: TextStyle(color: theme.textPri, fontSize: 13, fontWeight: FontWeight.w600),
        listBullet: TextStyle(color: theme.textMuted, fontSize: 13),
        strong: TextStyle(color: theme.textPri, fontWeight: FontWeight.bold),
        em: TextStyle(color: theme.textMuted, fontStyle: FontStyle.italic),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.border)),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(delay: 0, color: theme.textMuted),
        const SizedBox(width: 4),
        _Dot(delay: 150, color: theme.textMuted),
        const SizedBox(width: 4),
        _Dot(delay: 300, color: theme.textMuted),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ActionChip(
            icon: Icons.copy_all_rounded,
            label: 'Copiar',
            color: theme.textMuted,
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Copiado!'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.surface,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ponto animado para indicador de digitação.
class _Dot extends StatefulWidget {
  final int delay;
  final Color color;
  const _Dot({required this.delay, required this.color});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
