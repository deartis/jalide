# Melhorias de Usabilidade e Estabilidade — Julho de 2026

Este documento reúne e detalha as melhorias de usabilidade e estabilidade feitas no **JALIDE** em Julho de 2026.

---

## 1. Posicionamento Inteligente do Cursor pós-Formatação
**Problema:** Ao salvar o arquivo (com salvamento automático ativo) e disparar a formatação automática, o cursor perdia a referência relativa no texto e ficava "preso" no mesmo índice absoluto, o que o posicionava no meio do texto ou muito atrás da linha editada.
- **Solução:** Desenvolvemos o algoritmo `getFormattedOffset` em `CodeFormatter`. Ele calcula a posição relativa ideal do cursor (considerando recuos adicionados, tabs e remoção de espaços no fim da linha) para reposicionar o cursor e seleções ativas no local exato após a formatação de código.

---

## 2. Inicialização Automática do sshd no Termux
**Problema:** O Android suspende ou encerra processos em segundo plano (como o Termux com o serviço SSH) após algum tempo de inatividade. Ao voltar ao editor, a conexão SSH falhava e as reconexões automáticas falhavam consecutivamente porque o daemon `sshd` estava morto, exigindo que você reiniciasse o aplicativo do zero.
- **Solução:** O método `connect()` da sessão SSH foi configurado para que, sempre que o dispositivo for Android e o destino for local (`localhost` ou `127.0.0.1`), envie um comando nativo executando `pgrep sshd || sshd` no Termux. Um delay de 600ms garante tempo hábil para o daemon se restabelecer antes do socket ser criado.

---

## 3. Seleção Facilitada da Pasta Raiz no Explorador
**Problema:** Ao navegar por pastas filhas ou abrir um arquivo secundário, o explorer de arquivos bloqueava o fluxo em torno do último diretório selecionado. Não havia como "deselecionar" uma pasta para criar novos itens na raiz do projeto.
- **Solução:**
  - O cabeçalho do projeto no topo do Drawer lateral foi transformado em um botão clicável (`InkWell`). Tocar nele limpa a seleção ativa e redefine o diretório de destino de volta à raiz.
  - Adicionamos um realce visual sutil ao cabeçalho (borda fina e cor de destaque) quando a pasta raiz estiver ativa.
  - O diálogo de criação ("Novo arquivo" / "Nova pasta") agora exibe explicitamente onde o arquivo será criado (`Em: raiz`, `Em: src/components`), evitando surpresas.

---

## 4. Criação Rápida de Arquivos e Pastas no Long-press
**Problema:** Para criar um arquivo em uma pasta específica profunda, era necessário clicar nela, subir até o topo do Drawer e clicar nos botões de criação rápida.
- **Solução:** Adicionamos as opções **"Novo arquivo"** e **"Nova pasta"** diretamente no menu de contexto (exibido ao pressionar longamente - *long-press* - qualquer pasta no explorador). Ao clicar nelas, o diálogo é aberto apontando automaticamente para a pasta selecionada.

---

## 5. Botões de "Desconectar" e "Sair" na Notificação
**Problema:** Ao fechar a interface do app (limpar dos apps recentes), o isolate principal da UI era destruído, mas o Foreground Service continuava ativo para manter a sessão viva. Sem a UI principal ativa, o botão "Desconectar" na barra de notificação não funcionava (pois não havia listeners ativos), forçando o usuário a ir até as configurações do Android para fechar o app.
- **Solução:**
  - O botão **Desconectar** da notificação agora chama `stopService` no isolate em background de forma autônoma, fechando o serviço e removendo a notificação na hora.
  - Adicionado o botão **Sair** à notificação. Clicá-lo encerra o serviço e executa `exit(0)`, matando o processo inteiro do app instantaneamente, assim como no Termux.

---

## 6. Otimizações de Fluxo e Interface de Usuário (UI/UX)
**Problema:** Várias inconsistências de usabilidade geravam atritos no uso diário do aplicativo (como notificações que nunca sumiam, diálogos de abas incompletos e caminhos de arquivo muito longos poluindo a tela).
- **Solução:**
  - **Duração Inteligente de Toasts:** Toasts de sucesso ou informativos agora fecham sozinhos em 3 segundos, enquanto mensagens de erro permanecem por 6 segundos, eliminando a necessidade de fechá-los manualmente a todo momento.
  - **Ação "Salvar e Fechar":** Adicionamos a opção de salvar alterações diretamente ao fechar abas modificadas, evitando a necessidade de salvar manualmente antes de dispensar o editor.
  - **Caminho Relativo no Título:** O título da barra superior agora exibe o caminho simplificado relativo ao projeto (ex: `src/routes/auth.js`) em vez do caminho absoluto do sistema operacional.
  - **Menu de Opções Reorganizado:** Reestruturamos o menu principal em subseções agrupadas tematicamente (Arquivo, Editor, IA, Sessão e App), facilitando a localização de cada recurso.
  - **Área de Toque das Tabs Aumentada:** O botão de fechar tab (`×`) recebeu um preenchimento maior (padding), facilitando o fechamento em telas de toque menores.
  - **Indicador de Destino no Teclado Auxiliar:** Um indicador visual dinâmico no topo do teclado (`EDIT` ou `TERM`) mostra claramente se as teclas inseridas vão para o editor ou para o terminal ativo.
  - **Visualizador de Temas Modernizado:** A seleção de temas agora exibe cards de pré-visualização contendo a paleta de cores correspondente a cada variante (Dracula, Dark, Dark Purple e Light).
  - **Prevenção de Erros durante Build do Explorer**: Corrigimos o erro de reconstrução concorrente (`setState() during build`) no gerenciador de diretórios usando inicialização diferida por frames.
  - **Ícones Expandidos no Explorer:** Adicionamos suporte a dezenas de novas extensões de arquivo com ícones e cores dedicadas (Python, Dart, TypeScript, Rust, Go, C/C++, Shell scripts, YAML, XML, Git, etc.).

