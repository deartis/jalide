import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';
import '../theme/jalide_theme.dart';
import 'ai_settings_dialog.dart';

// ─── Modelos de mensagem ─────────────────────────────────────────────────────

enum ChatMsgRole { user, ai, system }

class ChatMessage {
  final ChatMsgRole role;
  String text;
  bool isStreaming;

  ChatMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
  });

  /// Serializa para JSON (para persistência em disco)
  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'isStreaming': isStreaming,
  };

  /// Desserializa do JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: ChatMsgRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => ChatMsgRole.system,
    ),
    text: json['text'] as String? ?? '',
    isStreaming: json['isStreaming'] as bool? ?? false,
  );
}

// ─── Comandos rápidos ────────────────────────────────────────────────────────

class _QuickCommand {
  final String trigger;   // ex: '/explain'
  final String label;     // ex: 'Explicar código'
  final String icon;
  final String Function(String fileName) buildPrompt;

  const _QuickCommand({
    required this.trigger,
    required this.label,
    required this.icon,
    required this.buildPrompt,
  });
}

const _quickCommands = [
  _QuickCommand(
    trigger: '/explain',
    label: 'Explicar código',
    icon: '🔍',
    buildPrompt: _promptExplain,
  ),
  _QuickCommand(
    trigger: '/refactor',
    label: 'Sugerir refatoração',
    icon: '♻️',
    buildPrompt: _promptRefactor,
  ),
  _QuickCommand(
    trigger: '/test',
    label: 'Gerar testes',
    icon: '🧪',
    buildPrompt: _promptTest,
  ),
  _QuickCommand(
    trigger: '/fix',
    label: 'Encontrar e corrigir bugs',
    icon: '🐛',
    buildPrompt: _promptFix,
  ),
  _QuickCommand(
    trigger: '/doc',
    label: 'Gerar documentação',
    icon: '📝',
    buildPrompt: _promptDoc,
  ),
];

String _promptExplain(String f) => 'Explique o que o arquivo $f faz, em detalhes. Descreva as principais funções, classes e o fluxo de execução.';
String _promptRefactor(String f) => 'Analise o arquivo $f e sugira melhorias de refatoração: organização, nomes, separação de responsabilidades e padrões de projeto aplicáveis.';
String _promptTest(String f) => 'Gere testes unitários para as principais funções e classes do arquivo $f. Use as convenções de teste da linguagem atual.';
String _promptFix(String f) => 'Analise o arquivo $f em busca de bugs, problemas de performance, vazamentos de memória e más práticas. Liste os problemas e sugira as correções.';
String _promptDoc(String f) => 'Gere documentação completa para o arquivo $f: docstrings/comentários para todas as classes, métodos e parâmetros públicos.';

// ─── Painel principal ────────────────────────────────────────────────────────

/// Painel de chat de IA — abre como bottom sheet deslizável.
/// Recebe o contexto do projeto já injetado no [aiService] antes de ser aberto.
class AIChatPanel extends StatefulWidget {
  final AIService aiService;

  /// Texto descritivo do contexto carregado, exibido na mensagem inicial.
  final String contextSummary;

  /// Nome do arquivo ativo (para os prompts rápidos).
  final String activeFileName;

  /// Histórico de mensagens anterior (para restaurar a conversa ao reabrir).
  final List<ChatMessage> initialMessages;

  /// Chamado sempre que o histórico muda, para que o pai possa persistir.
  final void Function(List<ChatMessage>)? onMessagesChanged;

  /// Callback para inserir texto no cursor do editor ativo.
  final void Function(String text)? onInsertAtCursor;

  const AIChatPanel({
    super.key,
    required this.aiService,
    required this.contextSummary,
    this.activeFileName = '',
    this.initialMessages = const [],
    this.onMessagesChanged,
    this.onInsertAtCursor,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final List<ChatMessage> _messages;
  bool _isSending = false;
  StreamSubscription<String>? _streamSub;
  Timer? _streamThrottleTimer;
  bool _streamDirty = false;

  // Comandos rápidos
  bool _showQuickCommands = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessages.isNotEmpty) {
      _messages = List<ChatMessage>.from(widget.initialMessages);
    } else {
      _messages = [
        ChatMessage(
          role: ChatMsgRole.system,
          text: widget.contextSummary,
        ),
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Escuta o campo de texto para detectar '/'
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _streamThrottleTimer?.cancel();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Input listener para comandos rápidos ───────────────────────────────

  void _onInputChanged() {
    final text = _inputController.text;
    final shouldShow = text == '/' || (text.startsWith('/') && !text.contains(' ') && text.length <= 10);
    if (shouldShow != _showQuickCommands) {
      setState(() => _showQuickCommands = shouldShow);
    }
  }

  void _applyQuickCommand(_QuickCommand cmd) {
    final fileName = widget.activeFileName.isNotEmpty ? widget.activeFileName : 'arquivo atual';
    final prompt = cmd.buildPrompt(fileName);
    _inputController.text = prompt;
    _inputController.selection = TextSelection.collapsed(offset: prompt.length);
    setState(() => _showQuickCommands = false);
  }

  // ─── Envio / cancelamento ────────────────────────────────────────────────

  void _notifyChanged() {
    widget.onMessagesChanged?.call(List.unmodifiable(_messages));
    // Persiste em disco em background
    final serialized = _messages
        .where((m) => !m.isStreaming)
        .map((m) => m.toJson())
        .toList();
    widget.aiService.persistHistory(serialized);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();
    setState(() {
      _showQuickCommands = false;
      _messages.add(ChatMessage(role: ChatMsgRole.user, text: text));
      _isSending = true;
    });
    _notifyChanged();
    _scrollToBottom();

    final aiMsg = ChatMessage(role: ChatMsgRole.ai, text: '', isStreaming: true);
    setState(() => _messages.add(aiMsg));

    try {
      final stream = widget.aiService.sendMessage(text);
      _streamSub = stream.listen(
        (chunk) {
          if (!mounted) return;
          aiMsg.text += chunk;
          _scrollToBottom();
          // Throttle: setState no máximo a cada 50ms para evitar lag no streaming
          _streamDirty = true;
          if (_streamThrottleTimer == null || !_streamThrottleTimer!.isActive) {
            _streamThrottleTimer = Timer(const Duration(milliseconds: 50), () {
              if (mounted && _streamDirty) {
                _streamDirty = false;
                setState(() {});
              }
            });
          }
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            aiMsg.isStreaming = false;
            _isSending = false;
          });
          _notifyChanged();
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            aiMsg.text = '**Erro:** $e';
            aiMsg.isStreaming = false;
            _isSending = false;
          });
          _notifyChanged();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        aiMsg.text = '**Erro inesperado:** $e';
        aiMsg.isStreaming = false;
        _isSending = false;
      });
      _notifyChanged();
    }
  }

  void _cancelStream() {
    _streamSub?.cancel();
    widget.aiService.cancelCurrentStream();
    setState(() => _isSending = false);
    // Marca a última mensagem da IA como não-streaming
    final last = _messages.lastOrNull;
    if (last != null && last.role == ChatMsgRole.ai && last.isStreaming) {
      setState(() {
        last.isStreaming = false;
        if (last.text.isEmpty) last.text = '*[Cancelado]*';
      });
    }
    _notifyChanged();
  }

  void _resetChat() {
    _streamSub?.cancel();
    widget.aiService.resetChat();
    widget.aiService.clearPersistedHistory();
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        role: ChatMsgRole.system,
        text: widget.contextSummary,
      ));
      _isSending = false;
    });
    _notifyChanged();
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

  // ─── Contador de mensagens (exclui a mensagem de sistema) ───────────────
  int get _messageCount => _messages.where((m) => m.role != ChatMsgRole.system).length;

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
              if (_showQuickCommands) _buildQuickCommandsMenu(theme),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assistente JAL',
                style: TextStyle(
                  color: theme.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              if (_messageCount > 0)
                Text(
                  '$_messageCount msg${_messageCount == 1 ? '' : 's'} na sessão',
                  style: TextStyle(color: theme.textMuted, fontSize: 10),
                ),
            ],
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

  Widget _buildBubble(ChatMessage msg, JalideThemeVariant theme) {
    switch (msg.role) {
      case ChatMsgRole.system:
        return _SystemBubble(text: msg.text, theme: theme);
      case ChatMsgRole.user:
        return _UserBubble(text: msg.text, theme: theme);
      case ChatMsgRole.ai:
        return _AIBubble(
          msg: msg,
          theme: theme,
          onInsert: widget.onInsertAtCursor != null
              ? () => _insertCodeFromMessage(msg.text)
              : null,
        );
    }
  }

  /// Extrai o primeiro bloco de código da mensagem e insere no cursor.
  void _insertCodeFromMessage(String markdown) {
    // Tenta extrair um bloco de código ```...```
    final codeBlockRegex = RegExp(r'```[\w]*\n?([\s\S]*?)```');
    final match = codeBlockRegex.firstMatch(markdown);
    final toInsert = match != null ? match.group(1)?.trim() ?? markdown : markdown;

    widget.onInsertAtCursor?.call(toInsert);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Código inserido no cursor ✓'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ThemeProvider.of(context).current.surface,
      ),
    );
  }

  // ─── Menu de comandos rápidos ────────────────────────────────────────────

  Widget _buildQuickCommandsMenu(JalideThemeVariant theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(color: theme.border, width: 0.5),
          bottom: BorderSide(color: theme.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 8, bottom: 4),
            child: Text(
              'COMANDOS RÁPIDOS',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._quickCommands.map((cmd) => _QuickCommandTile(
            command: cmd,
            theme: theme,
            onTap: () => _applyQuickCommand(cmd),
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── Barra de input ──────────────────────────────────────────────────────

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
                hintText: 'Pergunte sobre o código… (/ para comandos)',
                hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSending
                ? Tooltip(
                    key: const ValueKey('cancel'),
                    message: 'Cancelar resposta',
                    child: IconButton(
                      icon: Icon(Icons.stop_circle_outlined, color: theme.accent, size: 24),
                      onPressed: _cancelStream,
                    ),
                  )
                : IconButton(
                    key: const ValueKey('send'),
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

// ─── Tile de comando rápido ──────────────────────────────────────────────────

class _QuickCommandTile extends StatelessWidget {
  final _QuickCommand command;
  final JalideThemeVariant theme;
  final VoidCallback onTap;

  const _QuickCommandTile({
    required this.command,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Text(command.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Text(
              command.trigger,
              style: TextStyle(
                color: theme.accent,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              command.label,
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
          ],
        ),
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

/// Bolha da IA — alinhada à esquerda, com Markdown e botões de ação.
class _AIBubble extends StatelessWidget {
  final ChatMessage msg;
  final JalideThemeVariant theme;

  /// Se não-null, mostra o botão "Inserir no cursor".
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
    // Verifica se a resposta contém bloco de código
    final hasCode = msg.text.contains('```');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Botão inserir no cursor (só aparece se há código E callback disponível)
          if (hasCode && onInsert != null) ...[
            _ActionChip(
              icon: Icons.keyboard_tab_rounded,
              label: 'Inserir',
              color: theme.accent,
              onTap: onInsert!,
            ),
            const SizedBox(width: 6),
          ],
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
