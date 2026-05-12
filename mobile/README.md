# JALIDE Mobile IDE 🚀

**Transforme seu Android em uma estação de desenvolvimento completa.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Em%20desenvolvimento-orange?style=flat-square)]()

---

## Sobre

JALIDE é uma IDE móvel moderna desenvolvida em Flutter, focada em **JavaScript / Node.js**. Desenvolvida para quando você tem apenas o celular à mão — sem abrir mão de produtividade.

---

## ✨ Funcionalidades

| | Funcionalidade | Descrição |
|---|---|---|
| 📝 | **Editor profissional** | Syntax highlighting, zoom dinâmico e múltiplas abas |
| 🐚 | **Terminal híbrido** | Alterne entre terminal local (Android) e remoto via SSH |
| ⚡ | **Termux Magic** | Configura Node.js + SSH no Termux com um clique |
| 📂 | **SFTP nativo** | Edite arquivos remotos como se fossem locais |
| 🔐 | **Gestor de perfis SSH** | Credenciais seguras para acesso rápido a servidores |
| 🎹 | **Teclado auxiliar** | Atalhos `{}` `[]` `=>` otimizados para telas pequenas |

---

## 🛠️ Integração: JALIDE + Termux

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

## 📝 Licença

Distribuído sob a licença **MIT**. Veja [`LICENSE`](LICENSE) para mais informações.

---

*Desenvolvido com ❤️ para a comunidade de desenvolvedores mobile.*
