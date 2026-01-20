# 🔧 Configuração Manual do Firebase - Guia Completo

## 📋 O QUE FOI FEITO AUTOMATICAMENTE

✅ **Código Atualizado:**
- ✅ **Android:** Gradle configurado com Google Services Plugin e Firebase BoM
- ✅ **iOS:** Configuração automática via FlutterFire (veja [CONFIGURACAO_FIREBASE_IOS.md](CONFIGURACAO_FIREBASE_IOS.md))
- ✅ Modelo User com métodos `toFirestore()` e `fromFirestore()`
- ✅ AuthService salvando dados do usuário no Firestore
- ✅ Sincronização de dados do usuário no login
- ✅ Arquivo `firestore.rules` criado com regras de segurança

---

## ⚠️ CONFIGURAÇÕES MANUAIS NECESSÁRIAS NO CONSOLE FIREBASE

Você precisa fazer estas configurações **manualmente** no Console do Firebase:

### 1️⃣ ATIVAR AUTENTICAÇÃO POR EMAIL/SENHA

1. Acesse: https://console.firebase.google.com
2. Selecione o projeto: **carta-de-vinhos-320c1**
3. No menu lateral, clique em **Authentication**
4. Clique na aba **Sign-in method**
5. Clique em **Email/Password**
6. Ative o botão **Ativar** (primeira opção)
7. **NÃO** ative "Link de e-mail (login sem senha)"
8. Clique em **Salvar**

✅ **Resultado esperado:** Você verá "Email/Password" com status "Ativado"

---

### 2️⃣ CONFIGURAR REGRAS DE SEGURANÇA DO FIRESTORE

1. No Console do Firebase, clique em **Firestore Database**
2. Clique na aba **Regras**
3. **APAGUE** todo o conteúdo atual
4. **COPIE e COLE** o conteúdo do arquivo `firestore.rules` deste projeto:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Regras para a coleção de usuários
    match /users/{userId} {
      // Permitir leitura/escrita apenas para o próprio usuário autenticado
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Subcoleções do usuário (vinhos, vendas, etc)
      match /{document=**} {
        // Permitir acesso completo apenas ao próprio usuário
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Bloquear acesso a qualquer outra coleção
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

5. Clique em **Publicar**
6. Confirme clicando em **Publicar** novamente

✅ **Resultado esperado:** Você verá "Regras publicadas com sucesso"

---

### 3️⃣ VERIFICAR FIRESTORE DATABASE

1. No Console do Firebase, clique em **Firestore Database**
2. Se aparecer "Criar banco de dados", clique nele
3. Escolha **Iniciar no modo de produção**
4. Escolha a localização: **southamerica-east1 (São Paulo)** (recomendado)
5. Clique em **Ativar**

✅ **Resultado esperado:** Você verá a interface do Firestore vazia (sem coleções ainda)

---

## 🧪 TESTAR A CONFIGURAÇÃO

### Passo 1: Limpar cache e recompilar

```powershell
cd d:\projeto\app_vinho_taverna
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

### Passo 2: Criar novo usuário

1. No app, clique em "Registrar"
2. Crie um usuário teste: 
   - **Username:** teste123
   - **Password:** senha123
3. Clique em "Registrar"

### Passo 3: Verificar no Console Firebase

1. Vá em **Authentication** → **Users**
   - ✅ Você deve ver o email: `teste123@appvinhotaverna.local`

2. Vá em **Firestore Database**
   - ✅ Você deve ver uma coleção `users`
   - ✅ Dentro dela, um documento com o UID do usuário
   - ✅ Dentro do documento, os campos: `username` e `createdAt`

### Passo 4: Testar sincronização cross-device

1. **No Windows:**
   - Faça login com o usuário criado
   - Adicione alguns vinhos

2. **No Android:**
   - Instale o app
   - Faça login com o mesmo usuário
   - ✅ Os vinhos devem aparecer após a sincronização

---

## 🔍 COMO VERIFICAR SE ESTÁ FUNCIONANDO

### No Log do App (Debug Console)

Você deve ver estas mensagens ao registrar um novo usuário:
```
✓ Usuário criado no Firebase Auth: [UID do usuário]
✓ Dados do usuário salvos no Firestore
✓ Database inicializado
✓ Firebase inicializado com sucesso!
```

Ao fazer login:
```
✓ Autenticado no Firebase: [UID do usuário]
✓ Dados do usuário recuperados do Firestore
```

### No Console Firebase

**Authentication:**
- Você verá os usuários registrados com emails fictícios

**Firestore Database:**
- Estrutura esperada:
```
users/
  └── [UID do Firebase]/
      ├── username: "nome_do_usuario"
      ├── createdAt: "2026-01-19T..."
      └── wines/
          └── [ID do vinho]/
              ├── name: "..."
              ├── price: ...
              └── ... (outros campos)
```

---

## ❌ PROBLEMAS COMUNS

### 1. "Firebase não configurado (modo offline)"
- ✅ **Solução:** Execute `flutter pub get` e recompile o app

### 2. "PERMISSION_DENIED: Missing or insufficient permissions"
- ✅ **Solução:** Verifique se você configurou as regras do Firestore corretamente (Passo 2)

### 3. "The email address is already in use"
- ✅ **Solução:** Usuário já existe. Faça login ou use outro username

### 4. Dados não aparecem em outro dispositivo
- ✅ **Solução:** 
  - Verifique se ambos dispositivos têm internet
  - Aguarde alguns segundos para sincronização
  - Feche e abra o app novamente

### 5. "Unable to resolve dependency com.google.firebase:firebase-bom"
- ✅ **Solução:** Execute:
  ```powershell
  cd android
  ./gradlew --refresh-dependencies
  ```

---

## 📊 ESTRUTURA DE DADOS NO FIRESTORE

```
firestore/
├── users/
│   ├── [UID_Firebase_Usuario1]/
│   │   ├── username: "joao"
│   │   ├── createdAt: "2026-01-19T10:30:00Z"
│   │   └── wines/
│   │       ├── [ID_Vinho_1]/
│   │       │   ├── name: "Château Margaux"
│   │       │   ├── price: 1500.00
│   │       │   ├── region: "Bordeaux"
│   │       │   └── ... (outros campos)
│   │       └── [ID_Vinho_2]/
│   │           └── ...
│   │
│   └── [UID_Firebase_Usuario2]/
│       ├── username: "maria"
│       └── ...
```

**Características:**
- ✅ Cada usuário tem seu próprio documento com seu UID do Firebase Auth
- ✅ Os vinhos ficam em uma subcoleção `wines` dentro do documento do usuário
- ✅ Usuários **NÃO** podem acessar dados de outros usuários
- ✅ Dados sincronizam automaticamente entre dispositivos

---

## 🎯 CHECKLIST FINAL

Antes de usar o app em produção, confirme:

- [ ] Autenticação Email/Senha ativada no Firebase Console
- [ ] Regras de segurança do Firestore publicadas
- [ ] Firestore Database criado e ativado
- [ ] App testado criando usuário
- [ ] Dados do usuário aparecem no Firestore
- [ ] Vinhos aparecem na subcoleção correta
- [ ] Sincronização funcionando entre dispositivos
- [ ] Logs não mostram erros de permissão

---

## 📞 SUPORTE

Se encontrar problemas:
1. Verifique os logs no Debug Console
2. Verifique o Console do Firebase
3. Certifique-se de que há internet
4. Tente fazer `flutter clean` e recompilar

**Data de criação:** 19 de janeiro de 2026
