import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform;

// Services
import 'services/fcm_sync_service.dart';
import 'services/product_sync_repository.dart';
import 'services/database_service.dart';

// Models
import 'models/product_isar.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

/// ============================================================================
/// MAIN - EXEMPLO COMPLETO COM SINCRONIZAÇÃO
/// ============================================================================

// Instâncias globais (use Dependency Injection em produção)
late Isar isar;
late ProductSyncRepository syncRepository;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // =========================================================================
    // 1. INICIALIZAR SQFLITE FFI (para Windows/Linux)
    // =========================================================================
    if (Platform.isWindows || Platform.isLinux) {
      await DatabaseService.initializeFFI();
      debugPrint('✅ SQLite FFI inicializado');
    }

    // =========================================================================
    // 2. INICIALIZAR FIREBASE (Opcional para modo offline)
    // =========================================================================
    bool firebaseInitialized = false;
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
      debugPrint('✅ Firebase inicializado');
    } catch (e) {
      debugPrint('⚠️ Firebase não configurado (continuando em modo offline): $e');
    }

    // =========================================================================
    // 3. INICIALIZAR ISAR DATABASE (para produtos com sync)
    // =========================================================================
    final dir = await getApplicationDocumentsDirectory();
    
    isar = await Isar.open(
      [ProductIsarSchema, SyncMetadataSchema],
      directory: dir.path,
      name: 'app_sync_database',
      inspector: true, // Habilita Isar Inspector para debug
    );
    
    debugPrint('✅ Isar Database inicializado em: ${dir.path}');
    
    // =========================================================================
    // 4. INICIALIZAR SYNC REPOSITORY
    // =========================================================================
    syncRepository = ProductSyncRepository(
      isar: isar,
      apiBaseUrl: 'https://sua-api.com', // TODO: Substituir pela sua API
      getAuthToken: () {
        // TODO: Implementar - buscar token do SharedPreferences
        return 'YOUR_JWT_TOKEN_HERE';
      },
    );
    
    debugPrint('✅ Sync Repository inicializado');

    // =========================================================================
    // 5. INICIALIZAR FCM (se Firebase disponível)
    // =========================================================================
    if (firebaseInitialized) {
      await FCMSyncService.instance.initialize(
        onSyncCallback: (entity) async {
          debugPrint('🔔 FCM Trigger recebido para: $entity');
          
          try {
            // Executar delta sync em background
            final updatedCount = await syncRepository.syncProductsIncremental();
            debugPrint('✅ Sync concluída: $updatedCount produtos atualizados');
            
            // Opcional: Mostrar notificação in-app
            // _showSyncNotification(updatedCount);
            
          } catch (e) {
            debugPrint('❌ Erro no sync automático: $e');
          }
        },
      );
      
      debugPrint('✅ FCM Service configurado');
    }

    // =========================================================================
    // 6. EXECUTAR APP
    // =========================================================================
    runApp(MyApp(
      syncEnabled: firebaseInitialized,
    ));

  } catch (e, stackTrace) {
    debugPrint('❌ Erro fatal na inicialização: $e');
    debugPrint(stackTrace.toString());
    
    // Mostrar tela de erro
    runApp(ErrorApp(error: e.toString()));
  }
}

/// ============================================================================
/// APP PRINCIPAL
/// ============================================================================

class MyApp extends StatelessWidget {
  final bool syncEnabled;

  const MyApp({
    Key? key,
    required this.syncEnabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Vinho Taverna',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      
      darkTheme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      
      // Rotas
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/sync': (context) => SyncScreen(
          syncRepository: syncRepository,
          onComplete: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      },
      
      // Banner de modo offline (se FCM não disponível)
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            if (!syncEnabled)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.orange,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '⚠️ Modo Offline - Sincronização desativada',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ============================================================================
/// TELA DE SINCRONIZAÇÃO INICIAL
/// ============================================================================

class SyncScreen extends StatefulWidget {
  final ProductSyncRepository syncRepository;
  final VoidCallback onComplete;

  const SyncScreen({
    Key? key,
    required this.syncRepository,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  int _currentProgress = 0;
  int _totalItems = 0;
  String _status = 'Iniciando sincronização...';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    try {
      // Verificar se sync inicial já foi feita
      final isComplete = await widget.syncRepository.isInitialSyncComplete();
      
      if (isComplete) {
        debugPrint('ℹ️  Sync inicial já completa, apenas atualizando...');
        setState(() => _status = 'Verificando atualizações...');
        
        final count = await widget.syncRepository.syncProductsIncremental();
        debugPrint('✅ $count produtos atualizados');
        
        widget.onComplete();
        return;
      }

      // Sync inicial completa
      setState(() => _status = 'Baixando catálogo completo...');
      
      await widget.syncRepository.syncInitialFull(
        onProgress: (current, total) {
          setState(() {
            _currentProgress = current;
            _totalItems = total;
            _status = 'Baixando produtos...';
          });
        },
      );

      setState(() => _status = 'Sincronização concluída!');
      
      // Aguardar um pouco para mostrar sucesso
      await Future.delayed(const Duration(seconds: 1));
      
      widget.onComplete();

    } catch (e, stackTrace) {
      debugPrint('❌ Erro na sincronização: $e');
      debugPrint(stackTrace.toString());
      
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _status = 'Erro na sincronização';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalItems > 0 
        ? _currentProgress / _totalItems 
        : 0.0;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone
              if (!_hasError)
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                  ),
                )
              else
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),

              const SizedBox(height: 32),

              // Status
              Text(
                _status,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Progress bar
              if (_totalItems > 0 && !_hasError) ...[
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  '$_currentProgress / $_totalItems produtos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],

              // Erro
              if (_hasError && _errorMessage != null) ...[
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                    });
                    _startSync();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                ),
                
                TextButton(
                  onPressed: widget.onComplete,
                  child: const Text('Continuar Offline'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// TELA DE ERRO
/// ============================================================================

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Erro ao inicializar app',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
