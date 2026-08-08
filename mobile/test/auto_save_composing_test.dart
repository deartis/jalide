import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auto-Save & IME Composing Protection Tests', () {
    test('Detecta corretamente se o editor está no meio de uma composição de texto (IME)', () {
      final valueSemComposicao = TextEditingValue(
        text: 'import {findById, findBiEmail} from "repository.js"',
        selection: const TextSelection.collapsed(offset: 24),
        composing: TextRange.empty,
      );

      final isComposingSem = valueSemComposicao.composing.isValid &&
          !valueSemComposicao.composing.isCollapsed;
      expect(isComposingSem, isFalse);

      final valueEmComposicao = TextEditingValue(
        text: 'import {findById, findBiEmail} from "repository.js"',
        selection: const TextSelection.collapsed(offset: 24),
        composing: const TextRange(start: 18, end: 29),
      );

      final isComposingCom = valueEmComposicao.composing.isValid &&
          !valueEmComposicao.composing.isCollapsed;
      expect(isComposingCom, isTrue);
    });

    test('Re-atribuir TextEditingValue com composing: TextRange.empty desativa a faixa de composição estagnada', () {
      final valOriginal = TextEditingValue(
        text: 'import {findById, findBEmail} from "repository.js"',
        selection: const TextSelection.collapsed(offset: 23),
        composing: const TextRange(start: 18, end: 28),
      );

      final valFormatado = valOriginal.copyWith(
        text: 'import { findById, findBEmail } from "repository.js"',
        selection: const TextSelection.collapsed(offset: 25),
        composing: TextRange.empty,
      );

      expect(valFormatado.composing, equals(TextRange.empty));
      expect(valFormatado.text, contains('findBEmail'));
    });
  });
}
