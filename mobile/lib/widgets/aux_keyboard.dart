import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

/// Definição de uma camada de teclas
class _KeyLayer {
  final String label;
  final IconData icon;
  final List<_Key> keys;
  const _KeyLayer({required this.label, required this.icon, required this.keys});
}

class _Key {
  final String label;
  final String value;
  final bool isAccent;
  const _Key(this.label, {String? value, this.isAccent = false})
      : value = value ?? label;
}

/// Teclado auxiliar em camadas estilo Termux.
/// Três abas fixas no topo: Nav | Sym | Ctrl
/// Cada aba exibe uma grade de 2 linhas de teclas sem scroll.
class AuxKeyboard extends StatefulWidget {
  final List<String> auxKeys; // mantido por compatibilidade, não usado
  final bool ctrlActive;
  final Function(String) onKeyTap;

  const AuxKeyboard({
    super.key,
    required this.auxKeys,
    this.ctrlActive = false,
    required this.onKeyTap,
  });

  @override
  State<AuxKeyboard> createState() => _AuxKeyboardState();
}

class _AuxKeyboardState extends State<AuxKeyboard> {
  int _layer = 0;

  static final List<_KeyLayer> _layers = [
    _KeyLayer(
      label: 'Nav',
      icon: Icons.keyboard_arrow_up_rounded,
      keys: [
        _Key('Tab', isAccent: true),
        _Key('↑'),
        _Key('↓'),
        _Key('←'),
        _Key('→'),
        _Key('⌫', value: 'BACKSPACE'),
        _Key('Esc', value: 'ESC', isAccent: true),
        _Key('Home', value: 'HOME'),
        _Key('End', value: 'END'),
        _Key('Sel↑', value: 'SEL_UP'),
        _Key('Sel↓', value: 'SEL_DOWN'),
        _Key('Enter', value: 'ENTER', isAccent: true),
      ],
    ),
    _KeyLayer(
      label: 'Sym',
      icon: Icons.data_object,
      keys: [
        _Key('{ }', value: '{ }'),
        _Key('[ ]', value: '[ ]'),
        _Key('( )', value: '( )'),
        _Key('" "', value: '" "'),
        _Key("' '", value: "' '"),
        _Key('` `', value: '` `'),
        _Key(';'),
        _Key(':'),
        _Key('='),
        _Key('=>'),
        _Key('->'),
        _Key('**'),
        _Key('//'),
        _Key('/*'),
        _Key('!='),
        _Key('=='),
        _Key('&&'),
        _Key('||'),
        _Key('!'),
        _Key('?'),
        _Key('@'),
        _Key('#'),
        _Key('\$'),
        _Key('%'),
      ],
    ),
    _KeyLayer(
      label: 'Ctrl',
      icon: Icons.keyboard_command_key,
      keys: [
        _Key('Ctrl+Z', value: 'Z (Undo)', isAccent: true),
        _Key('Ctrl+Y', value: 'Y (Redo)', isAccent: true),
        _Key('Ctrl+A', value: 'A (All)'),
        _Key('Ctrl+C', value: 'C (Copy)'),
        _Key('Ctrl+V', value: 'V (Paste)'),
        _Key('Ctrl+X', value: 'X (Cut)'),
        _Key('Ctrl+S', value: 'S (Save)'),
        _Key('Ctrl+D', value: 'D (Dup)'),
        _Key('Ctrl+F', value: 'F (Format)', isAccent: true),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;
    final currentLayer = _layers[_layer];

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra de abas ──────────────────────────────────────────────
          _buildTabBar(theme),
          // ── Grade de teclas ────────────────────────────────────────────
          _buildKeyGrid(theme, currentLayer.keys),
        ],
      ),
    );
  }

  Widget _buildTabBar(JalideThemeVariant theme) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: theme.bg,
        border: Border(bottom: BorderSide(color: theme.border, width: 0.5)),
      ),
      child: Row(
        children: List.generate(_layers.length, (i) {
          final isActive = i == _layer;
          final layer = _layers[i];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _layer = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.surface
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? theme.accent : Colors.transparent,
                      width: 2,
                    ),
                    right: BorderSide(color: theme.border, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      layer.icon,
                      size: 12,
                      color: isActive ? theme.accent : theme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      layer.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? theme.accent : theme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeyGrid(JalideThemeVariant theme, List<_Key> keys) {
    // Divide as teclas em 2 linhas igualitárias
    final half = (keys.length / 2).ceil();
    final row1 = keys.sublist(0, half);
    final row2 = keys.sublist(half);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKeyRow(theme, row1),
          const SizedBox(height: 3),
          _buildKeyRow(theme, row2),
        ],
      ),
    );
  }

  Widget _buildKeyRow(JalideThemeVariant theme, List<_Key> keys) {
    return SizedBox(
      height: 30,
      child: Row(
        children: keys.map((key) {
          final isCtrlLayer = _layer == 2;
          final accent = isCtrlLayer
              ? const Color(0xFFFF79C6) // rosa para Ctrl
              : theme.accent;

          final isHighlight = key.isAccent;
          final bgColor = isHighlight
              ? accent.withValues(alpha: 0.18)
              : theme.bg.withValues(alpha: 0.8);
          final borderColor =
              isHighlight ? accent : theme.border.withValues(alpha: 0.7);
          final textColor = isHighlight ? accent : theme.textMuted;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Para camada Ctrl, envia como sequência Ctrl+X
                if (isCtrlLayer) {
                  // Simula: ativa ctrl e envia a tecla
                  widget.onKeyTap('Ctrl');
                  widget.onKeyTap(key.value);
                } else {
                  widget.onKeyTap(key.value);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    key.label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight:
                          isHighlight ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
