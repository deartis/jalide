import 'package:flutter/material.dart';
import 'package:jalide/theme/jalide_theme.dart';
import 'package:jalide/screens/donation_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context).current;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        title: Text('Sobre', style: TextStyle(color: theme.textPri)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPri),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Icon(Icons.code, size: 50, color: theme.accent),
              ),
              const SizedBox(height: 24),
              Text(
                'JAL IDE',
                style: TextStyle(
                  color: theme.textPri,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v0.1.0+5',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Um editor de código nativo, leve e poderoso para Android.\n'
                'Desenvolvido com o objetivo de entregar a melhor experiência '
                'de programação direto do seu celular.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textPri, height: 1.5, fontSize: 16),
              ),
              const SizedBox(height: 48),
              Text(
                'Gostou do projeto?',
                style: TextStyle(color: theme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DonationScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AA2F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.favorite, size: 20),
                label: const Text('Apoiar o Projeto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
