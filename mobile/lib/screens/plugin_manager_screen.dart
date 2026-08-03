import 'package:flutter/material.dart';
import '../modules/module_manager.dart';
import '../theme/jalide_theme.dart';

class PluginManagerScreen extends StatefulWidget {
  final ModuleManager manager;

  const PluginManagerScreen({super.key, required this.manager});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    final modules = widget.manager.modules;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Plugins',
          style: TextStyle(
            color: theme.textPri,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: modules.isEmpty
          ? Center(
              child: Text(
                'Nenhum módulo registrado',
                style: TextStyle(color: theme.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                final enabled = widget.manager.isEnabled(module.id);
                final panel = module.buildPanel(context);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.extension_rounded,
                          size: 18,
                          color: theme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              module.name,
                              style: TextStyle(
                                color: theme.textPri,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              module.description.isEmpty
                                  ? module.id
                                  : module.description,
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              module.id,
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (panel != null)
                        IconButton(
                          tooltip: 'Abrir painel',
                          icon: Icon(
                            Icons.open_in_full_rounded,
                            size: 18,
                            color: theme.textMuted,
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (sheetCtx) =>
                                module.buildPanel(sheetCtx) ?? const SizedBox(),
                          ),
                        ),
                      Switch(
                        value: enabled,
                        activeThumbColor: theme.accent,
                        onChanged: (value) async {
                          await widget.manager.setEnabled(module.id, value);
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
