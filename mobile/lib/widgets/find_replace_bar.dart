import 'package:flutter/material.dart';
import '../theme/jalide_theme.dart';

class FindReplaceBar extends StatefulWidget {
  final TextEditingController editorController;
  final VoidCallback onClose;
  final JalideThemeVariant theme;

  const FindReplaceBar({
    super.key,
    required this.editorController,
    required this.onClose,
    required this.theme,
  });

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _showReplace = false;
  bool _caseSensitive = false;
  List<Match> _matches = [];
  int _currentMatchIndex = -1;

  JalideThemeVariant get _t => widget.theme;
  TextEditingController get _editor => widget.editorController;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _findMatches();
    if (_matches.isNotEmpty) {
      _currentMatchIndex = 0;
      _highlightCurrentMatch();
    } else {
      _currentMatchIndex = -1;
    }
    setState(() {});
  }

  void _findMatches() {
    final query = _searchController.text;
    if (query.isEmpty) {
      _matches = [];
      return;
    }
    final text = _editor.text;
    final source = _caseSensitive ? text : text.toLowerCase();
    final pattern = _caseSensitive ? query : query.toLowerCase();

    _matches = pattern.allMatches(source).toList();
  }

  void _highlightCurrentMatch() {
    if (_matches.isEmpty || _currentMatchIndex < 0 || _currentMatchIndex >= _matches.length) return;
    final match = _matches[_currentMatchIndex];
    _editor.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
  }

  void _findNext() {
    _findMatches();
    if (_matches.isEmpty) return;

    final cursorPos = _editor.selection.end;
    int nextIndex = -1;

    for (int i = 0; i < _matches.length; i++) {
      if (_matches[i].start >= cursorPos) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex == -1) {
      nextIndex = 0;
    }

    _currentMatchIndex = nextIndex;
    _highlightCurrentMatch();
    setState(() {});
  }

  void _findPrevious() {
    _findMatches();
    if (_matches.isEmpty) return;

    final cursorPos = _editor.selection.start;
    int prevIndex = -1;

    for (int i = _matches.length - 1; i >= 0; i--) {
      if (_matches[i].end <= cursorPos) {
        prevIndex = i;
        break;
      }
    }

    if (prevIndex == -1) {
      prevIndex = _matches.length - 1;
    }

    _currentMatchIndex = prevIndex;
    _highlightCurrentMatch();
    setState(() {});
  }

  void _replaceCurrent() {
    if (_matches.isEmpty || _currentMatchIndex < 0) return;
    final match = _matches[_currentMatchIndex];
    final replacement = _replaceController.text;

    final text = _editor.text;
    final newText = text.replaceRange(match.start, match.end, replacement);

    _editor.text = newText;
    _editor.selection = TextSelection(
      baseOffset: match.start + replacement.length,
      extentOffset: match.start + replacement.length,
    );

    _findMatches();
    if (_matches.isNotEmpty) {
      final cursor = _editor.selection.start;
      int nextIdx = -1;
      for (int i = 0; i < _matches.length; i++) {
        if (_matches[i].start >= cursor) {
          nextIdx = i;
          break;
        }
      }
      _currentMatchIndex = nextIdx != -1 ? nextIdx : 0;
      _highlightCurrentMatch();
    } else {
      _currentMatchIndex = -1;
    }
    setState(() {});
  }

  void _replaceAll() {
    if (_matches.isEmpty) return;
    final replacement = _replaceController.text;
    final text = _editor.text;
    final query = _searchController.text;
    if (query.isEmpty) return;

    final buffer = StringBuffer();
    int searchFrom = 0;
    final lowerText = text.toLowerCase();
    final lowerQuery = _caseSensitive ? query : query.toLowerCase();

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, searchFrom);
      if (idx == -1) {
        buffer.write(text.substring(searchFrom));
        break;
      }
      buffer.write(text.substring(searchFrom, idx));
      buffer.write(replacement);
      searchFrom = idx + query.length;
    }

    _editor.text = buffer.toString();
    _editor.selection = const TextSelection.collapsed(offset: 0);
    _findMatches();
    _currentMatchIndex = _matches.isNotEmpty ? 0 : -1;
    _highlightCurrentMatch();
    setState(() {});
  }

  String get _matchCountText {
    if (_searchController.text.isEmpty) return '';
    if (_matches.isEmpty) return '0/0';
    return '${_currentMatchIndex + 1}/${_matches.length}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _t.surface,
        border: Border(bottom: BorderSide(color: _t.border, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchRow(),
          if (_showReplace) _buildReplaceRow(),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  color: _t.textPri,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(
                    color: _t.textMuted,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: _t.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: _t.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: _t.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: _t.accent, width: 1.5),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _findNext(),
              ),
            ),
          ),
          if (_matchCountText.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              _matchCountText,
              style: TextStyle(
                color: _t.textMuted,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(width: 2),
          _iconBtn(icon: Icons.keyboard_arrow_up, tooltip: 'Anterior', onTap: _findPrevious),
          _iconBtn(icon: Icons.keyboard_arrow_down, tooltip: 'Proximo', onTap: _findNext),
          _iconBtn(
            icon: _showReplace ? Icons.expand_less : Icons.expand_more,
            tooltip: 'Substituir',
            onTap: () => setState(() => _showReplace = !_showReplace),
          ),
          _iconBtn(icon: Icons.close, tooltip: 'Fechar', onTap: widget.onClose),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _buildReplaceRow() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _t.border, width: 0.5)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 30,
                child: TextField(
                  controller: _replaceController,
                  style: TextStyle(
                    color: _t.textPri,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Substituir...',
                    hintStyle: TextStyle(
                      color: _t.textMuted,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: _t.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: _t.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: _t.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: _t.accent, width: 1.5),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _textBtn('Substituir', _replaceCurrent),
            _textBtn('Todas', _replaceAll),
            _toggleBtn('Aa', _caseSensitive, () {
              setState(() => _caseSensitive = !_caseSensitive);
              _onSearchChanged();
            }),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 18, color: _t.textMuted),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        splashRadius: 14,
        onPressed: onTap,
      ),
    );
  }

  Widget _textBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 28,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: _t.accent.withValues(alpha: 0.15),
            foregroundColor: _t.accent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: _t.accent.withValues(alpha: 0.3)),
            ),
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 28,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: active
                ? _t.accent.withValues(alpha: 0.25)
                : _t.bg,
            foregroundColor: active ? _t.accent : _t.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(
                color: active ? _t.accent.withValues(alpha: 0.5) : _t.border,
              ),
            ),
            textStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
