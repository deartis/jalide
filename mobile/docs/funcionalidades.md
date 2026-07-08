# Documentação de Funcionalidades — JALIDE 🚀

Esta documentação descreve em detalhes todas as funcionalidades do **JALIDE**, uma IDE móvel moderna e poderosa desenvolvida em Flutter para dispositivos Android. O documento aborda tanto a experiência do usuário final quanto os detalhes da arquitetura técnica interna do projeto.

---

## Índice
1. [Visão Geral e Arquitetura](#1-visão-geral-e-arquitetura)
2. [Editor Profissional & Abas](#2-editor-profissional--abas)
3. [Auto-Save e Gerenciamento de Histórico](#3-auto-save-e-gerenciamento-de-histórico)
4. [Teclado Auxiliar de Programação](#4-teclado-auxiliar-de-programação)
5. [Autocomplete e Sugestões por Idioma](#5-autocomplete-e-sugestões-por-idioma)
6. [Play Inteligente (Execução de Código)](#6-play-inteligente-execução-de-código)
7. [Terminal Híbrido (Local & SSH)](#7-terminal-híbrido-local--ssh)
8. [Integração Termux (Termux Magic)](#8-integração-termux-termux-magic)
9. [Árvore de Diretórios (VS Code Style) & SFTP](#9-árvore-de-diretórios-vs-code-style--sftp)
10. [Assistente IA & Ghost Suggestions (Google Gemma)](#10-assistente-ia--ghost-suggestions-google-gemma)
11. [Formatador Offline Integrado](#11-formatador-offline-integrado)
12. [Temas & Customizações](#12-temas--customizações)
13. [Resumo das Tecnologias e Dependências Principais](#13-resumo-das-tecnologias-e-dependências-principais)

---

### 1. Visão Geral e Arquitetura
O JALIDE é estruturado sob o ecossistema do Flutter e foi projetado seguindo padrões modernos de desenvolvimento para IDEs mobile-first:
- **[main.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/main.dart)**: Ponto de entrada do aplicativo. Inicializa os canais de comunicação para serviços em segundo plano (`SshForegroundService`) e carrega as preferências de tema do usuário.
- **[controllers/](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/controllers)**: Contém classes que gerenciam estados das abas abertas e persistência de sessão.
- **[services/](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/services)**: Serviços essenciais para operações de arquivos locais e remotos, comunicações SSH/SFTP e chamadas de modelos de Inteligência Artificial da API do Google Gemini.
- **[widgets/](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/widgets)**: Elementos modulares da interface, como terminal, chat de IA, teclado auxiliar e o menu lateral do explorador de arquivos.
- **[screens/](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/screens)**: Telas completas que agrupam os widgets, incluindo o painel principal do editor e a tela de conexão SSH.

---

### 2. Editor Profissional & Abas
O coração da IDE é o editor de código multilíngue, implementado sobre o pacote `flutter_code_editor`.
- **Destaques Técnicos**:
  - **Syntax Highlighting**: Integração com a biblioteca `highlight` para suporte a linguagens como Javascript, Dart, Python, CSS, JSON, XML/HTML, C/C++ e Markdown.
  - **Tabs Management**: Gerenciado pela classe [EditorTabController](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/controllers/editor_tab_controller.dart). Permite abrir múltiplos arquivos ao mesmo tempo, alternar entre abas ativas, reabrir a última aba visualizada e persistir a lista de abas abertas via `SharedPreferences`.
  - **Zoom Dinâmico**: Permite ajustar o tamanho da fonte diretamente com gestos de pinça (pinch-to-zoom) no editor.
  - **Seleção Inteligente**: Toques rápidos apenas posicionam o cursor, evitando que o menu padrão de seleção do Android apareça inoportunamente ao programar, o que é ativado apenas por toques longos.

---

### 3. Auto-Save e Gerenciamento de Histórico
Para evitar qualquer perda de trabalho em dispositivos móveis, o editor conta com salvamento automático e um histórico de desfazer/refazer inteligente.
- **Auto-Save Background**:
  - Salva silenciosamente o progresso do usuário no arquivo ativo utilizando um mecanismo de **debounce de 1.5s** (atraso para evitar gravações consecutivas a cada caractere digitado).
  - Também aciona o salvamento automático de forma síncrona no momento em que o usuário troca de aba no editor.
- **Histórico Personalizado (Undo/Redo)**:
  - Implementado na classe [EditorTabHistory](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/models/editor_tab.dart).
  - Funciona com uma pilha de histórico customizada (`_undoStack` e `_redoStack`) que limita o uso de memória a até 100 entradas.
  - Agrupa caracteres digitados sequencialmente através de um temporizador de 800ms antes de registrar uma nova alteração, o que evita que o "Undo" reverta apenas uma única letra por clique no celular.

---

### 4. Teclado Auxiliar de Programação
Facilita a digitação de códigos em telas pequenas reduzindo a dependência de trocar de layout no teclado nativo do Android.
- **Aba Nav (Navegação)**: Atalhos rápidos de movimentação de cursor (Tab, ↑, ↓, ←, →, ⌫, Esc, Home, End, Enter) e seleção de texto por teclado (Sel↑, Sel↓).
- **Aba Sym (Símbolos)**: Insere rapidamente caracteres especiais comuns em programação, como: `{ }`, `[ ]`, `( )`, `" "`, `' '`, `\``, `;`, `:`, `=`, `=>`, `->`, `**`, `//`, `/*`, `!=`, `==`, `&&`, `||`, `!`, `?`, `@`, `#`, `$`, `%`.
- **Aba Ctrl (Atalhos)**: Permite simular comandos clássicos do teclado físico como Ctrl+Z, Ctrl+Y, Ctrl+A, Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+S, Ctrl+F, Ctrl+G, Ctrl+D (duplicar linha) e movimentação de linhas (Alt+Up, Alt+Down).
- **Localização do Código**: Implementado em [aux_keyboard.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/widgets/aux_keyboard.dart).

---

### 5. Autocomplete e Sugestões por Idioma
Exibe sugestões de palavras-chave baseadas no contexto de cada linguagem, mudando automaticamente ao alternar o arquivo ativo.
- **Como Funciona**:
  - O utilitário `applyLanguageSuggestions` em [code_completion.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/utils/code_completion.dart) mapeia listas de palavras-chave para JS/TS, Dart, Python, C/C++, HTML/XML, CSS, Bash/Shell e Markdown.
  - Ele atualiza dinamicamente as sugestões no `CodeController.autocompleter` do editor assim que o arquivo é aberto ou a aba é alternada.

---

### 6. Play Inteligente (Execução de Código)
Disponibiliza um botão de play de execução direta no cabeçalho superior que roda o script atual diretamente no terminal de acordo com a sua linguagem.
- **Mapeamento de Comandos**:
  - **`.js` / `.mjs`**: `node "arquivo"`
  - **`.py` / `.pyw`**: `python "arquivo"`
  - **`.dart`**: `dart run "arquivo"`
  - **`.cpp` / `.cc`**: Compila e executa com `clang++ "arquivo" -o "saida" && "./saida"`
  - **`.c`**: Compila e executa com `clang "arquivo" -o "saida" && "./saida"`
  - **`.sh`**: `bash "arquivo"`
  - **`.html` / `.htm`**: Inicia um servidor web Python rápido com `python -m http.server 8000`
  - **Outros**: Executa `cat "arquivo"` para inspecionar conteúdo.
- **Localização do Código**: Método `_runActiveFile` em [editor_screen.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/screens/editor_screen.dart#L632-L727).

---

### 7. Terminal Híbrido (Local & SSH)
Uma janela de terminal interativa acoplável na parte inferior do editor que suporta dois modos de operação:
- **Modo Local (PTY)**:
  - Usa a biblioteca `flutter_pty` para iniciar um pseudo-terminal (PTY) diretamente no Android.
  - Tenta carregar o Bash do Termux (`/data/data/com.termux/files/usr/bin/bash`) se detectado, ou usa o shell padrão do Android `/system/bin/sh` como fallback.
- **Modo Remoto (SSH)**:
  - Permite interagir diretamente com um servidor remoto conectado usando a biblioteca `dartssh2` para transmitir fluxos de E/S (`stdin`, `stdout`, `stderr`).
  - **SshForegroundService**: Um serviço de primeiro plano (`Foreground Service` do Android) é iniciado ao conectar para garantir que a sessão de rede não seja interrompida pelo sistema operacional ao minimizar o aplicativo ou desligar a tela.
  - **Mecanismo de Health Check & Reconexão**: A classe [SshConnectionManager](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/services/ssh_connection_manager.dart) executa ping periódico (heartbeat) a cada 30 segundos e gerencia até 5 tentativas consecutivas de reconexão automática com backoff exponencial.

---

### 8. Integração Termux (Termux Magic)
O JALIDE possui integração nativa com o **Termux** no Android para permitir um ambiente de desenvolvimento Linux completo no próprio celular.
- **Funcionamento**:
  - No terminal do JALIDE, há um atalho representado por um **Raio Amarelo ⚡**.
  - Este atalho copia um script de setup de um clique para a área de transferência e abre o app Termux via intenção Android (`MethodChannel` `runTermuxCommand`).
  - O script automatiza a instalação dos pacotes necessários (Node.js, Git, SSH) e inicia o servidor SSH na porta `8022` padrão.

---

### 9. Árvore de Diretórios (VS Code Style) & SFTP
Permite explorar sistemas de arquivos locais e remotos a partir do menu lateral esquerdo da IDE.
- **Recursos da Árvore**:
  - **Expansão In-place**: Pastas são navegadas inline usando setas na lateral esquerda, recriando a experiência clássica de IDEs desktop.
  - **Cache Anti-Crash**: Utiliza cache otimizado no [file_explorer.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/widgets/file_explorer.dart) para carregar dados de diretórios apenas sob demanda, mitigando latência de rede no SSH/SFTP e evitando loops que causam travamentos de interface (ANR).
  - **Gerenciamento Completo**: Permite criar arquivos e pastas (resolvendo para o diretório pai selecionado), renomear e excluir itens com diálogos interativos de confirmação.
  - **Edição Remota (SFTP)**: Edição direta e transparente de arquivos no servidor SSH remoto. Ao abrir o arquivo, ele é baixado via SFTP, e o salvamento envia o arquivo de volta imediatamente.

---

### 10. Assistente IA & Ghost Suggestions (Google Gemma)
Integração com APIs de inteligência artificial generativa usando a biblioteca `google_generative_ai` (suportando modelos como `gemini-2.5-flash` e `gemini-2.5-pro`).
- **Painel de Chat**:
  - Permite conversar com um assistente contextual sobre o projeto.
  - Ao ser aberto, ele envia automaticamente o contexto e trecho do arquivo atualmente ativo para que a IA dê respostas precisas.
- **Ghost Suggestions (Sugestões Fantasma)**:
  - Analisa o código em segundo plano enquanto o usuário digita.
  - Quando a digitação é interrompida por **1.2 segundos** (debounce), envia o snippet pré-cursor para a API e exibe uma linha de sugestão cinza/fantasma diretamente acima do teclado auxiliar.
  - O usuário pode aceitar a sugestão inteira clicando nela ou apenas ignorá-la e continuar a digitação.
  - Código implementado em [ghost_suggestion_bar.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/widgets/ghost_suggestion_bar.dart).

---

### 11. Formatador Offline Integrado
Oferece limpeza e recuo estrutural de arquivos de código inteiramente em modo offline (sem consumir dados ou API de IA).
- **Tecnologia**:
  - Implementado em [code_formatter.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/mobile/lib/utils/code_formatter.dart).
  - Conta com analisador léxico simples que rastreia chaves `{}` e colchetes `[]` para aplicar recuos de dois espaços em linguagens baseadas em blocos (JS/Dart/C/C++).
  - Possui tratamento especializado para tags XML/HTML.
  - Pode ser configurado nas preferências para formatar automaticamente o arquivo sempre que for salvo (**Auto-Format on Save**).

---

### 12. Temas & Customizações
Suporte a customização visual de alta fidelidade para se adequar ao ambiente preferido do desenvolvedor.
- **Modelagem**:
  - Gerenciado por `ThemeProvider` em [jalide_theme.dart](file:///c:/Users/JAL/Documents/Projetos/jalide/theme/jalide_theme.dart) ou `mobile/lib/theme/jalide_theme.dart` (refeita a referência local no main.dart).
  - Possui temas predefinidos de alto contraste e esteticamente ricos (como Dracula Theme e Classic Orange).
  - Altera de forma coesa a paleta de cores do editor de código, barras laterais, teclado auxiliar, diálogos de sistema e terminal.

---

### 13. Resumo das Tecnologias e Dependências Principais
- **`flutter_code_editor` & `highlight`**: Usado para a renderização, formatação visual e realce de sintaxe do editor de código.
- **`dartssh2`**: Mecanismo que provê cliente SSH2 nativo no Dart e conexões seguras de arquivos por SFTP.
- **`xterm` & `flutter_pty`**: Exibição visual de terminal e criação de instâncias de terminal locais do sistema operacional.
- **`flutter_foreground_task`**: Permite rodar o Keep-Alive de conexões SSH como um Foreground Service do Android.
- **`google_generative_ai`**: Facilita a comunicação com as APIs do Gemini da Google para chat contextual e autocompletação.
- **`flutter_secure_storage`**: Armazenamento criptografado de credenciais SSH sensíveis e da chave API da IA.
