# Configuração do Firebase para Sincronização

## Passo 1: Criar Projeto no Firebase Console

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em "Adicionar projeto"
3. Nome do projeto: `app-vinho-taverna` (ou qualquer nome)
4. Aceite os termos e clique em "Criar projeto"

## Passo 2: Adicionar App Android

1. No console do Firebase, clique no ícone Android
2. **Package name**: `com.example.app_vinho_taverna`
3. **App nickname** (opcional): Vinho Taverna
4. **SHA-1** (opcional por enquanto): deixe em branco
5. Clique em "Registrar app"

## Passo 3: Baixar google-services.json

1. Faça download do arquivo `google-services.json`
2. Coloque o arquivo em: `android/app/google-services.json`

## Passo 4: Configurar build.gradle (Projeto)

Abra `android/build.gradle.kts` e verifique se tem:

```kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
        // Adicione esta linha:
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

## Passo 5: Configurar build.gradle (App)

Abra `android/app/build.gradle.kts` e adicione no final do arquivo:

```kotlin
apply(plugin = "com.google.gms.google-services")
```

## Passo 6: Ativar Firestore Database

1. No Firebase Console, vá em "Build" > "Firestore Database"
2. Clique em "Create database"
3. Escolha o modo de produção ou teste
4. Selecione uma região próxima (ex: `southamerica-east1` para São Paulo)

## Passo 7: Configurar Regras de Segurança do Firestore

No Firebase Console > Firestore Database > Rules, configure:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Cada usuário só pode acessar seus próprios vinhos
    match /users/{userId}/wines/{wineId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Alternativamente, para desenvolvimento (MENOS SEGURO):
    match /users/{userId}/wines/{wineId} {
      allow read, write: if true;
    }
  }
}
```

**IMPORTANTE**: As regras acima permitem acesso público para desenvolvimento. Para produção, você precisará implementar Firebase Authentication.

## Passo 8: Testar a Sincronização

1. Execute o app: `flutter run -d R5CX23VGCMD`
2. Faça login
3. Adicione um vinho com internet conectada
4. Verifique no Firebase Console se o vinho apareceu em Firestore Database
5. O caminho deve ser: `users/{userId}/wines/{wineId}`

## Estrutura do Firestore

```
users/
  └── {userId}/
      └── wines/
          └── {wineId}/
              ├── name: string
              ├── region: string
              ├── year: int
              ├── type: string
              ├── rating: double
              ├── notes: string
              ├── imagePath: string
              ├── lastModified: timestamp
```

## Solução de Problemas

### Erro: google-services.json não encontrado
- Verifique se o arquivo está em `android/app/google-services.json`
- O caminho deve ser exato

### Erro: FirebaseException
- Verifique se o Firebase foi inicializado corretamente no `main.dart`
- Confirme que as regras do Firestore permitem acesso

### Vinhos não sincronizam
- Verifique a conexão com internet
- Confira os logs: `flutter logs`
- Verifique no Firestore Console se os dados estão sendo salvos

### Desenvolvimento Multi-dispositivo

Para testar sincronização entre dispositivos:
1. Instale o app em dois dispositivos
2. Faça login com o mesmo usuário em ambos
3. Adicione um vinho no dispositivo 1
4. Aguarde alguns segundos
5. Puxe para atualizar no dispositivo 2
6. O vinho deve aparecer

## Próximos Passos (Opcional)

1. **Firebase Authentication**: Implementar login real com Firebase Auth
2. **Storage**: Sincronizar imagens no Firebase Storage
3. **Offline Persistence**: Melhorar cache offline do Firestore
4. **Notificações**: Avisar quando novos vinhos são adicionados
