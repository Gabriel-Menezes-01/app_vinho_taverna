# Configuração do Firebase para Sincronização

Este app agora suporta sincronização em nuvem usando Firebase Firestore.

## Passo 1: Criar Projeto no Firebase

1. Acesse https://console.firebase.google.com/
2. Clique em "Adicionar projeto"
3. Nome do projeto: **app-vinho-taverna**
4. Desabilite Google Analytics (opcional)
5. Clique em "Criar projeto"

## Passo 2: Adicionar Android ao Projeto

1. No console do Firebase, clique no ícone do Android
2. Preencha os campos:
   - **Nome do pacote**: `com.example.app_vinho_taverna`
   - **Apelido do app**: Taverna dos Vinhos
   - **SHA-1**: (opcional por enquanto)
3. Clique em "Registrar app"
4. **Baixe o arquivo `google-services.json`**

## Passo 3: Adicionar google-services.json ao Projeto

1. Copie o arquivo `google-services.json` baixado
2. Cole em: `android/app/google-services.json`

## Passo 4: Configurar build.gradle

### android/build.gradle.kts

Adicione no bloco `dependencies`:

```kotlin
dependencies {
    classpath("com.google.gms:google-services:4.4.0")
}
```

### android/app/build.gradle.kts

No **final do arquivo**, adicione:

```kotlin
apply(plugin = "com.google.gms.google-services")
```

## Passo 5: Configurar Firestore

1. No console do Firebase, vá em "Firestore Database"
2. Clique em "Criar banco de dados"
3. Selecione "Modo de produção"
4. Escolha a localização (southamerica-east1 para Brasil)
5. Clique em "Ativar"

## Passo 6: Configurar Regras de Segurança

No Firestore, vá em "Regras" e adicione:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Permitir que usuários acessem apenas seus próprios dados
    match /users/{userId}/wines/{wineId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Passo 7: Testar a Configuração

Execute o comando:

```bash
flutter run
```

## Como Funciona a Sincronização

### Automática
- Ao abrir o app com internet, sincroniza automaticamente
- Quando a conexão é restaurada, sincroniza em segundo plano

### Manual
- Pull-to-refresh na tela principal força sincronização

### Funcionamento Offline
- Todos os dados ficam salvos localmente em SQLite
- Funciona normalmente sem internet
- Quando conectar, envia tudo para a nuvem

### Multi-dispositivo
- Login com o mesmo usuário em outro dispositivo
- Todos os vinhos aparecem sincronizados
- Mudanças em um dispositivo aparecem no outro

## Estrutura no Firestore

```
users/
  └── {userId}/
      └── wines/
          ├── {wineId1}/
          │   ├── id
          │   ├── name
          │   ├── price
          │   ├── description
          │   ├── isGood
          │   ├── region
          │   ├── wineType
          │   └── lastModified
          └── {wineId2}/
              └── ...
```

## Solução de Problemas

### Erro: google-services.json not found
- Verifique se o arquivo está em `android/app/google-services.json`
- Certifique-se de que o nome do pacote está correto

### Erro: Authentication required
- As regras do Firestore estão muito restritivas
- Para teste, use regras mais permissivas (cuidado em produção)

### App não sincroniza
- Verifique a conexão com internet
- Olhe os logs no terminal: `flutter run`
- Verifique se o Firebase foi inicializado no main.dart

## Comandos Úteis

```bash
# Ver logs de sincronização
flutter run --verbose

# Limpar cache do Firebase
flutter clean
flutter pub get
```
