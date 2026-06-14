# 🔄 Sistema de Reconexão Automática SSH no JALIDE

## ✅ Implementado e Testado

A reconexão automática SSH foi totalmente integrada ao seu JALIDE com os seguintes recursos:

---

## 🎯 Recursos Principais

### 1. **Monitoramento Contínuo de Saúde (Heartbeat)**
- ✅ Envia heartbeat a cada 30 segundos (configurável)
- ✅ Detecta desconexões imediatamente
- ✅ Testa a conexão antes de cada operação

### 2. **Reconexão Automática com Backoff Exponencial**
- ✅ Tenta reconectar automaticamente quando desconecta
- ✅ Backoff exponencial: 2s → 4s → 8s → 16s → 32s
- ✅ Máximo de 5 tentativas antes de dar erro
- ✅ Salva última conexão bem-sucedida

### 3. **Armazenamento Seguro**
- ✅ Chave API e credenciais SSH criptografadas
- ✅ Última conexão salva em segurança
- ✅ Recuperável em qualquer momento

### 4. **Interface Visual**
- ✅ Widget de status de conexão em tempo real
- ✅ Indicador visual de tentativas de reconexão
- ✅ Botão de reconectar manualmente
- ✅ Configurações acessíveis

---

## 📱 Como Usar

### **Conectar a SSH (como sempre)**
1. Clique no menu (☰)
2. Selecione "SSH Remote"
3. Escolha ou crie um perfil
4. Conecte normalmente

### **Novo: Widget de Status SSH**
Uma vez conectado, aparecerá um painel no topo mostrando:
- 🟢 **Status**: Verde (conectado), Âmbar (reconectando), Vermelho (erro)
- 📊 **Informações**: Perfil conectado, tentativas de reconexão
- ⚙️ **Ações**: Reconectar agora, Configurações

### **Reconectar Manualmente**
1. Clique no ícone 🔄 no widget de status
2. Ou vá em Menu > Config. Gemma IA > Reconectar Agora (será adicionado no menu)

### **Configurar Heartbeat**
1. Clique em ⚙️ no widget de status
2. Ajuste o intervalo (10s - 120s)
3. Configure auto-reconexão ON/OFF

---

## 🔧 Arquivos Criados

```
lib/
  services/
    └── ssh_connection_manager.dart ✨ (Novo - Gerenciador de reconexão)
  widgets/
    └── ssh_connection_status_widget.dart ✨ (Novo - UI do status)
  screens/
    └── editor_screen.dart (Modificado - Integração)
```

---

## 🛠️ Implementação Técnica

### **SshConnectionManager** 
Responsável por:
```dart
- Monitorar saúde da conexão com timers
- Detectar desconexões via heartbeat
- Reconectar automaticamente com backoff
- Armazenar última conexão bem-sucedida
- Emitir eventos de mudança de estado
```

### **SshConnectionStatusWidget**
Mostra:
```dart
- Status atual da conexão
- Tentativas de reconexão em progresso
- Botão para reconectar manualmente
- Menu de configurações
```

### **Fluxo de Reconexão**
```
Desconexão Detectada
        ↓
    ⏳ 2s de espera
        ↓
    Tentativa 1 de reconexão
        ↓
    ❌ Falhou? → Próxima tentativa
    ✅ Sucesso? → Estado: Conectado
        ↓
    Volta ao monitoramento de heartbeat
```

---

## ⚙️ Configurações (SharedPreferences + SecureStorage)

| Config | Padrão | Range |
|--------|--------|-------|
| Auto-Reconexão | Ativado | ON/OFF |
| Intervalo Heartbeat | 30s | 10s - 120s |
| Tentativas Máximas | 5 | Fixo |
| Backoff Inicial | 2s | Fixo |

---

## 📊 Estados de Conexão

```
disconnected  ←→  connecting  ←→  connected
                      ↑              ↓
                      └──← error ←──┘
```

O gerenciador monitora estes estados e reage:
- **Conectado**: Envia heartbeat a cada X segundos
- **Desconectado**: Tenta reconectar se auto-reconexão estiver ON
- **Erro**: Mostra mensagem e aguarda ação manual

---

## 🐛 Troubleshooting

### "Reconecta infinitamente"
- Verifique credenciais SSH
- Confirme que Termux/servidor está rodando
- Aumente o timeout de heartbeat em Configurações

### "Nunca reconecta"
- Verifique se auto-reconexão está ON
- Clique "Reconectar Agora" manualmente
- Verifique logs do Android (flutter logs)

### "Perde conexão frequentemente"
- Pode ser conexão Wi-Fi instável
- Aumente intervalo de heartbeat (30s → 60s)
- Use 4G para testes de estabilidade

---

## 📝 Logs de Debug

Ative logs com:
```bash
flutter logs
```

Procure por:
- `✅ SSH conectado com sucesso`
- `⚠️ Conexão SSH perdida!`
- `⏳ Reconectando em...`
- `❌ Máximo de tentativas atingido`

---

## 🚀 Próximos Passos (Opcional)

1. **Persistência de Conexão**: Reconectar automaticamente ao abrir app
2. **Notificações**: Alertar quando reconectar com sucesso
3. **Histórico**: Salvar histórico de reconexões
4. **Pool de Conexões**: Suportar múltiplas conexões SSH simultâneas

---

## 🎓 Código Exemplo

### Usar SshConnectionManager programaticamente:

```dart
// Inicializar
final manager = SshConnectionManager(profileManager: _sshProfileManager);
await manager.initialize();

// Conectar
final success = await manager.connect(profile);

// Reconectar manualmente
await manager.reconnectNow();

// Escutar mudanças de estado
manager.connectionStateStream.listen((state) {
  print('Estado: $state');
});

// Desconectar
await manager.disconnect();
```

---

**Seu SSH agora é 100% robusto! 🛡️**

Qualquer desconexão será detectada automaticamente e você terá opções para reconectar sem perder dados.
