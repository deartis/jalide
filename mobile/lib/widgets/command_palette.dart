import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class CommandItem {
  final String label;
  final String shortcut;
  final IconData icon;
  final VoidCallback onTap;
  final String? category;

  const CommandItem({
    required this.label,
    required this.shortcut,
    required this.icon,
    required this.onTap,
    this.category,
  });
}

class _CommandGroup {
  final String title;
  final List<CommandItem> items;

  const _CommandGroup(this.title, this.items);
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
  List<_CommandGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _groups = _buildGroups(widget.commands);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static List<_CommandGroup> _buildGroups(List<CommandItem> commands) {
    final groups = <String, List<CommandItem>>{};
    final order = <String>[];
    for (final cmd in commands) {
      final cat = cmd.category ?? 'Geral';
      if (!groups.containsKey(cat)) {
        groups[cat] = [];
        order.add(cat);
      }
      groups[cat]!.add(cmd);
    }
    return [for (final cat in order) _CommandGroup(cat, groups[cat]!)];
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _groups = _buildGroups(widget.commands);
      } else {
        final q = query.toLowerCase();
        _groups = _buildGroups(widget.commands
            .where((c) => c.label.toLowerCase().contains(q))
            .toList());
      }
    });
  }

  int get _totalRows =>
      _groups.fold(0, (sum, g) => sum + 1 + g.items.length);

  Object? _rowAt(int index) {
    var cursor = 0;
    for (final group in _groups) {
      if (index == cursor) return group.title;
      cursor++;
      if (index < cursor + group.items.length) {
        return group.items[index - cursor];
      }
      cursor += group.items.length;
    }
    return null;
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
                      child: _groups.isEmpty
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
                              itemCount: _totalRows,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemBuilder: (context, index) {
                                final entry = _rowAt(index);
                                if (entry is String) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      entry,
                                      style: TextStyle(
                                        color: theme.accent,
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  );
                                }
                                final cmd = entry as CommandItem;
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
                                        Icon(cmd.icon,
                                            size: 18, color: theme.accent),
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: theme.border),
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
