import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import '../models/product_isar.dart';

/// ============================================================================
/// REPOSITORY DE SINCRONIZAÇÃO DE PRODUTOS
/// ============================================================================
/// 
/// Responsável por toda a lógica de sincronização entre servidor e banco local:
/// - Delta Sync (baixar apenas o que mudou)
/// - Batch operations (inserções em lote eficientes)
/// - Conflict resolution (baseado em timestamp)
/// - Upload de mudanças locais

class ProductSyncRepository {
  final Isar isar;
  final String apiBaseUrl;
  final String Function() getAuthToken;
  
  ProductSyncRepository({
    required this.isar,
    required this.apiBaseUrl,
    required this.getAuthToken,
  });
  
  // ============================================================================
  // DELTA SYNC - DOWNLOAD INCREMENTAL
  // ============================================================================
  
  /// Sincroniza produtos alterados desde a última sync
  /// 
  /// Este é o método principal chamado pelo FCM handler
  /// Retorna o número de produtos atualizados
  Future<int> syncProductsIncremental() async {
    try {
      debugPrint('🔄 Iniciando Delta Sync...');
      
      // 1. Obter timestamp da última sincronização
      final lastSyncTime = await _getLastSyncTimestamp();
      debugPrint('⏰ Última sync: ${lastSyncTime?.toIso8601String() ?? "NUNCA"}');
      
      // 2. Buscar produtos modificados desde então
      final changedProducts = await _fetchChangedProducts(lastSyncTime);
      debugPrint('📥 Recebidos ${changedProducts.length} produtos alterados');
      
      if (changedProducts.isEmpty) {
        debugPrint('✅ Nada para sincronizar');
        return 0;
      }
      
      // 3. Aplicar mudanças no banco local (batch operation)
      final updatedCount = await _applyProductChanges(changedProducts);
      
      // 4. Atualizar timestamp da última sync
      await _updateLastSyncTimestamp(DateTime.now().toUtc());
      
      debugPrint('✅ Delta Sync concluída: $updatedCount produtos atualizados');
      return updatedCount;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erro no Delta Sync: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }
  
  /// Busca produtos modificados desde um timestamp
  Future<List<ProductIsar>> _fetchChangedProducts(DateTime? since) async {
    try {
      // Montar URL com query parameter
      final queryParams = since != null 
          ? '?since=${since.toIso8601String()}'
          : ''; // Se null, pega tudo (sync inicial)
      
      final url = Uri.parse('$apiBaseUrl/api/products/sync$queryParams');
      
      debugPrint('📡 GET $url');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${getAuthToken()}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('Erro na API: ${response.statusCode} - ${response.body}');
      }
      
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final productsJson = jsonData['products'] as List<dynamic>;
      
      // Converter JSON para ProductIsar
      return productsJson
          .map((json) => ProductIsar.fromJson(json as Map<String, dynamic>))
          .toList();
          
    } catch (e) {
      debugPrint('❌ Erro ao buscar produtos: $e');
      rethrow;
    }
  }
  
  /// Aplica mudanças no banco local usando batch operation
  Future<int> _applyProductChanges(List<ProductIsar> products) async {
    int updatedCount = 0;
    
    await isar.writeTxn(() async {
      for (final product in products) {
        // Verificar se produto já existe no banco local
        final existing = await isar.productIsars
            .filter()
            .serverIdEqualTo(product.serverId)
            .findFirst();
        
        if (existing != null) {
          // CONFLICT RESOLUTION: Comparar timestamps
          if (product.updatedAt.isAfter(existing.updatedAt)) {
            // Produto do servidor é mais recente
            existing.updateFrom(product);
            existing.lastSyncedAt = DateTime.now().toUtc();
            existing.hasPendingChanges = false;
            await isar.productIsars.put(existing);
            updatedCount++;
            debugPrint('  📝 Atualizado: ${product.name}');
          } else {
            // Produto local é mais recente ou igual
            debugPrint('  ⏭️  Ignorado (local mais recente): ${product.name}');
          }
        } else {
          // Produto novo - inserir
          product.lastSyncedAt = DateTime.now().toUtc();
          await isar.productIsars.put(product);
          updatedCount++;
          debugPrint('  ➕ Inserido: ${product.name}');
        }
      }
    });
    
    return updatedCount;
  }
  
  // ============================================================================
  // SYNC INICIAL - DOWNLOAD COMPLETO EM BACKGROUND
  // ============================================================================
  
  /// Faz o download inicial de TODOS os produtos
  /// Para grandes volumes (50k+), use paginação
  Future<void> syncInitialFull({
    required Function(int current, int total) onProgress,
  }) async {
    try {
      debugPrint('🔄 Iniciando Sync Inicial Completa...');
      
      // 1. Obter total de produtos e páginas
      final metadata = await _fetchSyncMetadata();
      final totalProducts = metadata['total_products'] as int;
      final pageSize = metadata['page_size'] as int? ?? 1000;
      final totalPages = (totalProducts / pageSize).ceil();
      
      debugPrint('📊 Total: $totalProducts produtos em $totalPages páginas');
      
      int processedCount = 0;
      
      // 2. Baixar página por página
      for (int page = 1; page <= totalPages; page++) {
        debugPrint('📄 Baixando página $page/$totalPages...');
        
        final pageProducts = await _fetchProductsPage(page, pageSize);
        
        // Inserir em batch
        await _batchInsertProducts(pageProducts);
        
        processedCount += pageProducts.length;
        onProgress(processedCount, totalProducts);
        
        debugPrint('  ✅ Página $page processada ($processedCount/$totalProducts)');
      }
      
      // 3. Marcar sync inicial como concluída
      await _markInitialSyncComplete();
      await _updateLastSyncTimestamp(DateTime.now().toUtc());
      
      debugPrint('🎉 Sync Inicial Completa! Total: $processedCount produtos');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erro na Sync Inicial: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }
  
  /// Busca metadata da sincronização (total de registros, etc)
  Future<Map<String, dynamic>> _fetchSyncMetadata() async {
    final url = Uri.parse('$apiBaseUrl/api/products/sync/metadata');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${getAuthToken()}',
      },
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar metadata: ${response.statusCode}');
    }
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  /// Busca uma página de produtos
  Future<List<ProductIsar>> _fetchProductsPage(int page, int pageSize) async {
    final url = Uri.parse(
      '$apiBaseUrl/api/products?page=$page&limit=$pageSize',
    );
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer ${getAuthToken()}',
      },
    ).timeout(const Duration(seconds: 30));
    
    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar página: ${response.statusCode}');
    }
    
    final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
    final productsJson = jsonData['products'] as List<dynamic>;
    
    return productsJson
        .map((json) => ProductIsar.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  /// Insere produtos em batch (muito mais rápido que individualmente)
  Future<void> _batchInsertProducts(List<ProductIsar> products) async {
    await isar.writeTxn(() async {
      // putAll é MUITO mais eficiente que múltiplos put()
      await isar.productIsars.putAll(products);
    });
  }
  
  // ============================================================================
  // UPLOAD - ENVIAR MUDANÇAS LOCAIS PARA O SERVIDOR
  // ============================================================================
  
  /// Envia mudanças locais pendentes para o servidor
  /// Retorna o número de produtos sincronizados
  Future<int> uploadPendingChanges() async {
    try {
      debugPrint('⬆️  Enviando mudanças locais...');
      
      // 1. Buscar produtos com mudanças pendentes
      final pendingProducts = await isar.productIsars
          .filter()
          .hasPendingChangesEqualTo(true)
          .findAll();
      
      if (pendingProducts.isEmpty) {
        debugPrint('  ✅ Nenhuma mudança pendente');
        return 0;
      }
      
      debugPrint('  📤 ${pendingProducts.length} produtos para enviar');
      
      // 2. Enviar para o servidor (pode ser em batch ou individual)
      int successCount = 0;
      
      for (final product in pendingProducts) {
        try {
          await _uploadProduct(product);
          
          // Marcar como sincronizado
          await isar.writeTxn(() async {
            product.hasPendingChanges = false;
            product.lastSyncedAt = DateTime.now().toUtc();
            await isar.productIsars.put(product);
          });
          
          successCount++;
          debugPrint('    ✅ Enviado: ${product.name}');
          
        } catch (e) {
          debugPrint('    ❌ Erro ao enviar ${product.name}: $e');
          // Continua tentando os outros
        }
      }
      
      debugPrint('⬆️  Upload concluído: $successCount/${pendingProducts.length}');
      return successCount;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erro no upload: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }
  
  /// Envia um produto para o servidor
  Future<void> _uploadProduct(ProductIsar product) async {
    final url = Uri.parse('$apiBaseUrl/api/products/${product.serverId}');
    
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer ${getAuthToken()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(product.toJson()),
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode != 200) {
      throw Exception('Erro ao enviar produto: ${response.statusCode}');
    }
    
    // Atualizar com dados do servidor (pode ter novo timestamp/version)
    final serverResponse = jsonDecode(response.body) as Map<String, dynamic>;
    product.updatedAt = DateTime.parse(serverResponse['updatedAt'] as String);
    product.version = serverResponse['version'] as int;
  }
  
  // ============================================================================
  // GERENCIAMENTO DE METADATA
  // ============================================================================
  
  /// Obtém o timestamp da última sincronização
  Future<DateTime?> _getLastSyncTimestamp() async {
    final metadata = await isar.syncMetadatas
        .filter()
        .keyEqualTo('products_last_sync')
        .findFirst();
    
    if (metadata == null) return null;
    return DateTime.parse(metadata.value);
  }
  
  /// Atualiza o timestamp da última sincronização
  Future<void> _updateLastSyncTimestamp(DateTime timestamp) async {
    await isar.writeTxn(() async {
      var metadata = await isar.syncMetadatas
          .filter()
          .keyEqualTo('products_last_sync')
          .findFirst();
      
      if (metadata == null) {
        metadata = SyncMetadata(
          key: 'products_last_sync',
          value: timestamp.toIso8601String(),
        );
      } else {
        metadata.value = timestamp.toIso8601String();
        metadata.updatedAt = DateTime.now().toUtc();
      }
      
      await isar.syncMetadatas.put(metadata);
    });
  }
  
  /// Verifica se a sync inicial foi completada
  Future<bool> isInitialSyncComplete() async {
    final metadata = await isar.syncMetadatas
        .filter()
        .keyEqualTo('initial_sync_completed')
        .findFirst();
    
    return metadata?.value == 'true';
  }
  
  /// Marca a sync inicial como completa
  Future<void> _markInitialSyncComplete() async {
    await isar.writeTxn(() async {
      await isar.syncMetadatas.put(
        SyncMetadata(
          key: 'initial_sync_completed',
          value: 'true',
        ),
      );
    });
  }
  
  // ============================================================================
  // QUERIES ÚTEIS
  // ============================================================================
  
  /// Conta produtos locais
  Future<int> getLocalProductCount() async {
    return await isar.productIsars.count();
  }
  
  /// Busca produtos com mudanças pendentes
  Future<List<ProductIsar>> getPendingProducts() async {
    return await isar.productIsars
        .filter()
        .hasPendingChangesEqualTo(true)
        .findAll();
  }
  
  /// Busca produtos por região
  Future<List<ProductIsar>> getProductsByRegion(String region) async {
    return await isar.productIsars
        .filter()
        .regionEqualTo(region)
        .and()
        .isDeletedEqualTo(false)
        .findAll();
  }
}
