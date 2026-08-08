# 📱 Guia de Permissões e Configuração Termux + SSH no JALIDE

Este guia orienta como configurar o **Termux** e as permissões do **Android** para que o **JALIDE** consiga iniciar o serviço SSH (`sshd`) em segundo plano de forma 100% automática ao conectar.

---

## 🎯 Por que estas configurações são necessárias?

A partir do Android 12 e das versões recentes do Termux (v0.118+), novos mecanismos de segurança exigem:
1. Autorização explícita no Termux para receber comandos de aplicativos externos (`RUN_COMMAND`).
2. Concessão da permissão nativa `com.termux.permission.RUN_COMMAND` ao JALIDE.
3. Isenção da otimização de bateria para impedir que o Android mate o daemon do SSH em segundo plano.

---

## 🚀 Passo a Passo de Configuração

### Passo 1: Habilitar Comandos Externos no Termux

Abra o aplicativo **Termux** no celular e execute os dois comandos abaixo:

```bash
echo "allow-external-apps = true" >> ~/.termux/termux.properties
termux-reload-settings
```

> 💡 **Nota:** Se você ainda não instalou o servidor SSH no Termux, instale executando:
> ```bash
> pkg install openssh
> ```

---

### Passo 2: Conceder a Permissão `RUN_COMMAND` ao JALIDE

O JALIDE precisa da permissão do sistema para enviar a ordem de inicialização do `sshd`.

#### Método 1: Pop-up Nativo (Recomendado)
Ao abrir o JALIDE e tentar conectar ao SSH pela primeira vez, o Android exibirá um pop-up solicitando a permissão **"Executar comandos no Termux"**. Clique em **Permitir**.

#### Método 2: Pelas Configurações do Celular
Se o pop-up não aparecer (comum em MIUI/Xiaomi, Samsung, Realme):
1. Vá em **Configurações do Android > Aplicativos > JALIDE**.
2. Abra **Permissões** (ou *Permissões Adicionais* / *Outras Permissões*).
3. Ative a permissão **"Executar comandos do Termux"** (*Run Termux commands* / *Iniciar em segundo plano*).

#### Método 3: Via ADB (Desenvolvedores / Computador)
Se preferir via linha de comando USB:
```bash
adb shell pm grant com.example.jalide com.termux.permission.RUN_COMMAND
```

---

### Passo 3: Desativar Otimização de Bateria do Termux

Para evitar que o Android encerre o processo do SSH enquanto você edita código no JALIDE:

1. Vá em **Configurações do Android > Aplicativos > Termux**.
2. Toque em **Bateria**.
3. Selecione a opção **Sem Restrições** (*Unrestricted*).

---

## 🛠️ Solução de Problemas (Troubleshooting)

### 🔴 `SocketException: Connection refused (errno = 111)`
- **Causa:** O daemon `sshd` não está rodando no Termux ou a porta (padrão: `8022`) está incorreta.
- **Solução:** No Termux, rode `sshd` manualmente uma vez para testar ou verifique se definiu a porta `8022` no perfil SSH do JALIDE.

### 🔴 `PlatformException(TERMUX_ERROR, Not allowed to start service Intent ... without permission)`
- **Causa:** O JALIDE não possui a permissão `com.termux.permission.RUN_COMMAND`.
- **Solução:** Siga o **Passo 2** acima para conceder a permissão manualmente nas configurações do app JALIDE.

### 🔴 O sshd inicia mas cai depois de alguns minutos
- **Causa:** O sistema operacional encerrou o processo do Termux em background.
- **Solução:** Verifique o **Passo 3** (Otimização de Bateria) e certifique-se de que a economia de energia do dispositivo não está limitando o Termux.

---

## 🎓 Conexão no JALIDE

Após concluir o passo a passo:
1. Abra o **JALIDE**.
2. Clique no menu ou navegue até **SSH Remote**.
3. Selecione o perfil **Localhost** (`127.0.0.1`, Porta `8022`).
4. Clique em **Conectar**. O JALIDE iniciará o Termux e o `sshd` silenciosamente em background! 🚀
