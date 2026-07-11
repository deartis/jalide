import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/jalide_theme.dart';

class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  // Chave local (fallback)
  String pixKey = "40dccccc-04fa-4c63-959d-f671794d5f27";
  bool _isLoading = true;

  // Valor da doação
  double _donationAmount = 2.0;
  final TextEditingController _amountController =
      TextEditingController(text: '2,00');
  final FocusNode _amountFocus = FocusNode();

  static const _presetAmounts = [2.0, 5.0, 10.0, 20.0];

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _heartScale = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _fetchPixKey();

    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) {
        _parseAmountFromController();
      }
    });
  }

  Future<void> _fetchPixKey() async {
    try {
      // Substitua pela URL do seu VPS/API
      // Exemplo: final response = await http.get(Uri.parse('https://api.jalide.com/pix'));
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    setState(() {
      _donationAmount = amount;
      _amountController.text = amount.toStringAsFixed(2).replaceAll('.', ',');
    });
  }

  void _parseAmountFromController() {
    final raw = _amountController.text.replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed != null && parsed > 0) {
      setState(() => _donationAmount = parsed);
    } else {
      _amountController.text =
          _donationAmount.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  String get _coffeeLabel {
    if (_donationAmount < 5) return 'um cafezinho ☕';
    if (_donationAmount < 10) return 'dois cafezinhos ☕☕';
    if (_donationAmount < 20) return 'um café especial ☕☕☕';
    return 'uma pizza pra gente! 🍕';
  }

  IconData get _coffeeIcon {
    if (_donationAmount < 20) return Icons.coffee;
    return Icons.local_pizza;
  }

  void _copyPix() {
    Clipboard.setData(ClipboardData(text: pixKey));
    final theme = ThemeProvider.of(context).current;
    final formattedValue =
        'R\$ ${_donationAmount.toStringAsFixed(2).replaceAll('.', ',')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.black, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chave Pix copiada! Valor sugerido: $formattedValue ❤️',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: IconButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                icon: const Icon(Icons.close, color: Colors.black, size: 18),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Fechar',
              ),
            ),
          ],
        ),
        backgroundColor: theme.accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.surface, width: 1),
        ),
        duration: const Duration(days: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPri),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),

                // Ícone animado
                ScaleTransition(
                  scale: _heartScale,
                  child: Icon(
                    _coffeeIcon,
                    size: 72,
                    color: theme.accent.withValues(alpha: 0.9),
                  ),
                ),

                const SizedBox(height: 20),

                // Título
                Text(
                  'Me pague um café? ☕',
                  style: TextStyle(
                    color: theme.textPri,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Descrição pessoal
                Text(
                  'Desenvolvo o JALIDE nas horas vagas para que você possa codar '
                  'de qualquer lugar com seu Android. Se ele te ajudou, '
                  'me pague $_coffeeLabel — isso faz toda a diferença! 🙏',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),

                const SizedBox(height: 32),

                // Label
                Text(
                  'ESCOLHA O VALOR',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),

                // Chips de valor rápido
                Wrap(
                  spacing: 10,
                  children: _presetAmounts.map((amount) {
                    final selected = (_donationAmount - amount).abs() < 0.01;
                    return GestureDetector(
                      onTap: () => _setAmount(amount),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? theme.accent : theme.surface,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: selected
                                ? theme.accent
                                : theme.accent.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'R\$ ${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: selected ? Colors.black : theme.textPri,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Campo de valor personalizado
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: TextStyle(
                      color: theme.textPri,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixText: 'R\$ ',
                      prefixStyle: TextStyle(
                        color: theme.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      hintText: '0,00',
                      hintStyle: TextStyle(color: theme.textMuted),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: theme.accent.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: theme.accent, width: 2),
                      ),
                    ),
                    onEditingComplete: () {
                      _parseAmountFromController();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'ou digite outro valor',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 36),

                // Card com chave Pix
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.accent.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pix, color: theme.accent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'CHAVE PIX',
                            style: TextStyle(
                              color: theme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_isLoading)
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.accent,
                          ),
                        )
                      else
                        SelectableText(
                          pixKey,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textPri,
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Botão copiar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _copyPix,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: Text(
                            'COPIAR CHAVE  —  R\$ ${_donationAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Cole no seu banco e confirme o valor acima ✅',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Muito obrigado pelo carinho! ❤️',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
