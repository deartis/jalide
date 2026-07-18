import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/jalide_theme.dart';

// ─── Modelos ─────────────────────────────────────────────────────────────────

class _Key {
  final String label;
  final String value;
  final bool isAccent;
  const _Key(this.label, {String? value, this.isAccent = false})
      : value = value ?? label;
}

// ─── Widget principal ─────────────────────────────────────────────────────────

/// Teclado auxiliar em camadas estilo Termux.
/// Três abas fixas no topo: Nav | Sym | Ctrl
/// A aba Nav tem D-pad de setas no formato de cruz (como teclado físico).
class AuxKeyboard extends StatefulWidget {
  final List<String> auxKeys; // mantido por compatibilidade, não usado
  final bool ctrlActive;
  final Function(String) onKeyTap;
  final bool isTerminalMode;
  final VoidCallback? onClose;

  const AuxKeyboard({
    super.key,
    required this.auxKeys,
    this.ctrlActive = false,
    required this.onKeyTap,
    this.isTerminalMode = false,
    this.onClose,
  });

  @override
  State<AuxKeyboard> createState() => _AuxKeyboardState();
}

class _AuxKeyboardState extends State<AuxKeyboard> {
  int _layer = 0;

  // ── Camada Sym (símbolos) ─────────────────────────────────────────────────
  static const _symKeys = [
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
    _Key(r'$'),
    _Key('%'),
  ];

  // ── Camada Ctrl ───────────────────────────────────────────────────────────
  static const _ctrlKeys = [
    _Key('Ctrl+Z', value: 'Z (Undo)', isAccent: true),
    _Key('Ctrl+Y', value: 'Y (Redo)', isAccent: true),
    _Key('Ctrl+A', value: 'A (All)'),
    _Key('Ctrl+C', value: 'C (Copy)'),
    _Key('Ctrl+V', value: 'V (Paste)'),
    _Key('Ctrl+X', value: 'X (Cut)'),
    _Key('Ctrl+S', value: 'S (Save)'),
    _Key('Ctrl+D', value: 'D (Dup)'),
    _Key('Ctrl+F', value: 'F (Format)', isAccent: true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabBar(theme),
          // Cada aba tem seu próprio builder
          if (_layer == 0) _buildNavLayer(theme),
          if (_layer == 1) _buildSymLayer(theme),
          if (_layer == 2) _buildCtrlLayer(theme),
        ],
      ),
    );
  }

  // ── Barra de abas ─────────────────────────────────────────────────────────

  Widget _buildTabBar(JalideThemeVariant theme) {
    final tabs = [
      (Icons.keyboard_arrow_up_rounded, 'Nav'),
      (Icons.data_object, 'Sym'),
      (Icons.keyboard_command_key, 'Ctrl'),
    ];

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: theme.bg,
        border: Border(bottom: BorderSide(color: theme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          ...List.generate(tabs.length, (i) {
            final isActive = i == _layer;
            final (icon, label) = tabs[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _layer = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isActive ? theme.surface : Colors.transparent,
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
                      Icon(icon, size: 12,
                          color: isActive ? theme.accent : theme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        label,
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
          // Badge EDIT / TERM
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.border, width: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isTerminalMode ? Icons.terminal : Icons.code,
                  size: 10,
                  color: widget.isTerminalMode
                      ? const Color(0xFF50FA7B)
                      : theme.textMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  widget.isTerminalMode ? 'TERM' : 'EDIT',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: widget.isTerminalMode
                        ? const Color(0xFF50FA7B)
                        : theme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: theme.border, width: 0.5)),
                ),
                child: Icon(
                  Icons.keyboard_hide_rounded,
                  size: 14,
                  color: theme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Aba Nav: D-pad em cruz + teclas extras ────────────────────────────────

  Widget _buildNavLayer(JalideThemeVariant theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Lado esquerdo: Tab e Esc (um acima do outro) ──────────────────
          SizedBox(
            width: 55,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _navKey(theme, _Key('Tab', value: 'Tab', isAccent: true), height: 30),
                const SizedBox(height: 4),
                _navKey(theme, _Key('Esc', value: 'ESC', isAccent: true), height: 30),
              ],
            ),
          ),

          // ── Centro/Responsivo: Teclas extras ──────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _navKey(theme, const _Key('`', value: '`'), height: 30),
                      const SizedBox(height: 4),
                      _navKey(theme, const _Key('/', value: '/'), height: 30),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _navKey(theme, const _Key('<', value: '<'), height: 30),
                      const SizedBox(height: 4),
                      _navKey(theme, const _Key('>', value: '>'), height: 30),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _navKey(theme, const _Key('|', value: '|'), height: 30),
                      const SizedBox(height: 4),
                      _navKey(theme, const _Key('\\', value: '\\'), height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Canto direito: D-pad em cruz ───────────────────────────────────
          SizedBox(
            width: 112,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ↑ sozinho no centro
                Row(
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 32,
                      child: _dpadKey(theme, '↑', '↑'),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                // ← ↓ →
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 32, child: _dpadKey(theme, '←', '←')),
                    const SizedBox(width: 8),
                    SizedBox(width: 32, child: _dpadKey(theme, '↓', '↓')),
                    const SizedBox(width: 8),
                    SizedBox(width: 32, child: _dpadKey(theme, '→', '→')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tecla padrão da barra Nav
  Widget _navKey(JalideThemeVariant theme, _Key key, {double height = 30}) {
    final accent = theme.accent;
    final bgColor = key.isAccent
        ? accent.withValues(alpha: 0.18)
        : theme.bg.withValues(alpha: 0.8);
    final borderColor =
        key.isAccent ? accent : theme.border.withValues(alpha: 0.7);
    final textColor = key.isAccent ? accent : theme.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onKeyTap(key.value);
      },
      child: Container(
        height: height,
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
              fontWeight: key.isAccent ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // Tecla de D-pad: quadrada e destacada com seta
  Widget _dpadKey(JalideThemeVariant theme, String label, String value) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onKeyTap(value);
      },
      onLongPress: () {
        // Long press nas setas dispara repetidamente
        HapticFeedback.lightImpact();
        widget.onKeyTap(value);
      },
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.12),
          border: Border.all(color: theme.accent.withValues(alpha: 0.5), width: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── Aba Sym ───────────────────────────────────────────────────────────────

  Widget _buildSymLayer(JalideThemeVariant theme) {
    final half = (_symKeys.length / 2).ceil();
    final row1 = _symKeys.sublist(0, half);
    final row2 = _symKeys.sublist(half);

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

  // ── Aba Ctrl ──────────────────────────────────────────────────────────────

  Widget _buildCtrlLayer(JalideThemeVariant theme) {
    final half = (_ctrlKeys.length / 2).ceil();
    final row1 = _ctrlKeys.sublist(0, half);
    final row2 = _ctrlKeys.sublist(half);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKeyRow(theme, row1, isCtrlLayer: true),
          const SizedBox(height: 3),
          _buildKeyRow(theme, row2, isCtrlLayer: true),
        ],
      ),
    );
  }

  // ── Grid de teclas genéricas ──────────────────────────────────────────────

  Widget _buildKeyRow(JalideThemeVariant theme, List<_Key> keys,
      {bool isCtrlLayer = false}) {
    return SizedBox(
      height: 30,
      child: Row(
        children: keys.map((key) {
          final accent = isCtrlLayer
              ? const Color(0xFFFF79C6)
              : theme.accent;

          final bgColor = key.isAccent
              ? accent.withValues(alpha: 0.18)
              : theme.bg.withValues(alpha: 0.8);
          final borderColor =
              key.isAccent ? accent : theme.border.withValues(alpha: 0.7);
          final textColor = key.isAccent ? accent : theme.textMuted;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                if (isCtrlLayer) {
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
                      fontWeight: key.isAccent
                          ? FontWeight.bold
                          : FontWeight.normal,
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
