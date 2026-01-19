import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../models/product_isar.dart';
import 'product_sync_repository.dart';

/// ============================================================================
/// ISOLATE WORKER PARA SINCRONIZAÇÃO PESADA
/// ============================================================================
/// 
/// Esta classe gerencia um Isolate separado para realizar operações pesadas
/// de sincronização (como baixar e inserir 50.000+ produtos) sem travar a UI.
/// 
/// O Isolate roda em uma thread separada e se comunica via SendPort/ReceivePort

class SyncIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  
  /// Callback para progresso
  Function(int current, int total, String status)? onProgress;
  
  /// Callback para conclusão
  Function(bool success, String message)? onComplete;
  
  /// Inicia um sync completo em um isolate separado
  Future<void> startFullSyncInBackground({
    required String apiBaseUrl,
    required String authToken,
    required String isarPath,
    required Function(int current, int total, String status) progressCallback,
    required Function(bool success, String message) completeCallback,
  }) async {
    onProgress = progressCallback;
    onComplete = completeCallback;
    
    debugPrint('🚀 Iniciando Isolate para Sync Completo...');
    
    // Criar ReceivePort para receber mensagens do isolate
    _receivePort = ReceivePort();
    
    // Parâmetros para o isolate
    final params = SyncIsolateParams(
      apiBaseUrl: apiBaseUrl,
      authToken: authToken,
      isarPath: isarPath,
      sendPort: _receivePort!.sendPort,
    );
    
    // Spawn isolate
    _isolate = await Isolate.spawn(
      _syncIsolateEntryPoint,
      params,
      debugName: 'SyncWorker',
    );
    
    // Escutar mensagens do isolate
    _receivePort!.listen((message) {
      if (message is SyncProgressMessage) {
        onProgress?.call(message.current, message.total, message.status);
      } else if (message is SyncCompleteMessage) {
        onComplete?.call(message.success, message.message);
        _cleanup();
      }
    });
  }
  
  /// Entry point do isolate (deve ser top-level ou static)
  static Future<void> _syncIsolateEntryPoint(SyncIsolateParams params) async {
    try {
      debugPrint('🔧 [Isolate] Iniciando...');
      
      // 1. Abrir Isar no isolate (cada isolate precisa da própria instância)
      final isar = await Isar.open(
        [ProductIsarSchema, SyncMetadataSchema],
        directory: params.isarPath,
        name: 'sync_worker',
      );
      
      debugPrint('📂 [Isolate] Isar aberto');
      
      // 2. Criar repository
      final repository = ProductSyncRepository(
        isar: isar,
        apiBaseUrl: params.apiBaseUrl,
        getAuthToken: () => params.authToken,
      );
      
      // 3. Executar sync completa
      await repository.syncInitialFull(
        onProgress: (current, total) {
          // Enviar progresso para a UI
          params.sendPort.send(SyncProgressMessage(
            current: current,
            total: total,
            status: 'Baixando produtos...',
          ));
        },
      );
      
      // 4. Enviar mensagem de conclusão
      params.sendPort.send(SyncCompleteMessage(
        success: true,
        message: 'Sincronização completa com sucesso!',
      ));
      
      debugPrint('✅ [Isolate] Concluído');
      
      // Fechar Isar
      await isar.close();
      
    } catch (e, stackTrace) {
      debugPrint('❌ [Isolate] Erro: $e');
      debugPrint(stackTrace.toString());
      
      params.sendPort.send(SyncCompleteMessage(
        success: false,
        message: 'Erro: $e',
      ));
    }
  }
  
  /// Limpa recursos
  void _cleanup() {
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort = null;
    _isolate = null;
    _sendPort = null;
  }
  
  /// Cancela o isolate
  void cancel() {
    debugPrint('🛑 Cancelando Isolate...');
    _cleanup();
  }
}

// ============================================================================
// MENSAGENS ENTRE ISOLATES
// ============================================================================

/// Parâmetros passados para o isolate
class SyncIsolateParams {
  final String apiBaseUrl;
  final String authToken;
  final String isarPath;
  final SendPort sendPort;
  
  SyncIsolateParams({
    required this.apiBaseUrl,
    required this.authToken,
    required this.isarPath,
    required this.sendPort,
  });
}

/// Mensagem de progresso
class SyncProgressMessage {
  final int current;
  final int total;
  final String status;
  
  SyncProgressMessage({
    required this.current,
    required this.total,
    required this.status,
  });
}

/// Mensagem de conclusão
class SyncCompleteMessage {
  final bool success;
  final String message;
  
  SyncCompleteMessage({
    required this.success,
    required this.message,
  });
}

// ============================================================================
// EXEMPLO DE USO NO FLUTTER
// ============================================================================

/// Widget que mostra progresso da sync
class SyncProgressScreen extends StatefulWidget {
  const SyncProgressScreen({Key? key}) : super(key: key);
  
  @override
  State<SyncProgressScreen> createState() => _SyncProgressScreenState();
}

class _SyncProgressScreenState extends State<SyncProgressScreen> {
  final _isolateManager = SyncIsolateManager();
  
  int _currentProgress = 0;
  int _totalItems = 0;
  String _status = 'Preparando...';
  bool _isComplete = false;
  
  @override
  void initState() {
    super.initState();
    _startSync();
  }
  
  Future<void> _startSync() async {
    // Obter path do Isar
    final isarPath = await _getIsarPath();
    
    await _isolateManager.startFullSyncInBackground(
      apiBaseUrl: 'https://sua-api.com',
      authToken: 'seu-token-aqui',
      isarPath: isarPath,
      progressCallback: (current, total, status) {
        setState(() {
          _currentProgress = current;
          _totalItems = total;
          _status = status;
        });
      },
      completeCallback: (success, message) {
        setState(() {
          _isComplete = true;
          _status = message;
        });
        
        if (success) {
          // Navegar para tela principal
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
    );
  }
  
  Future<String> _getIsarPath() async {
    // Implementar obtenção do path
    // Ex: final dir = await getApplicationDocumentsDirectory();
    // return dir.path;
    return '';
  }
  
  @override
  void dispose() {
    _isolateManager.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final progress = _totalItems > 0 ? _currentProgress / _totalItems : 0.0;
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 32),
              
              Text(
                _status,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              
              if (_totalItems > 0) ...[
                const SizedBox(height: 24),
                
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '$_currentProgress / $_totalItems produtos',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
              
              if (_isComplete) ...[
                const SizedBox(height: 24),
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DICAS DE OTIMIZAÇÃO
// ============================================================================

/// Para melhor performance em grandes volumes:
/// 
/// 1. BATCH OPERATIONS
///    - Use putAll() ao invés de múltiplos put()
///    - Agrupe em batches de 1000-5000 itens
/// 
/// 2. COMPACTAÇÃO
///    - Use isar.writeTxn() para agrupar múltiplas escritas
///    - Minimize o número de transações
/// 
/// 3. ÍNDICES
///    - Crie índices apenas nos campos usados para queries
///    - Evite índices desnecessários (degradam performance de escrita)
/// 
/// 4. PARSING JSON
///    - Faça o parsing no isolate, não na UI thread
///    - Use compute() para operações menores
/// 
/// 5. MEMORY
///    - Processe em chunks (páginas) ao invés de tudo de uma vez
///    - Libere objetos grandes após uso
/// 
/// 6. NETWORK
///    - Use compressão gzip nas respostas HTTP
///    - Implemente retry com backoff exponencial
///    - Considere HTTP/2 para múltiplas requests simultâneas
