# 🚀 JALIDE v1.0.0 - IDE Mobile Multilinguagem 🎉

Transforme o seu dispositivo Android em uma estação de desenvolvimento completa e profissional! Chegamos à **versão oficial 1.0.0**! O **JALIDE** agora é uma solução estável e pronta para produção, trazendo recursos avançados de conectividade em segundo plano, restauração de workspace inteligente, inteligência artificial integrada e melhorias gigantescas de usabilidade para quem programa diretamente pelo celular.

---

## ✨ Recursos Principais & Novidades da v1.0.0

### 🔌 1. Conectividade SSH Persistente em Background (Novo)
* **Foreground Service de Rede**: Implementamos um serviço persistente nativo do Android. O terminal SSH e a comunicação SFTP não caem mais quando o aplicativo vai para segundo plano ou o celular desliga a tela.
* **Heartbeat de Keep-Alive**: Envio automático de pacotes de heartbeat a cada 30 segundos para manter os túneis de conexão ativos e evitar desconexões por inatividade.

### 📲 2. Restauração de Workspace & Reconexão Silenciosa (Novo)
* **Reconexão Automática**: Ao abrir o JALIDE, ele se reconecta silenciosamente à última sessão SSH bem-sucedida.
* **Persistência de Abas**: Seu progresso de desenvolvimento é mantido! As abas de arquivos locais ou remotos que estavam abertas são restauradas exatamente de onde você parou.

### ⌨️ 3. Histórico de Edição (Undo/Redo) Customizado por Aba (Novo)
* **Pilha de Undo/Redo Independente**: As teclas `Ctrl+Z` (Undo) e `Ctrl+Y` (Redo) do teclado auxiliar agora funcionam nativamente no celular, mantendo pilhas de alterações separadas para cada arquivo.
* **Debounce Inteligente**: Edições de digitação contínua são agrupadas para evitar gravação letra por letra, mas ações como quebras de linha (`Enter`), espaços, recortes, colagens e formatações salvam o estado de forma instantânea.

### 🤖 4. Integração com Inteligência Artificial (Google Gemma)
* **Assistente de IA Gratuito**: Uma aba de chat inteligente para tirar dúvidas de código, pedir otimizações e gerar trechos conversando diretamente com a IA do Google (Gemma). Basta configurar a sua chave de API gratuita do Google AI Studio.
* **Sugestões Contextuais (Ghost Suggestions)**: A IA agora analisa seu código ativamente em segundo plano e oferece sugestões úteis diretamente na interface enquanto você digita (pode ser ativado/desativado nas opções).

### 🧹 5. Auto-Format Offline & Formatação Inteligente
* **Formatador Nativo Veloz**: Ajuste recuos, alinhamento de chaves e espaçamentos instantaneamente, sem precisar de internet.
* **Auto-Format ao Salvar**: Escolha formatar o arquivo de forma automática toda vez que pressionar salvar (`Ctrl+S`).

### 📱 6. Ajustes de Usabilidade no Teclado e Toque
* **Teclas Auxiliares Corrigidas (TAB & ESC)**: Resolvemos o comportamento da tecla `TAB` (que antes tinha seus espaços removidos pelo formatador de atalhos) e da tecla `ESC` (que agora desfoca o editor e recolhe o teclado do sistema de forma limpa).
* **Fim dos Menus Acidentais**: Toques rápidos no editor apenas posicionam o cursor. O menu nativo de seleção/copiar/colar agora só abre com toques longos (long press), oferecendo muito mais fluidez ao navegar pelo código.

---

## 🛠️ Correções e Estabilidade
* Ajuste no ciclo de vida de memória e descarte de recursos de abas fechadas.
* Correção de erros na árvore de navegação do file explorer remota.
* Otimização no carregamento de perfis de SSH criptografados.

---

## 📲 Como Instalar

1. Baixe o arquivo **`JALIDE-v1.0.0.apk`** listado nos Assets do release.
2. No seu Android, permita a instalação de aplicativos de fontes desconhecidas (se solicitado).
3. Instale o APK e abra o JALIDE!

---

## 💖 Apoie o Desenvolvimento

Se o **JALIDE** te ajuda a programar ou salvar o dia fora do computador, considere apoiar o projeto com uma estrela ⭐ no repositório ou fazendo uma contribuição voluntária no painel de doações dentro do próprio aplicativo! 

A chave PIX padrão do projeto é:
`40dccccc-04fa-4c63-959d-f671794d5f27`

---

*Desenvolvido com 💜 em Flutter.*
