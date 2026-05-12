# 🚀 JALIDE Mobile IDE

> **Transforme seu Android em uma estação de desenvolvimento completa.**

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)
[![Status](https://img.shields.io/badge/Status-Em%20desenvolvimento-orange?style=for-the-badge)]()

</div>

---

## 📑 Índice

- [Sobre](#-sobre)
- [Funcionalidades](#-funcionalidades)
- [Screenshots](#-screenshots) *(opcional)*
- [Integração com Termux](#-integração-jalide--termux)
- [Contribuindo](#-como-contribuir)
- [Licença](#-licença)

---

## 📖 Sobre

**JALIDE** é uma IDE móvel moderna desenvolvida em **Flutter**, focada em **JavaScript / Node.js**. 

Foi criada para quando você tem apenas o celular à mão — sem abrir mão de produtividade. 💻📱

---

## ✨ Funcionalidades

| Ícone | Funcionalidade | Descrição |
|-------|---------------|-----------|
| 📝 | **Editor Profissional** | Syntax highlighting, zoom dinâmico e múltiplas abas |
| 🐚 | **Terminal Híbrido** | Alterne entre terminal local (Android) e remoto via SSH |
| ⚡ | **Termux Magic** | Configura Node.js + SSH no Termux com um clique |
| 📂 | **SFTP Nativo** | Edite arquivos remotos como se fossem locais |
| 🔐 | **Gestor de Perfis SSH** | Credenciais seguras para acesso rápido a servidores |
| 🎹 | **Teclado Auxiliar** | Atalhos `{}` `[]` `=>` otimizados para telas pequenas |

---

## 🖼️ Screenshots

<div align="center">
  <img src="screenshots/editor.png" width="200" alt="Editor"/>
  <img src="screenshots/terminal.png" width="200" alt="Terminal"/>
  <img src="screenshots/sftp.png" width="200" alt="SFTP"/>
</div>

> 💡 *Dica: Adicione prints reais do app na pasta `screenshots/` para aumentar o engajamento!*

---

## 🛠️ Integração: JALIDE + Termux

Para usar o potencial máximo (**Node.js**, **NPM**, **Git**), integre o JALIDE ao Termux.

### ⚡ Passo 1 — Termux Magic (Jeito Fácil)

1. Abra o **JALIDE** e toque no ícone de terminal no rodapé 🐚
2. No painel do terminal, toque no ícone de **Raio Amarelo** ⚡
3. Toque em **"COPIAR E ABRIR TERMUX"**
4. No Termux, cole o comando e dê `Enter` — ele instala Node.js e o servidor SSH automaticamente
5. Defina uma senha e anote seu usuário:

```bash
passwd      # Define sua senha
whoami      # Anote o resultado para usar no SSH
