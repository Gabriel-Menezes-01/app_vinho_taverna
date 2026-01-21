# 🔐 Verificação de Usuário em Todas as Plataformas

## Mudanças Realizadas

### 1. **Verificação em Tempo de Inicialização (main.dart)**
   - Ao abrir o app, verifica se o usuário existe no banco
   - Se não existir → vai direto para login
   - Mostra "Verificando usuário..." enquanto carrega

### 2. **Verificação Aprofundada (auth_service.dart)**
   
   A função `getCurrentUser()` agora verifica:
   
   ✅ **Verificação 1: Usuário no Banco Local (SQLite)**
   - Se userId está salvo em SharedPreferences
   - Se o usuário existe na tabela users
   - Auto-logout automático se usuário foi deletado
   
   ✅ **Verificação 2: Dados Válidos**
   - Se email não está vazio
   - Se username existe
   - Auto-logout se dados inválidos
   
   ✅ **Verificação 3: Sincronização Firebase** (Multi-device)
   - Se Firebase está habilitado
   - Se usuário existe também no Firestore
   - Fallback para cache local se Firebase cair

### 3. **Verificação na HomeScreen**
   - Ao entrar na HomeScreen, verifica novamente se usuário existe
   - Se não existir → redireciona para login
   - Em caso de erro crítico → volta para login

## Fluxo Completo

```
┌─ Iniciar App
│
├─ main.dart: isLoggedIn()?
│  │
│  ├─ SIM → verifica authService.getCurrentUser()
│  │  │
│  │  ├─ SQLite: usuário existe?
│  │  ├─ Email válido?
│  │  ├─ Firebase: sincronizado?
│  │  │
│  │  └─ SIM → vai para HomeScreen ✅
│  │  └─ NÃO → vai para LoginScreen 🔴
│  │
│  └─ NÃO → vai para LoginScreen 🔴
│
├─ HomeScreen: _loadData()
│  │
│  └─ Verifica novamente getUserAsync()
│     └─ Se erro → volta para LoginScreen
│
└─ FIM
```

## Situações Tratadas

| Situação | Ação |
|----------|------|
| Usuário deletado do banco | Auto-logout → Login |
| Email vazio/nulo | Auto-logout → Login |
| Firebase sem sincronização | Usa cache local, continua |
| Firestore indisponível | Fallback SQLite, continua |
| Erro ao carregar HomeScreen | Redireciona para Login |
| Usuario não autenticado | Login screen |

## Plataformas Suportadas

✅ Windows (Desktop)
✅ Android (Mobile)
✅ iOS (Mobile)
✅ macOS (Desktop)
✅ Web

Todas as plataformas agora usam a **mesma lógica de verificação**.

## Como Testar

### Teste 1: Usuário Normal
```
1. Fazer login normalmente
2. App abre HomeScreen
3. Tudo funciona ✅
```

### Teste 2: Simular Usuário Deletado
```
1. Abrir banco de dados
2. Deletar usuário da tabela users
3. Reabrir app
4. Vai para Login automaticamente ✅
```

### Teste 3: Forçar Logout
```
1. No código: await authService.logout()
2. Reabrir app
3. Vai para Login automaticamente ✅
```

### Teste 4: Multi-Device
```
1. Login em Windows com email@example.com
2. Login em Android com mesmo email
3. Os dois acessam os mesmos vinhos (Firestore)
4. Se deletar usuário em um → afeta os dois ✅
```

## Logs para Debug

Procure por estes logs no terminal:

```
🔐 getCurrentUser: userId = 123          # Encontrou ID salvo
🔐 ✅ Usuário verificado: nomeUsuario    # Usuário válido
🔐 ⚠️ Usuário não existe mais no banco!  # Usuário deletado
☁️ Verificando sincronização no Firebase # Checando Firestore
✅ Usuário autenticado em linux          # App iniciado com sucesso
❌ Usuário não encontrado no banco!      # Redirecionando para login
```

## Possíveis Melhorias Futuras

- [ ] Notificação quando usuário é deletado de outro dispositivo
- [ ] Sincronização em tempo real com Firestore
- [ ] Biometric login (face/fingerprint)
- [ ] Token refresh automático
