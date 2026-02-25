# Configuracao Firebase (Auth, Firestore, Storage)

Este guia mostra como criar um projeto Firebase gratuito e configurar o app para
sincronizar dados e imagens entre dispositivos.

## 1) Criar projeto Firebase (gratis)

1. Acesse o Firebase Console e clique em "Add project".
2. Escolha um nome de projeto.
3. Quando pedir a localizacao, escolha uma regiao compativel com o plano free:
   - United States (us) ou Europe (eu)
4. Finalize o projeto.

Observacao: a regiao do projeto nao pode ser alterada depois.

## 2) Ativar Authentication

1. Menu esquerdo: Authentication
2. Clique em "Get started"
3. Em "Sign-in method", ative Email/Password

## 3) Ativar Firestore

1. Menu esquerdo: Firestore Database
2. Clique em "Create database"
3. Start in test mode (temporario)
4. Escolha a mesma regiao do projeto (us ou eu)

## 4) Ativar Storage

1. Menu esquerdo: Storage
2. Clique em "Get started"
3. Escolha a mesma regiao do projeto

Se aparecer erro de regiao sem bucket gratuito, crie um novo projeto com regiao
us ou eu.

## 5) Criar apps no Firebase

1. Project settings (icone de engrenagem)
2. Em "Your apps", adicione:
   - Android (package name do app)
   - iOS (bundle id do app)
   - Web (para Windows/desktop)

Baixe os arquivos:
- Android: google-services.json -> android/app/
- iOS: GoogleService-Info.plist -> ios/Runner/

## 6) Gerar firebase_options.dart

No terminal:

- dart pub global activate flutterfire_cli
- flutterfire configure --project <seu-project-id>

Isso atualiza o arquivo lib/firebase_options.dart.

## 7) Dependencias no pubspec.yaml

Garanta que existam estas dependencias:

- firebase_core
- firebase_auth
- cloud_firestore
- firebase_storage

Depois rode:

- flutter pub get

## 8) Regras definitivas

Firestore Rules:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /wines/{wineId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /adega/{wineId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /sales/{saleId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    match /test/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}

Storage Rules:

rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}

## 9) Teste

1. Rode o app e faca login.
2. Cadastre um vinho com imagem.
3. Verifique no Storage: users/<uid>/wines/<id>.jpg
4. Abra o app em outro dispositivo e confirme a imagem.

## 10) Problemas comuns

- Storage nao cria bucket: projeto em regiao sem free -> crie novo projeto.
- Erro object-not-found: upload nao ocorreu -> regras ou auth.
- Imagens antigas: reabra o vinho e salve a imagem de novo.
