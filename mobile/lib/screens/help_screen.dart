import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/jalide_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Text(
          'Central de Ajuda & Guia',
          style: TextStyle(color: theme.textPri, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPri),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.accent,
          unselectedLabelColor: theme.textMuted,
          indicatorColor: theme.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.rocket_launch_rounded, size: 20), text: 'Primeiros Passos'),
            Tab(icon: Icon(Icons.terminal_rounded, size: 20), text: 'Termux & SSH'),
            Tab(icon: Icon(Icons.auto_awesome_rounded, size: 20), text: 'Assistente IA'),
            Tab(icon: Icon(Icons.keyboard_rounded, size: 20), text: 'Atalhos & Teclado'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickStartTab(theme),
          _buildTermuxSshTab(theme),
          _buildAiAssistantTab(theme),
          _buildShortcutsTab(theme),
        ],
      ),
    );
  }

  // ─── Aba 1: Primeiros Passos ───────────────────────────────────────────────

  Widget _buildQuickStartTab(JalideThemeVariant theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHelpCard(
          theme: theme,
          icon: Icons.folder_open_rounded,
          iconColor: const Color(0xFF7AA2F7),
          title: 'Abrindo Projetos e Arquivos',
          description:
              'No painel lateral (Explorer), toque no botão de pasta para abrir um diretório do celular via Storage Access Framework (SAF) ou selecione um perfil SSH remoto.',
        ),
        const SizedBox(height: 12),
        _buildHelpCard(
          theme: theme,
          icon: Icons.tab_rounded,
          iconColor: const Color(0xFFBB9AF7),
          title: 'Gerenciamento de Abas',
          description:
              'Abra múltiplos arquivos simultaneamente. Toque na aba para alternar, deslize a barra superior para navegar ou toque no botão × para fechar. Arquivos com alterações não salvas exibem um ponto de destaque.',
        ),
        const SizedBox(height: 12),
        _buildHelpCard(
          theme: theme,
          icon: Icons.keyboard_alt_rounded,
          iconColor: const Color(0xFF7DCFFF),
          title: 'Teclado Auxiliar de Código',
          description:
              'A barra superior do teclado contém símbolos essenciais de programação ({ }, [ ], ( ), ;, =>, =, ", \'). Toque nos botões para inserir instantaneamente no código ou terminal.',
        ),
        const SizedBox(height: 12),
        _buildHelpCard(
          theme: theme,
          icon: Icons.save_rounded,
          iconColor: const Color(0xFF9ECE6A),
          title: 'Salvamento e Formatação',
          description:
              'Use o ícone de disco na barra superior para salvar o arquivo ativo. O JALIDE formata automaticamente o código mantendo o cursor na posição relativa correta.',
        ),
      ],
    );
  }

  // ─── Aba 2: Termux & SSH ──────────────────────────────────────────────────

  Widget _buildTermuxSshTab(JalideThemeVariant theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF7AA2F7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7AA2F7).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF7AA2F7), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'O JALIDE consegue iniciar o servidor SSH do Termux (sshd) em background automaticamente ao conectar no localhost (127.0.0.1).',
                  style: TextStyle(color: theme.textPri, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildStepCard(
          theme: theme,
          stepNumber: '1',
          title: 'Habilitar Comandos Externos no Termux',
          content: 'Abra o aplicativo Termux e execute o comando abaixo:',
          codeSnippet: 'echo "allow-external-apps = true" >> ~/.termux/termux.properties && termux-reload-settings',
        ),
        const SizedBox(height: 12),
        _buildStepCard(
          theme: theme,
          stepNumber: '2',
          title: 'Garantir Permissão de Execução ao JALIDE',
          content:
              'O Android exige que o JALIDE tenha a permissão com.termux.permission.RUN_COMMAND para acionar o Termux.',
          actionButton: ElevatedButton.icon(
            onPressed: () async {
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Abrir Configurações do App'),
          ),
        ),
        const SizedBox(height: 12),
        _buildStepCard(
          theme: theme,
          stepNumber: '3',
          title: 'Remover Otimização de Bateria do Termux',
          content:
              'Vá em Configurações do Android > Aplicativos > Termux > Bateria e defina como "Sem Restrições" para o Android não encerrar o SSH em segundo plano.',
        ),
      ],
    );
  }

  // ─── Aba 3: Assistente IA ─────────────────────────────────────────────────

  Widget _buildAiAssistantTab(JalideThemeVariant theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHelpCard(
          theme: theme,
          icon: Icons.auto_awesome_rounded,
          iconColor: Colors.amber[600]!,
          title: 'Assistente IA Gemma Integrado',
          description:
              'Toque no ícone de brilho ✨ na barra superior para abrir o painel de Inteligência Artificial. Você pode fazer perguntas sobre o projeto, pedir refatorações ou correções de bugs.',
        ),
        const SizedBox(height: 12),
        _buildHelpCard(
          theme: theme,
          icon: Icons.lightbulb_rounded,
          iconColor: const Color(0xFFE0AF68),
          title: 'Ghost Autocompletar',
          description:
              'Enquanto você digita no editor, sugestões em texto transparente (fantasma) podem aparecer. Pressione Tab no teclado auxiliar para aceitar a sugestão rapidamente.',
        ),
      ],
    );
  }

  // ─── Aba 4: Atalhos & Teclado ─────────────────────────────────────────────

  Widget _buildShortcutsTab(JalideThemeVariant theme) {
    final shortcuts = [
      {'key': 'Ctrl + S', 'desc': 'Salvar o arquivo ativo'},
      {'key': 'Ctrl + Z', 'desc': 'Desfazer a última edição'},
      {'key': 'Ctrl + Y', 'desc': 'Refazer edição'},
      {'key': 'Ctrl + C / V', 'desc': 'Copiar e Colar texto selecionado'},
      {'key': 'Ctrl + A', 'desc': 'Selecionar todo o conteúdo'},
      {'key': 'Tab (Teclado Auxiliar)', 'desc': 'Inserir indentação ou aceitar sugestão IA'},
      {'key': 'EDIT / TERM', 'desc': 'Indicador no teclado que alterna o envio para o Editor ou Terminal'},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Atalhos Úteis do Editor & Teclado',
          style: TextStyle(color: theme.textPri, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...shortcuts.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    s['key']!,
                    style: TextStyle(
                      color: theme.accent,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    s['desc']!,
                    style: TextStyle(color: theme.textPri, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Componentes Auxiliares de UI ─────────────────────────────────────────

  Widget _buildHelpCard({
    required JalideThemeVariant theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: theme.textPri, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required JalideThemeVariant theme,
    required String stepNumber,
    required String title,
    required String content,
    String? codeSnippet,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.accent,
                child: Text(
                  stepNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: theme.textPri, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
          ),
          if (codeSnippet != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      codeSnippet,
                      style: const TextStyle(color: Color(0xFF7DCFFF), fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codeSnippet));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comando copiado!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copiar Comando',
                  ),
                ],
              ),
            ),
          ],
          if (actionButton != null) ...[
            const SizedBox(height: 12),
            actionButton,
          ],
        ],
      ),
    );
  }
}
