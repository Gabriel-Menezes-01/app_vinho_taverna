# 🧪 Guia de Testes - Sincronização de Vinhos

## Resumo Rápido

O app agora sincroniza vinhos automaticamente com Firebase. Este guia mostra como testar.

## ✅ Teste 1: Adicionar Vinho (Local + Sync Attempt)

### Pré-requisitos
- App aberto no device Android
- Usuário autenticado (teste1@gmail.com ou outro)
- Terminal do VS Code aberto com `flutter logs`

### Passos

1. **Inicie o monitoramento de logs**
   ```bash
   flutter logs
   ```

2. **No app, clique no menu (⋮)**
   - Procure o hamburger menu no topo direito
   - Clique nele

3. **Clique em "Adicionar vinho"**
   - Digite a senha quando solicitado
   - A tela de adição de vinho abrirá

4. **Preencha o formulário**
   ```
   Nome:        "Tinta Negra"
   Preço:       "25.50"
   Região:      "Douro"
   Tipo:        "Tinto"
   Quantidade:  "10"
   Descrição:   "Vinho português da Madeira"
   ```

5. **Clique em "Salvar"**

### ✅ Esperado nos Logs
```
[verde] I/flutter (15915): 🍷 Adicionando vinho: Tinta Negra
[verde] I/flutter (15915): ✅ Vinho adicionado localmente
[verde] I/flutter (15915): ☁️ Tentando sincronizar com Firebase...
```

### ✅ Esperado na Tela
- Vinho desaparece (tela limpa para adicionar outro)
- Mensagem verde: "Vinho adicionado com sucesso!"
- Se voltar para Home, "Tinta Negra" aparece na lista

### ❌ Se Vir Erros

**Erro: "Nenhum vinho para sincronizar"**
- Significa synced=0 não foi setado
- Vinho foi adicionado mas sinalizador está errado
- Verifique DatabaseService.insertWine()

**Erro: "Erro ao sincronizar" com mensagem Firebase**
- Firestore database não existe (esperado)
- Vinho foi salvo localmente ✅
- Faz sync quando database for criado

---

## ✅ Teste 2: Verificar Sincronização Local

### Objetivo
Confirmar que vinho está marcado como synced=0 no banco local

### Passos

1. **Abra um terminal/PowerShell**

2. **Navegue até a pasta do projeto**
   ```bash
   cd d:\projeto\app_vinho_taverna
   ```

3. **Acesse o banco de dados do device**
   ```bash
   $ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
   & $ADB shell
   sqlite3 /data/data/com.banco.cartavinhos/databases/wine_app.db
   ```

4. **Verifique vinhos não sincronizados**
   ```sql
   SELECT id, name, synced, last_modified FROM wines WHERE synced = 0;
   ```

### ✅ Esperado
```
id                          | name          | synced | last_modified
28e9a2f1a5b3c4d5e6f7g8h9i0 | Tinta Negra   | 0      | 2026-01-11T10:30:45.123456
```

Se o resultado está vazio, synced não foi setado corretamente.

### Como Sair do SQLite
```sql
.quit
```

---

## ✅ Teste 3: Simulação de Múltiplos Vinhos

### Objetivo
Adicionar vários vinhos e verificar se todos são sincronizados

### Passos

1. **Adicione 3 vinhos rapidamente**

   **Vinho 1:** "Douro Tinto 2019" - Tinto - R$35.00
   
   **Vinho 2:** "Vinho Verde Branco" - Branco - R$12.00
   
   **Vinho 3:** "Rosé da Madeira" - Rosé - R$18.00

2. **Observe os logs**
   ```
   🍷 Adicionando vinho: Douro Tinto 2019
   ✅ Vinho adicionado localmente
   ☁️ Tentando sincronizar com Firebase...
   
   🍷 Adicionando vinho: Vinho Verde Branco
   ✅ Vinho adicionado localmente
   ☁️ Tentando sincronizar com Firebase...
   
   🍷 Adicionando vinho: Rosé da Madeira
   ✅ Vinho adicionado localmente
   ☁️ Tentando sincronizar com Firebase...
   ```

3. **Volte para a Home Screen**
   - Todos os 3 vinhos devem aparecer na lista

### ✅ Esperado
- 3 vinhos aparecem na lista
- Cada um tem synced=0 no banco local
- Logs mostram tentativa de sincronização para cada um

---

## ✅ Teste 4: Teste Cross-Device (Quando Firebase DB Criado)

### ⚠️ Pré-requisito: Firestore Database Deve Existir

1. **Acesse Firebase Console**
   - https://console.firebase.google.com/
   - Projeto: carta-vinhos-fd287

2. **Crie o Firestore Database**
   - Clique em "Firestore Database"
   - Clique "Criar banco de dados"
   - Região: `europe-west1`
   - Modo: "Modo de teste"
   - Clique "Criar"

### Passos do Teste

**Device A (Seu device atual):**
1. App aberto, usuário logado
2. Adicione vinho "Tinta da Casa"

**Device B (Emulador ou outro device):**
1. Abra o app
2. Faça login com MESMO email/senha de Device A
3. Aguarde sincronização (ver logs: "Buscando vinhos do usuário...")

### ✅ Esperado em Device B
- "Tinta da Casa" aparece automaticamente na lista
- Sem precisar adicionar manualmente
- Logs mostram:
  ```
  🔄 Buscando vinhos do usuário [firebaseUid]...
  ✅ Vinho "Tinta da Casa" baixado do servidor
  ```

---

## 📊 Checklist de Testes

- [ ] Teste 1: Adicionar 1 vinho (logs esperados)
- [ ] Teste 1: Vinho aparece na lista após adicionar
- [ ] Teste 2: Vinho tem synced=0 no banco local
- [ ] Teste 3: Adicionar 3 vinhos rapidamente
- [ ] Teste 3: Todos aparecem na lista
- [ ] Teste 4: Device B baixa vinhos automaticamente

## 🐛 Troubleshooting

### Logs não aparecem?
```bash
flutter logs --verbose
```

### App trava ao adicionar vinho?
- Verifique se há erro no console
- Feche e reabra o app
- Execute `flutter clean && flutter run`

### Vinho não aparece na lista após adicionar?
- Verifique synced=0 está sendo setado
- Confira se user_id está correto
- Veja logs de erro

### Firebase sync não funciona?
- Verifique se Firestore database foi criado
- Confira se device tem internet
- Execute `flutter run` com `--verbose`

---

## 🔍 Monitore a Sincronização

### Logs Importantes

```
# Adição de vinho
🍷 Adicionando vinho: [nome]
✅ Vinho adicionado localmente
☁️ Tentando sincronizar com Firebase...

# Sincronização bem-sucedida
✅ Vinho [nome] sincronizado!

# Sync ao fazer login em novo device
🔄 Iniciando sincronização de vinhos do Firebase...
🔄 Buscando vinhos do usuário [uid]...
✅ Vinho [nome] baixado do servidor

# Erro de sincronização (esperado se Firebase DB não existe)
❌ Erro ao sincronizar [nome]: [mensagem]
```

### Emojis para Procurar
- 🍷 = Ação relacionada a vinho
- ☁️ = Sincronização Firebase
- ✅ = Sucesso
- ❌ = Erro
- 🔄 = Sincronização em andamento

---

## 📈 Próximos Passos Após Testes

1. ✅ **Adicione vinho com sucesso** 
2. ✅ **Veja synced=0 no banco**
3. ✅ **Confirme logs de tentativa de sync**
4. 📋 **Crie Firestore database** (quando quiser testar Firebase completo)
5. 📋 **Teste cross-device** (com Firebase database)

---

## 🆘 Precisa de Ajuda?

Se algo não funcionar:

1. Verifique os logs com `flutter logs`
2. Procure por mensagens de erro
3. Confira se app está compilando sem erros
4. Execute `flutter clean && flutter pub get && flutter run`

**Documentação completa:** Veja [SINCRONIZACAO_VINHOS.md](SINCRONIZACAO_VINHOS.md)
