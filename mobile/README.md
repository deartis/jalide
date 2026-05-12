# JALIDE Mobile IDE 🚀

JALIDE é uma IDE móvel moderna desenvolvida em Flutter, projetada para transformar seu dispositivo Android em uma estação de trabalho completa. Com foco em **JavaScript/Node.js**, o JALIDE oferece uma experiência de desenvolvimento fluida, mesmo quando você tem apenas o celular à mão.

---

## ✨ Funcionalidades Atuais

- 📝 **Editor de Código Profissional**: Syntax highlighting, zoom dinâmico e suporte a múltiplas abas.
- 🐚 **Terminal Híbrido**: Alterne entre terminal local (Android) e terminal remoto via SSH.
- ⚡ **Termux Magic**: Integração automatizada para configurar Node.js e SSH no Termux com um clique.
- 📂 **SFTP Nativo**: Edite arquivos remotos diretamente no editor como se fossem locais.
- 🔐 **Gestor de Perfis SSH**: Armazenamento seguro de credenciais para acesso rápido a servidores.
- 🎹 **Teclado Auxiliar**: Atalhos essenciais (`{`, `}`, `[`, `]`, `=>`, etc.) otimizados para telas pequenas.

---

## 🛠️ Guia de Integração: JALIDE + Termux

Para usar o potencial máximo (Node.js, NPM, Git), recomendamos integrar o JALIDE ao **Termux**.

### 1. O Jeito Fácil (Termux Magic ⚡)
1. Abra o JALIDE e clique no ícone de terminal no rodapé.
2. No painel do terminal, clique no ícone de **Raio Amarelo (⚡)**.
3. Clique em **"COPIAR E ABRIR TERMUX"**.
4. No Termux, **cole o comando** e dê Enter. Ele instalará o Node.js e o servidor SSH automaticamente.
5. **Importante**: No Termux, defina uma senha digitando `passwd` e anote seu usuário digitando `whoami`.

### 2. Conectando via SSH
Uma vez que o Termux está configurado:
1. No JALIDE, clique no menu superior (**⋮**) > **SSH Remote**.
2. Clique em **(+)** para adicionar um novo perfil.
   - **Host**: `localhost`
   - **Porta**: `8022` (padrão do Termux)
   - **Usuário**: (o que apareceu no `whoami`)
   - **Senha**: (a que você definiu no `passwd`)
3. Salve e clique em **Conectar**.

---

## 📂 Editando Arquivos Remotamente (SFTP)

O JALIDE não apenas oferece um terminal, mas um **File Explorer remoto completo**:

1. Ao conectar via SSH, o explorador lateral abrirá automaticamente na pasta `home` do servidor remoto.
2. **Abrir**: Toque em qualquer arquivo para carregá-lo no editor.
3. **Salvar**: Pressione Salvar ou use `Ctrl+S`. O JALIDE fará o upload via SFTP instantaneamente.
4. **Persistência**: Você pode fechar o terminal para ganhar espaço; a sessão SSH continuará ativa em segundo plano. Basta reabrir o terminal para continuar de onde parou.

---

## 🤝 Como Contribuir

JALIDE é um projeto **100% open-source**. Sinta-se à vontade para abrir issues, sugerir melhorias ou enviar Pull Requests!

1. **Fork** o repositório.
2. Crie sua branch: `git checkout -b minha-feature`.
3. Commit suas mudanças: `git commit -m 'Minha contribuição'`.
4. Push para a branch: `git push origin minha-feature`.
5. Abra um **Pull Request**.

---

## 📝 Licença

Distribuído sob a licença **MIT**. Veja `LICENSE` para mais informações.

---
*Desenvolvido com ❤️ para a comunidade de desenvolvedores mobile.*
