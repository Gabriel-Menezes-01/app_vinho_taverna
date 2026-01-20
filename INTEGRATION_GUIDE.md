# 🚀 GUIA DE INTEGRAÇÃO COMPLETO - Sincronização Multi-Dispositivo

## 📋 Índice

1. [Setup Inicial](#1-setup-inicial)
2. [Configuração do Firebase](#2-configuração-do-firebase)
3. [Integração no App Flutter](#3-integração-no-app-flutter)
4. [Fluxo de Sincronização](#4-fluxo-de-sincronização)
5. [Resolução de Conflitos](#5-resolução-de-conflitos)
6. [Performance e Otimizações](#6-performance-e-otimizações)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. SETUP INICIAL

### 1.1 Instalar Dependências

```bash
flutter pub get
```

### 1.2 Gerar Código do Isar

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Isso vai gerar o arquivo `product_isar.g.dart`.

### 1.3 Estrutura de Pastas

```
lib/
├── models/
│   └── product_isar.dart          # Model com anotações Isar
├── services/
│   ├── fcm_sync_service.dart      # Gerenciamento FCM
│   ├── product_sync_repository.dart  # Lógica de sincronização
│   └── sync_isolate_manager.dart  # Isolate para operações pesadas
└── main.dart
```

---

## 2. CONFIGURAÇÃO DO FIREBASE

### 2.1 Console do Firebase

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Crie um novo projeto ou use existente
3. Adicione o app Android e iOS

### 2.2 Android - google-services.json

Baixe `google-services.json` e coloque em:
```
android/app/google-services.json
```

### 2.3 iOS - GoogleService-Info.plist

Baixe `GoogleService-Info.plist` e coloque em:
```
ios/Runner/GoogleService-Info.plist
```

### 2.4 Configurar Firebase Admin SDK (Backend)

No seu servidor Node.js:

```bash
npm install firebase-admin
```

Baixe a service account key do Firebase Console e configure:

```typescript
import admin from 'firebase-admin';

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: "your-project-id",
    clientEmail: "your-client-email@project.iam.gserviceaccount.com",
    privateKey: "-----BEGIN PRIVATE KEY-----\n...",
  }),
});
```

---

## 3. INTEGRAÇÃO NO APP FLUTTER

### 3.1 Inicializar Isar no main.dart

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'services/fcm_sync_service.dart';
import 'services/product_sync_repository.dart';
import 'models/product_isar.dart';

late Isar isar;
late ProductSyncRepository syncRepository;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Firebase
  await Firebase.initializeApp();
  
  // 2. Inicializar Isar Database
  final dir = await getApplicationDocumentsDirectory();
  isar = await Isar.open(
    [ProductIsarSchema, SyncMetadataSchema],
    directory: dir.path,
    name: 'app_database',
  );
  
  debugPrint('✅ Isar Database inicializado');
  
  // 3. Inicializar Sync Repository
  syncRepository = ProductSyncRepository(
    isar: isar,
    apiBaseUrl: 'https://sua-api.com',
    getAuthToken: () => _getStoredToken(), // Implementar
  );
  
  // 4. Inicializar FCM
  await FCMSyncService.instance.initialize(
    onSyncCallback: (entity) async {
      debugPrint('🔄 FCM Trigger recebido para: $entity');
      
      // Executar delta sync
      try {
        final count = await syncRepository.syncProductsIncremental();
        debugPrint('✅ Sync concluída: $count produtos atualizados');
      } catch (e) {
        debugPrint('❌ Erro na sync: $e');
      }
    },
  );
  
  runApp(const MyApp());
}

String _getStoredToken() {
  // Implementar: buscar token JWT do SharedPreferences
  return 'YOUR_JWT_TOKEN';
}
```

### 3.2 Criar Service Locator (Opcional)

Para facilitar acesso aos serviços:

```dart
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  static ServiceLocator get instance => _instance;
  
  ServiceLocator._internal();
  
  late Isar isar;
  late ProductSyncRepository syncRepository;
  late FCMSyncService fcmService;
  
  Future<void> init() async {
    // Inicializar todos os serviços
  }
}
```

---

## 4. FLUXO DE SINCRONIZAÇÃO

### 4.1 Sync Inicial (Download Completo)

Quando usuário faz login pela primeira vez:

```dart
import 'services/sync_isolate_manager.dart';

class InitialSyncScreen extends StatefulWidget {
  @override
  _InitialSyncScreenState createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends State<InitialSyncScreen> {
  final _isolateManager = SyncIsolateManager();
  int _progress = 0;
  int _total = 0;
  
  @override
  void initState() {
    super.initState();
    _startSync();
  }
  
  Future<void> _startSync() async {
    final dir = await getApplicationDocumentsDirectory();
    
    await _isolateManager.startFullSyncInBackground(
      apiBaseUrl: 'https://sua-api.com',
      authToken: await _getToken(),
      isarPath: dir.path,
      progressCallback: (current, total, status) {
        setState(() {
          _progress = current;
          _total = total;
        });
      },
      completeCallback: (success, message) {
        if (success) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $message')),
          );
        }
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Sincronizando: $_progress / $_total'),
            if (_total > 0)
              LinearProgressIndicator(
                value: _progress / _total,
              ),
          ],
        ),
      ),
    );
  }
}
```

### 4.2 Delta Sync (Incremental)

Chamado automaticamente pelo FCM:

```dart
// O FCM service já está configurado para chamar automaticamente
// Mas você pode forçar uma sync manual:

Future<void> manualSync() async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Sincronizando...'),
          ],
        ),
      ),
    );
    
    final count = await syncRepository.syncProductsIncremental();
    
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $count produtos atualizados')),
    );
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Erro: $e')),
    );
  }
}
```

### 4.3 Upload de Mudanças Locais

Quando usuário edita um produto:

```dart
Future<void> updateProduct(ProductIsar product) async {
  try {
    // 1. Atualizar no banco local
    await isar.writeTxn(() async {
      product.updatedAt = DateTime.now().toUtc();
      product.hasPendingChanges = true;
      product.version++;
      await isar.productIsars.put(product);
    });
    
    // 2. Tentar enviar para servidor (se online)
    if (await _isOnline()) {
      await syncRepository.uploadPendingChanges();
    } else {
      // Se offline, será enviado quando voltar online
      debugPrint('⚠️ Offline: mudanças salvas localmente');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Produto atualizado')),
    );
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Erro: $e')),
    );
  }
}

Future<bool> _isOnline() async {
  // Implementar verificação de conectividade
  // Ex: usar connectivity_plus package
  return true;
}
```

---

## 5. RESOLUÇÃO DE CONFLITOS

### 5.1 Estratégia: Last-Write-Wins (Baseado em Timestamp)

O código já implementa isso em `_applyProductChanges`:

```dart
if (product.updatedAt.isAfter(existing.updatedAt)) {
  // Servidor tem versão mais recente
  existing.updateFrom(product);
} else {
  // Local tem versão mais recente (manter local)
}
```

### 5.2 Estratégia Avançada: Conflict UI

Para casos onde você quer que o usuário escolha:

```dart
class ConflictResolutionDialog extends StatelessWidget {
  final ProductIsar localVersion;
  final ProductIsar serverVersion;
  
  const ConflictResolutionDialog({
    required this.localVersion,
    required this.serverVersion,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Conflito Detectado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('O produto foi alterado em outro dispositivo.'),
          SizedBox(height: 20),
          
          // Versão Local
          Card(
            child: ListTile(
              title: Text('Versão Local'),
              subtitle: Text(
                'Preço: ${localVersion.price}\n'
                'Editado: ${localVersion.updatedAt}'
              ),
              trailing: ElevatedButton(
                onPressed: () => Navigator.pop(context, 'local'),
                child: Text('Usar'),
              ),
            ),
          ),
          
          // Versão Servidor
          Card(
            child: ListTile(
              title: Text('Versão do Servidor'),
              subtitle: Text(
                'Preço: ${serverVersion.price}\n'
                'Editado: ${serverVersion.updatedAt}'
              ),
              trailing: ElevatedButton(
                onPressed: () => Navigator.pop(context, 'server'),
                child: Text('Usar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. PERFORMANCE E OTIMIZAÇÕES

### 6.1 Batch Operations

Sempre use `putAll()` para múltiplas inserções:

```dart
// ❌ LENTO - Evite
for (var product in products) {
  await isar.productIsars.put(product);
}

// ✅ RÁPIDO - Use isso
await isar.productIsars.putAll(products);
```

### 6.2 Índices Eficientes

Os índices já estão definidos no modelo:

```dart
@Index()  // Índice simples
late DateTime updatedAt;

@Index(unique: true)  // Índice único
late String serverId;
```

### 6.3 Queries Otimizadas

Use filtros eficientes:

```dart
// ✅ BOM - Usa índice
final products = await isar.productIsars
  .filter()
  .updatedAt.greaterThan(since)  // Usa índice
  .findAll();

// ❌ RUIM - Sem índice
final products = await isar.productIsars
  .where()
  .anyProductName((q) => q.contains('vinho'))  // Scan completo
  .findAll();
```

### 6.4 Compactação do Banco

Execute periodicamente:

```dart
await isar.writeTxn(() async {
  await isar.productIsars
    .filter()
    .isDeletedEqualTo(true)
    .and()
    .lastSyncedAt.lessThan(
      DateTime.now().subtract(Duration(days: 30))
    )
    .deleteAll();
});
```

---

## 7. TROUBLESHOOTING

### 7.1 FCM não está funcionando

**Problema:** Mensagens não chegam

**Soluções:**
```dart
// 1. Verificar se o token está sendo enviado
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// 2. Testar no Firebase Console
// Ir em Cloud Messaging → Send test message

// 3. Verificar logs no Logcat (Android)
// adb logcat | grep FCM

// 4. Verificar se app está em foreground vs background
FirebaseMessaging.instance.getInitialMessage().then((message) {
  if (message != null) {
    print('App opened from terminated state');
  }
});
```

### 7.2 Sync Lenta

**Problema:** Demora muito para sincronizar

**Soluções:**
- Implementar paginação menor (500 items por página)
- Usar compressão gzip nas respostas HTTP
- Verificar índices no banco de dados
- Usar Isolates para parsing JSON

### 7.3 Conflitos de Merge

**Problema:** Produtos sendo sobrescritos incorretamente

**Solução:**
```dart
// Adicionar logs detalhados
debugPrint('Conflito detectado:');
debugPrint('  Local: ${local.updatedAt} (v${local.version})');
debugPrint('  Server: ${server.updatedAt} (v${server.version})');

// Usar campo version além do timestamp
if (server.version > local.version) {
  // Servidor mais recente
} else if (server.version == local.version && 
           server.updatedAt.isAfter(local.updatedAt)) {
  // Mesma versão mas timestamp mais recente
}
```

### 7.4 Erro: "Isar already opened"

**Problema:** Tentativa de abrir Isar múltiplas vezes

**Solução:**
```dart
// Usar singleton
class IsarService {
  static Isar? _instance;
  
  static Future<Isar> getInstance() async {
    if (_instance != null) return _instance!;
    
    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      [ProductIsarSchema, SyncMetadataSchema],
      directory: dir.path,
    );
    
    return _instance!;
  }
}
```

---

## 🎯 CHECKLIST FINAL

- [ ] Firebase configurado (Android + iOS)
- [ ] Isar code generation executado
- [ ] FCM Service inicializado no main.dart
- [ ] Backend API configurada
- [ ] Teste de sync inicial (50k produtos)
- [ ] Teste de delta sync
- [ ] Teste de upload de mudanças
- [ ] Teste em múltiplos dispositivos simultâneos
- [ ] Teste offline/online
- [ ] Performance testada (> 1000 items/segundo)

---

## 📚 RECURSOS ADICIONAIS

- [Isar Documentation](https://isar.dev)
- [Firebase Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Isolates](https://dart.dev/guides/language/concurrency)
- [PostgreSQL Optimization](https://wiki.postgresql.org/wiki/Performance_Optimization)

---

**Agora você tem tudo para implementar uma sincronização robusta e eficiente! 🎉**
