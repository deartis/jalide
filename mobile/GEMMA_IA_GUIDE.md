# 🤖 Gemma IA Integrada no JALIDE

## ✅ Configuração Concluída!

A IA Gemma já está configurada e pronta para usar no seu JALIDE com a chave fornecida.

---

## 🚀 Como Usar

### 1. **Botão de IA na Barra Superior**
- Clique no ícone de **lâmpada (💡)** na AppBar
- Isso abre o **Assistente Gemma** com o código da aba atual

### 2. **Abas do Assistente**

#### 📊 **Análise**
- Analisa o código
- Sugere melhorias de performance, segurança e boas práticas
- Mostrar exemplo corrigido se relevante

#### 📚 **Explicar**
- Explica trechos de código de forma clara
- Respostas concisas (máx 3 linhas)

#### 📝 **Documentação**
- Gera JSDoc/Dart Doc automático
- Perfeito para documentar funções e métodos

#### 💬 **Chat**
- Chat livre com Gemma
- Faça qualquer pergunta relacionada a código
- Peça dicas de desenvolvimento

---

## ⚙️ Configurações

### **Menu > Config. Gemma IA**
Permite:
- ✏️ Atualizar a chave API
- 🗑️ Remover a chave (se precisar mudar)

---

## 💾 Dados Sensíveis

✅ Sua chave API é armazenada de forma segura usando `flutter_secure_storage`
- Criptografada no dispositivo
- Não é perdida ao fechar o app
- Pode ser removida a qualquer momento

---

## 📊 Limites (Tier Grátis)

- ✅ **60 requisições/minuto**
- ✅ **Sem custo**
- ✅ **Sem limites de usos** (dentro do rate limit)

---

## 🎯 Casos de Uso Recomendados

| Caso | Aba | Exemplo |
|------|-----|---------|
| **Entender um algoritmo** | 📚 Explicar | Selecione um trecho complexo |
| **Melhorar código** | 📊 Análise | Cole um bloco de código |
| **Documentar função** | 📝 Documentação | Cole a assinatura da função |
| **Dúvida geral** | 💬 Chat | "Como fazer X em Dart?" |

---

## 🔧 Ficheiro Técnico

### **Arquivos Criados/Modificados:**

1. ✅ `pubspec.yaml` - Adicionada dependency `google_generative_ai`
2. ✅ `lib/services/ai_service.dart` - Serviço de IA (Singleton)
3. ✅ `lib/widgets/ai_dialog.dart` - Interface do Assistente
4. ✅ `lib/widgets/ai_settings_dialog.dart` - Configurações de IA
5. ✅ `lib/screens/editor_screen.dart` - Integração no editor

### **Método Singleton do AIService**
```dart
final aiService = AIService();
await aiService.initialize(apiKey: 'sua-chave');

// Usar:
String analise = await aiService.analyzeCode(code);
String explicacao = await aiService.explainCode(code);
String doc = await aiService.generateDocumentation(code);
```

---

## ⚡ Próximos Passos (Opcional)

1. **Context Menu** - Clique direito no editor para rápido acesso
2. **Atalhos de Teclado** - Ctrl+Alt+A para abrir IA
3. **Histórico** - Salvar conversas anteriores
4. **Temas Customizados** - Diferentes modos de análise

---

## 🐛 Troubleshooting

### "Erro ao conectar com a IA"
- Verifique sua conexão com internet
- Confirme que a chave API é válida
- Verifique se não excedeu o rate limit (60 req/min)

### "Chave não salva"
- Vá em Menu > Config. Gemma IA
- Verifique se a chave foi colada corretamente

### "Chave expirou"
- Gere uma nova em [ai.google.dev](https://ai.google.dev)
- Atualize em Menu > Config. Gemma IA

---

## 📞 Suporte

- 📖 Docs Gemma: https://ai.google.dev/docs
- 🐙 Google Generative AI Dart: https://pub.dev/packages/google_generative_ai

**Aproveite a IA no seu JALIDE! 🚀💡**
