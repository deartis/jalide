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

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _heartScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _fetchPixKey();
  }

  Future<void> _fetchPixKey() async {
    try {
      // Substitua pela URL do seu VPS/API
      // Exemplo: final response = await http.get(Uri.parse('https://api.jalide.com/pix'));
      // final response = await http.get(Uri.parse('SUA_URL_DA_VPS_AQUI'));

      // Simulação de delay de rede
      await Future.delayed(const Duration(seconds: 1));

      /* 
      if (response.statusCode == 200) {
        setState(() {
          pixKey = response.body.trim();
          _isLoading = false;
        });
      }
      */
      setState(() => _isLoading = false);
    } catch (e) {
      // Se falhar, mantém a chave local
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _copyPix() {
    Clipboard.setData(ClipboardData(text: pixKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chave PIX copiada com sucesso! ❤️'),
        backgroundColor: ThemeProvider.of(context).current.accent,
        behavior: SnackBarBehavior.floating,
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              ScaleTransition(
                scale: _heartScale,
                child: Icon(
                  Icons.favorite,
                  size: 80,
                  color: Colors.redAccent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Apoie o JALIDE',
                style: TextStyle(
                  color: theme.textPri,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'O JALIDE é um projeto open-source feito com dedicação para transformar o desenvolvimento mobile. Se este app te ajuda, considere fazer uma doação de qualquer valor para apoiar o servidor e novas funcionalidades!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Chave PIX',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      Text(
                        pixKey,
                        style: TextStyle(
                          color: theme.textPri,
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _copyPix,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text(
                        'COPIAR CHAVE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Obrigado pelo carinho! ❤️',
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
    );
  }
}
