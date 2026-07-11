# JALIDE Mobile IDE 🚀

**Transforme seu Android em uma estação de desenvolvimento completa.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Em%20desenvolvimento-orange?style=flat-square)]()

<p align="center">
  <img src="img/dracula_editor.png" width="30%" alt="JALIDE Dracula Theme" />
  <img src="img/classic_editor.png" width="30%" alt="JALIDE Classic Orange" />
  <img src="img/remote_explorer.png" width="30%" alt="JALIDE Remote File Explorer" />
</p>

---

## Sobre

JALIDE é uma IDE móvel moderna e poderosa desenvolvida em Flutter, com suporte **multi-linguagem** (JavaScript, Python, Dart, C, C++ e Shell Script). Ela foi projetada para transformar seu Android em um ambiente de desenvolvimento robusto, ideal para quando você está em trânsito ou tem apenas o celular à mão — sem abrir mão de produtividade e recursos avançados.

📖 **Consulte a [Documentação de Funcionalidades](docs/funcionalidades.md) para saber mais sobre a arquitetura técnica e detalhes de uso.**

🛠️ **Confira o histórico completo de [Melhorias de Usabilidade e Estabilidade](docs/melhorias_usabilidade.md) (Julho de 2026).**


---

## ✨ Funcionalidades

> [!NOTE]
> Para uma análise técnica detalhada da arquitetura e comportamento de cada recurso, consulte a **[Documentação de Funcionalidades](docs/funcionalidades.md)**.


| | Funcionalidade | Descrição |
|---|---|---|
| 📝 | **Editor profissional** | Syntax highlighting, zoom dinâmico e múltiplas abas |
| 🤖 | **Autocomplete por linguagem** | Sugestões inteligentes como VSCode (JS, Python, Dart, C++, etc.) — muda conforme você abre arquivos |
| ▶️ | **Play Inteligente** | Botão de execução direta na barra superior que roda códigos com um toque (Node, Python, Dart, C/C++, Bash) |
| 💾 | **Auto-Save Background** | Salvamento automático silencioso (com debounce de 1.5s) e ao trocar de abas no editor |
| 🐚 | **Terminal híbrido** | Alterne entre terminal local (Android) e remoto via SSH |
| ⚡ | **Termux Magic** | Configura Node.js + SSH no Termux com um clique |
| 📂 | **Árvore de Pastas & SFTP** | Árvore de diretórios estilo VS Code (expansão in-place), cache anti-crash e edição remota via SFTP |
| 🔐 | **Gestor de perfis SSH (melhorado)** | Credenciais seguras, testar conexão, indicador de status (ONLINE/OFFLINE), desconectar com um clique |
| 🎹 | **Teclado auxiliar** | Atalhos `{}` `[]` `=>` otimizados para telas pequenas |

---

## 🎯 O que há de novo (v1.1.0) - Julho de 2026

### 🧹 Formatação Inteligente & Cursor Inteligente
- **Preservação de Foco do Cursor** — O cursor e as seleções ativas no editor agora acompanham as mudanças de recuo e formatação de código (`CodeFormatter.getFormattedOffset`), sem saltar de linha ou perder o foco do código.

### 📱 Estabilidade com Termux Background
- **Auto-Wake do sshd** — O app agora acorda o Termux e garante que o daemon `sshd` está ativo em qualquer tentativa de conexão local, prevenindo falhas de conexão caso o Android encerre processos em background.

### 📂 Painel de Arquivos Refinado
- **Seleção e Criação no Diretório Raiz** — O cabeçalho do projeto no topo do Drawer lateral agora serve para limpar seleções internas e focar na raiz (com realce de destaque ativo). Além disso, a pasta de destino é indicada no diálogo de criação (`Em: raiz`, etc.).
- **Ações Rápidas no Long-press** — Criação de arquivos e pastas disponível diretamente no menu contextual ao segurar qualquer pasta.

### 🔐 Botão "Sair" e Parada de Serviço Autônoma
- **Notificação Otimizada** — O botão "Desconectar" na notificação funciona independentemente do isolate principal estar ativo. Adicionado também o botão **Sair** para matar o processo por completo instantaneamente.

---

## 🎯 Na versão anterior (v1.0.1)

### 📄 Nova Documentação Oficial
- **Arquitetura & Recursos Detalhados** — Lançamento do guia técnico e manual do usuário completo em `docs/funcionalidades.md`, detalhando o fluxo de abas, atalhos, SSH e IA.

### 🔐 Conexão SSH mais Estável e Resiliente
- **Monitoramento por Heartbeat** — Envio automático de pings a cada 30 segundos para manter o canal ativo.
- **Reconexão Inteligente** — Tentativa automática de reconexão de até 5 vezes com atraso incremental (backoff exponencial) para redes móveis instáveis.

---

## 🎯 Na versão anterior (v0.1.0+6)

### 📂 Árvore de Diretórios Estilo VS Code
- **Expansão In-place com Seta na Esquerda** — Pastas do explorador agora contam com setinhas de expansão no lado esquerdo. Você pode clicar e expandir estruturas profundas sem sair da raiz atual do projeto.
- **Cache Anti-Crash (Sem Conflito SSH)** — Implementado cache inteligente de leitura de pastas. Isso evita loops de carregamento redundantes no Drawer durante a digitação e elimina travamentos (ANRs) em conexões SSH remotas.
- **Destaque e Criação de Arquivos Contextual** — O arquivo ou pasta selecionada é destacado visualmente. A criação de novos arquivos/pastas resolve automaticamente para o diretório pai do arquivo selecionado.
- **Opção de Navegar Raiz** — Pressione e segure qualquer pasta (long-press) e selecione "Navegar" para redefinir aquela pasta como a raiz atual do explorador.

### 🤖 Integração com IA (Google Gemma)
- **Assistente IA Gratuito** — Tire dúvidas, peça sugestões ou gere códigos conversando com a IA usando a Chave de API do Google AI Studio.
- **Sugestões Contextuais (Ghost Suggestions)** — IA analisando seu código em tempo real e oferecendo sugestões (ativável nas configurações).
- **Sem Limites Ocultos** — O aplicativo conecta diretamente ao seu provedor, então não há custos ou taxas escondidas!

### 🧹 Auto-Format Offline
- **Formatação de Código Sem IA** — Mantendo a essência do "máximo grátis", implementamos um formatador embutido para limpar recuos e espaços.
- **Auto-Format on Save** — Opção para formatar o código magicamente toda vez que você salvar.

### 📱 Experiência Mobile Melhorada
- **Seleção de Texto Inteligente** — Corrigido o comportamento do toque; agora toques curtos apenas movem o cursor, evitando menus de seleção indesejados. Segure o dedo para ativar a seleção de texto.

---

## 🎯 Na versão anterior (v0.1.0+5)
- Todos os recursos de Auto-Format, IA (Google Gemma), melhoria de Seleção de Texto e estabilização móvel.

## 🎯 Na versão anterior (v0.1.0+4)

### 🚀 Autocomplete Inteligente
- **Digite e veja:** Conforme você digita, sugestões relevantes aparecem (como no VSCode).

### 🔐 SSH Melhorado
- **Testar conexão** — Botão para verificar se o servidor está respondendo antes de trabalhar.
- **Status em tempo real** — Indicador `🟢 ONLINE` ou `🔴 OFFLINE` próximo a cada perfil salvo.
- **Desconectar com 1 clique** — Encerra a sessão SSH quando terminar (libera recursos).
- **Memory-safe** — Sem memory leaks ao deletar perfis ou desconectar.

---

Para usar o potencial máximo (Node.js, NPM, Git), integre o JALIDE ao **[Termux](https://termux.dev)**.

### ⚡ Passo 1 — Termux Magic (jeito fácil)

1. Abra o JALIDE e toque no ícone de **terminal** no rodapé.
2. No painel do terminal, toque no ícone de **Raio Amarelo ⚡**.
3. Toque em **"COPIAR E ABRIR TERMUX"**.
4. No Termux, **cole o comando** e dê Enter — ele instala o Node.js e o servidor SSH automaticamente.
5. Defina uma senha com `passwd` e anote seu usuário com `whoami`.

> **⚠️ Guarde** seu usuário e senha — você vai precisar deles no próximo passo.

---

### 🔌 Passo 2 — Conectar via SSH

1. No JALIDE, toque em **⋮** (menu superior) → **SSH Remote**.
2. Toque em **(+)** para adicionar um novo perfil:

   | Campo | Valor |
   |---|---|
   | Host | `localhost` |
   | Porta | `8022` |
   | Usuário | resultado do `whoami` |
   | Senha | definida no `passwd` |

3. Salve e toque em **Conectar**. ✅

---

## 📂 Editando Arquivos Remotamente (SFTP)

O JALIDE oferece um **file explorer remoto completo**, não apenas um terminal:

- **Conectar** → o explorer abre automaticamente na pasta `home` do servidor remoto.
- **Abrir** → toque em qualquer arquivo para carregá-lo no editor.
- **Salvar** → `Ctrl+S` faz o upload via SFTP instantaneamente.
- **Persistência** → feche o terminal para ganhar espaço na tela; a sessão SSH continua ativa em segundo plano.

---

## 🤝 Como Contribuir

JALIDE é **100% open-source**. Issues, sugestões e PRs são muito bem-vindos!

```bash
# 1. Fork o repositório e clone
git clone https://github.com/seu-usuario/jalide.git

# 2. Crie sua branch
git checkout -b minha-feature

# 3. Commit suas mudanças
git commit -m 'feat: minha contribuição'

# 4. Push e abra um Pull Request
git push origin minha-feature
```

---

## 💖 Apoie o Projeto

Se o JALIDE te ajuda a programar, considere apoiar o projeto com uma estrela ⭐ no repositório ou fazendo uma contribuição voluntária via PIX direto pelo aplicativo!

Chave PIX do projeto:
`40dccccc-04fa-4c63-959d-f671794d5f27`

---

## 📝 Licença

Distribuído sob a licença **MIT**. Veja [`LICENSE`](LICENSE) para mais informações.

---

*Desenvolvido com ❤️ para a comunidade de desenvolvedores mobile.*
