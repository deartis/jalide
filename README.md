# 🚀 JALIDE Mobile IDE

> **Transforme seu Android em uma estação de desenvolvimento portátil.**

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge\&logo=flutter\&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge\&logo=android\&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Suporte-339933?style=for-the-badge\&logo=node.js\&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Em%20Desenvolvimento-orange?style=for-the-badge)

</div>

---

# 📑 Índice

* [📖 Sobre](#-sobre)
* [✨ Funcionalidades](#-funcionalidades)
* [🖼️ Screenshots](#️-screenshots)
* [🛠️ Integração JALIDE + Termux](#️-integração-jalide--termux)
* [🚀 Roadmap](#-roadmap)
* [🤝 Como contribuir](#-como-contribuir)
* [📄 Licença](#-licença)

---

# 📖 Sobre

**JALIDE** é uma IDE móvel moderna desenvolvida em **Flutter**, focada em desenvolvimento **JavaScript / Node.js** diretamente no Android.

A ideia é simples: permitir que qualquer desenvolvedor consiga programar, testar, editar arquivos e acessar servidores usando apenas o celular. 💻📱

Seja para corrigir algo rápido em produção, estudar no ônibus ou desenvolver projetos completos longe do PC, o JALIDE foi pensado para entregar praticidade sem sacrificar produtividade.

---

# ✨ Funcionalidades

| Ícone | Funcionalidade          | Descrição                                                     |
| ----- | ----------------------- | ------------------------------------------------------------- |
| 📝    | **Editor Profissional** | Syntax highlighting, múltiplas abas, zoom dinâmico e autosave |
| 🐚    | **Terminal Integrado**  | Terminal Android integrado com suporte a sessões locais e SSH |
| ⚡     | **Termux Magic**        | Configuração automática de Node.js, Git e SSH no Termux       |
| 📂    | **SFTP Nativo**         | Edite arquivos remotos como se fossem locais                  |
| 🔐    | **Perfis SSH**          | Salve conexões de forma rápida e segura                       |
| 🎹    | **Teclado Auxiliar**    | Barra de atalhos otimizada para programação mobile            |
| 🌙    | **Modo Escuro**         | Interface confortável para longas sessões de código           |
| 🚀    | **Foco em Performance** | Interface leve e rápida mesmo em aparelhos modestos           |

---

# 🖼️ Screenshots

<div align="center">
  <img src="screenshots/editor.png" width="220" alt="Editor"/>
  <img src="screenshots/terminal.png" width="220" alt="Terminal"/>
  <img src="screenshots/sftp.png" width="220" alt="SFTP"/>
</div>

> 💡 *Adicione screenshots reais do app na pasta `screenshots/` para deixar o projeto muito mais atrativo no GitHub.*

---

# 🛠️ Integração: JALIDE + Termux

Para desbloquear o potencial máximo do JALIDE (**Node.js**, **NPM**, **Git**, **SSH** e automações Linux), utilize a integração com o Termux.

## ⚡ Passo 1 — Termux Magic (Modo Fácil)

1. Abra o **JALIDE**
2. Toque no ícone de terminal 🐚
3. No painel do terminal, toque no botão de **Raio Amarelo** ⚡
4. Clique em **"COPIAR E ABRIR TERMUX"**
5. Cole o comando no Termux e pressione `Enter`

O script irá:

* Instalar o Node.js
* Configurar Git
* Instalar e iniciar o OpenSSH
* Preparar o ambiente de desenvolvimento automaticamente

Depois, defina sua senha e descubra seu usuário:

```bash
passwd      # Define sua senha
whoami      # Mostra seu usuário
```

---

## 🔌 Passo 2 — Conectar via SSH

Com o SSH ativo no Termux:

```bash
sshd
```

No JALIDE:

1. Vá em **Perfis SSH**
2. Crie uma nova conexão
3. Informe:

   * IP do celular
   * Usuário do Termux
   * Senha criada anteriormente
4. Conecte 🎉

---

# 🚀 Roadmap

* [x] Editor básico
* [x] Terminal integrado
* [x] Integração com Termux
* [ ] Git integrado
* [ ] Gerenciador de projetos
* [ ] Preview web local
* [ ] Marketplace de extensões
* [ ] Suporte a múltiplas linguagens
* [ ] IA assistente para código

---

# 🤝 Como contribuir

Contribuições são muito bem-vindas.

Se quiser ajudar:

1. Faça um fork do projeto
2. Crie uma branch:

```bash
git checkout -b minha-feature
```

3. Commit suas alterações:

```bash
git commit -m "feat: minha nova feature"
```

4. Envie para seu fork:

```bash
git push origin minha-feature
```

5. Abra um Pull Request 🚀

---

# 📄 Licença

Este projeto está sob a licença MIT.

Feito com ☕, Flutter e muita programação mobile.
