import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class CommandItem {
  final String label;
  final String shortcut;
  final IconData icon;
  final VoidCallback onTap;

  const CommandItem({
    required this.label,
    required this.shortcut,
    required this.icon,
    required this.onTap,
  });
}

class CommandPalette extends StatefulWidget {
  final JalideThemeVariant theme;
  final List<CommandItem> commands;

  const CommandPalette({
    super.key,
    required this.theme,
    required this.commands,
  });

  static Future<CommandItem?> show(
    BuildContext context, {
    required JalideThemeVariant theme,
    required List<CommandItem> commands,
  }) {
    return showModalBottomSheet<CommandItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommandPalette(theme: theme, commands: commands),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<CommandItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.commands;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.commands;
      } else {
        _filtered = widget.commands
            .where((c) => c.label.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(top: BorderSide(color: theme.border)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onSearch,
                        style: TextStyle(
                          color: theme.textPri,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar comandos...',
                          hintStyle: TextStyle(
                            color: theme.textMuted,
                            fontFamily: 'monospace',
                          ),
                          prefixIcon: Icon(Icons.search, color: theme.textMuted),
                          filled: true,
                          fillColor: theme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: theme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: theme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: theme.accent),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum comando encontrado',
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _filtered.length,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemBuilder: (context, index) {
                                final cmd = _filtered[index];
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    cmd.onTap();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(cmd.icon, size: 18, color: theme.accent),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            cmd.label,
                                            style: TextStyle(
                                              color: theme.textPri,
                                              fontFamily: 'monospace',
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (cmd.shortcut.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.surface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: theme.border),
                                            ),
                                            child: Text(
                                              cmd.shortcut,
                                              style: TextStyle(
                                                color: theme.textMuted,
                                                fontFamily: 'monospace',
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
