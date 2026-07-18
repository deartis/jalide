# JAL IDE — Roadmap de Melhorias de IA

> Gerado em 18/07/2026. Melhorias já implementadas até esta data não estão listadas aqui.

---

## 🔴 Alto Impacto

### Múltiplos arquivos no contexto
Hoje só o arquivo ativo vai pro system prompt. Permitir o usuário marcar quais abas quer incluir na conversa (ex: checkbox nas abas abertas) mudaria muito a qualidade das respostas para problemas que envolvem mais de um arquivo.

**Como implementar:** Adicionar um seletor de arquivos no header do `AIChatPanel`. Passar a lista selecionada para `startChatWithContext`.

---

### RAG local do projeto
Em vez de mandar o arquivo inteiro truncado em 6000 chars, indexar os arquivos do projeto com embeddings e recuperar só os trechos relevantes para cada pergunta.

**Como implementar:** Usar a API de embeddings do Gemini (`text-embedding-004`) para indexar os arquivos. Guardar os vetores em SQLite local. Na hora de enviar uma mensagem, recuperar os top-K trechos mais similares e injetar no prompt.

---

### "Perguntar sobre seleção"
O usuário seleciona um bloco de código no editor → segura → botão "Perguntar à IA" aparece no menu de contexto. Muito mais preciso do que mandar o arquivo inteiro.

**Como implementar:** Ouvir `controller.selection` no `EditorScreen`. Quando há seleção, mostrar um botão flutuante que abre o `AIChatPanel` com o trecho selecionado já no prompt.

---

## 🟡 Médio Impacto

### Múltiplas conversas salvas
Hoje existe só uma conversa global. Poder ter conversas separadas por projeto/contexto com título gerado automaticamente pela IA.

**Como implementar:** Criar um modelo `ChatSession { id, title, messages, createdAt }`. Persistir em `SharedPreferences` como lista de JSONs. Adicionar tela de histórico de sessões acessível pelo header do painel.

---

### Diff review (Git)
Botão "Revisar meu último commit" que pega o `git diff HEAD` via terminal e manda pra IA analisar. Integra com o terminal SSH que já existe no app.

**Como implementar:** Executar `git diff HEAD` via `SshService.execute()` ou terminal local. Passar o output como contexto para `sendMessage`.

---

### Temperatura configurável pelo usuário
O `_chatConfig` no `AIService` está hardcoded em `temperature: 0.7`. Um slider nas configurações permitiria controlar criatividade vs. precisão.

**Como implementar:** Adicionar `_temperature` no `AIService`, salvar em `SharedPreferences`, expor no `AISettingsDialog` com um `Slider` de 0.0 a 1.0.

---

### Streaming com syntax highlight em tempo real
Hoje o highlight de código fica sem cor durante o streaming (porque o `MarkdownBody` recebe texto incompleto). A resposta só fica bonita no `onDone`.

**Como implementar:** Detectar quando o chunk atual está fora de um bloco de código e renderizar o texto normal em streaming. Congelar a renderização do bloco de código até o ``` de fechamento aparecer.

---

## 🟢 Qualidade de Vida

### Busca no histórico
Campo de busca no topo do chat para encontrar uma resposta antiga na sessão atual.

**Como implementar:** `TextField` + filtro sobre `_messages` por substring. Highlight do termo encontrado.

---

### Compartilhar resposta
Botão para compartilhar o texto da resposta via `Share.share()` — útil para mandar uma solução pelo WhatsApp/Telegram sem sair do app.

**Como implementar:** Adicionar pacote `share_plus`. Botão extra em `_AIBubble._buildActions()`.

---

### Estimativa de tokens
Mostrar no header algo como `~2.4k tokens` para o usuário saber o quanto está consumindo de context window — especialmente útil com Gemini 2.5 Pro.

**Como implementar:** Contar caracteres do histórico e dividir por 4 (estimativa grosseira de chars/token). Exibir ao lado do contador de mensagens.

---

### Entrada por voz
Botão de microfone no input bar usando o pacote `speech_to_text`. Em mobile faz muito sentido — digitar código no celular é lento.

**Como implementar:** Adicionar `speech_to_text` no `pubspec.yaml`. Botão de microfone no `_buildInputBar` que transcreve e preenche o `_inputController`.

---

## 🔵 Avançado / Longo Prazo

### Agente de edição autônoma
A IA não só sugere, mas aplica as alterações diretamente no arquivo após confirmação do usuário — tipo Cursor AI. O usuário vê um diff antes de aceitar.

**Como implementar:** Pedir para a IA responder em formato estruturado (JSON com `file`, `operation`, `content`). Implementar um parser de diff/patch. Mostrar preview antes de aplicar.

---

### Suporte a múltiplos providers de IA
Hoje o código está acoplado ao SDK do Gemini. Uma interface `AIProvider` abstrata permitiria plugar OpenAI, Anthropic Claude, Mistral, etc.

**Como implementar:**
```dart
abstract class AIProvider {
  Stream<String> sendMessage(String message);
  Future<void> startChatWithContext({...});
  Future<String> generateCompletion(String prompt);
}

class GeminiProvider implements AIProvider { ... }
class OpenAIProvider implements AIProvider { ... }
```
O `AIService` passa a ser um wrapper que delega ao provider selecionado.

---

### Modelo local via Ollama + SSH
Como o app já tem SSH, daria para conectar num servidor com Ollama rodando e usar modelos locais (Llama 3, Mistral, CodeGemma) sem custo de API — privacidade total do código.

**Como implementar:** Implementar `OllamaProvider` que chama `http://localhost:11434/api/chat` via SSH port forwarding. O usuário configura o host e modelo nas configurações.

---

## Implementações já feitas ✅

- Persistência do histórico entre sessões (memória + disco)
- Botão cancelar stream com timeout de 60s
- Comandos rápidos via `/` (explain, refactor, test, fix, doc)
- Inserir código diretamente no cursor do editor
- Contexto dinâmico ao trocar de arquivo (sem resetar conversa)
- Ghost suggestions com contexto bidirecional (600 chars pré + 200 pós cursor)
- Contador de mensagens na sessão
