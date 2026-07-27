# 🚀 JALIDE v1.0.3 - Editor Profissional & Ferramentas de Produtividade 🎉

A **v1.0.3** traz uma grande evolução no editor de código e na produtividade do desenvolvedor. Com **10 novas funcionalidades**, o JALIDE agora se aproxima de IDEs desktop — tudo diretamente do seu Android.

---

## ✨ Novidades da v1.0.3

### 📝 1. Editor com Destaque de Sintaxe para 19 Linguagens (Expandido)
* **De 8 para 19 linguagens**: JavaScript, TypeScript, Python, Dart, C, C++, Java, Go, Rust, Kotlin, Ruby, PHP, C#, SQL, YAML, HTML, CSS, JSON, Markdown e Bash/Shell.
* Highlighting baseado na lib `highlight`, com suporte completo a keywords, strings, comentários e literais para cada linguagem.

### 🔍 2. Buscar e Substituir (Ctrl+F)
* **Barra de busca completa** com campo de texto, botões de navegação (próximo/anterior), contador de matches e toggle de case sensitive.
* **Substituição individual** ou **substituir tudo** — com highlighting visual nas linhas que contêm o termo buscado.
* Acessível via atalho `Ctrl+F` no teclado auxiliar ou pelo Command Palette.

### 🔢 3. Ir para Linha (Ctrl+G)
* **Navegação rápida** para qualquer linha do arquivo. Digite o número da linha e o cursor pula instantaneamente para lá.
* Mostra o total de linhas do arquivo atual como referência.

### 💬 4. Comentar/Descomentar Linha (Ctrl+/)
* **Comentário inteligente por linguagem**: detecta a linguagem do arquivo e usa o prefixo correto (`//` para C/Java/JS, `#` para Python/Bash, `<!--` para HTML/XML, `--` para SQL).
* Funciona com seleção múltipla — comenta ou descomenta todas as linhas selecionadas de uma vez.

### 🎯 5. Command Palette (Ctrl+Shift+P)
* **Paleta de comandos pesquisável** — pressione `⊞` no teclado auxiliar ou use o atalho para acessar.
* **22 comandos disponíveis** organizados por categoria: Arquivo, Editor, Visualização, Configurações e Remoto.
* Busca em tempo real enquanto você digita — encontre qualquer funcionalidade em segundos.

### 📂 6. Busca no Explorador de Arquivos
* **Campo de filtro** no cabeçalho do drawer de arquivos — digite o nome e o explorer filtra em tempo real.
* Limpe o filtro com um toque no botão ✕ para voltar à visualização completa.

### 🔀 7. Integração com Git
* **Painel Git completo** acessível pelo ícone de commit na barra superior.
* **Aba Arquivos**: visualiza status (modificado, novo, deletado), stage/unstage de arquivos individuais.
* **Aba Log**: histórico de commits com hash, mensagem e data.
* **Commit direto**: digite a mensagem e confirme — o commit é feito via `git commit`.

### 🎯 8. Multi-Cursor (Ctrl+D)
* **Selecionar próxima ocorrência**: selecione uma palavra e pressione `Ctrl+D` para selecionar a próxima ocorrência igual — edite todas de uma vez.
* **Duplicar linha**: quando nada estiver selecionado, `Ctrl+D` duplica a linha atual (comportamento padrão).

### ⬆️⬇️ 9. Mover Linha para Cima/Baixo (Ctrl+↑/↓)
* **Reordene linhas** sem copiar/colar — selecione ou posicione o cursor na linha e use `Ctrl+↑` para mover para cima ou `Ctrl+↓` para mover para baixo.
* A seleção acompanha o movimento da linha.

### ⌨️ 10. Teclado Auxiliar Expandido
* **Camada Normal**: novos botões de `🔍` (buscar), `//` (comentar) e `⊞` (command palette).
* **Camada Ctrl**: novos atalhos `↑ (Mover)` e `↓ (Mover)` para reordenação de linhas.
* Mais de **25 símbolos** na camada de símbolos: `{}`, `[]`, `()`, `=>`, `->`, `!=`, `>=`, `<=`, entre outros.

---

## 🔧 Correções e Melhorias

### 🖱️ 1. Scroll Horizontal Automático
* **Auto-scroll ao início da linha**: quando o cursor pula para o início de uma linha (após quebra de linha `\n`), o editor rola horizontalmente automaticamente para mostrar a coluna 0.
* Corrigido comportamento onde o cursor ficava "oculto" fora da área visível do editor.

### 📱 2. Estabilidade Geral
* Correções de memory leaks no gerenciamento de abas.
* Otimização no carregamento de arquivos grandes.
* Melhoria na responsividade do teclado auxiliar.

---

## 📊 Resumo de Atalhos

| Atalho | Ação |
|--------|------|
| `Ctrl+F` | Buscar e Substituir |
| `Ctrl+G` | Ir para Linha |
| `Ctrl+/` | Comentar/Descomentar |
| `Ctrl+D` | Multi-Cursor / Duplicar Linha |
| `Ctrl+↑` | Mover Linha para Cima |
| `Ctrl+↓` | Mover Linha para Baixo |
| `Ctrl+Shift+P` | Command Palette |
| `⊞` | Command Palette (teclado auxiliar) |
| `🔍` | Buscar e Substituir (teclado auxiliar) |
| `//` | Comentar Linha (teclado auxiliar) |

---

## 📲 Como Instalar

1. Baixe o arquivo **`JALIDE-v1.0.3.apk`** listado nos Assets do release.
2. No seu Android, permita a instalação de aplicativos de fontes desconhecidas (se solicitado).
3. Instale o APK e abra o JALIDE!

---

## 💖 Apoie o Desenvolvimento

Se o **JALIDE** te ajuda a programar ou salvar o dia fora do computador, considere apoiar o projeto com uma estrela ⭐ no repositório ou fazendo uma contribuição voluntária no painel de doações dentro do próprio aplicativo!

A chave PIX padrão do projeto é:
`40dccccc-04fa-4c63-959d-f671794d5f27`

---

*Desenvolvido com 💜 em Flutter.*