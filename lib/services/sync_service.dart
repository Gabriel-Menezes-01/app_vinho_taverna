import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/wine.dart';
import 'database_service.dart';

class SyncService {
  final DatabaseService _dbService;
  final bool firebaseEnabled;
  FirebaseFirestore? _firestore;
  int? _currentUserId;
  String? _firebaseUid;

  SyncService(this._dbService, {this.firebaseEnabled = false}) {
    if (firebaseEnabled) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        print('Erro ao inicializar Firestore: $e');
      }
    }
  }

  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  void setFirebaseUid(String? firebaseUid) {
    _firebaseUid = firebaseUid;
  }

  String? get _remoteUserDocId {
    return _firebaseUid ?? _currentUserId?.toString();
  }

  // Verificar se há conexão com internet
  Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  // Sincronizar todos os dados
  Future<void> syncAll() async {
    if (!firebaseEnabled || _firestore == null) {
      print('Firebase não habilitado. Sincronização desativada.');
      return;
    }

    if (_currentUserId == null && _firebaseUid == null) {
      print('⚠️ Usuário não configurado para sincronização (faltando userId/firebaseUid)');
      return; // Não lançar exceção, apenas retornar
    }

    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      print('Sem conexão com internet. Sincronização adiada.');
      return;
    }

    try {
      print('🔄 Iniciando sincronização para usuário $_currentUserId');
      // 1. Enviar vinhos locais não sincronizados para o servidor
      await uploadUnsyncedWines();

      // 2. Baixar vinhos do servidor que não existem localmente
      await downloadWinesFromServer();

      print('✅ Sincronização concluída com sucesso!');
    } catch (e, stackTrace) {
      print('⚠️ Erro na sincronização: $e');
      print('Stack: $stackTrace');
      // NÃO lançar exceção aqui - apenas log
      // O app deve funcionar mesmo sem Firebase
    }
  }

  // Upload de vinhos não sincronizados
  Future<void> uploadUnsyncedWines() async {
    if (!firebaseEnabled || _firestore == null) {
      print('ℹ️ Firebase não habilitado - vinhos salvos apenas localmente');
      return;
    }
    if (_currentUserId == null && _firebaseUid == null) {
      print('⚠️ Usuário não configurado - não é possível sincronizar');
      return;
    }

    final remoteUserDoc = _remoteUserDocId;
    if (remoteUserDoc == null || remoteUserDoc.isEmpty) {
      print('⚠️ ID de usuário remoto inválido');
      return;
    }

    final unsyncedWines = await _dbService.getUnsyncedWines(_currentUserId!);

    if (unsyncedWines.isEmpty) {
      print('✓ Nenhum vinho pendente de sincronização');
      return;
    }

    print('📤 Enviando ${unsyncedWines.length} vinhos para Firestore (usuário: $remoteUserDoc)...');

    int successCount = 0;
    for (final wine in unsyncedWines) {
      try {
        // Salvar no Firestore na coleção do usuário com timeout
        await _firestore!
            .collection('users')
          .doc(remoteUserDoc)
            .collection('wines')
            .doc(wine.id)
            .set(wine.toFirestore(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 10), onTimeout: () {
              throw Exception('Timeout ao sincronizar vinho ${wine.name}');
            });

        // Marcar como sincronizado localmente
        await _dbService.markWineAsSynced(wine.id, _currentUserId!);
        successCount++;

        print('  ✅ ${wine.name} → Firestore');
      } catch (e) {
        print('  ⚠️ Erro ao sincronizar ${wine.name}: $e');
        // Continuar sincronizando os outros vinhos
      }
    }
    
    print('📤 Upload completo: $successCount/${unsyncedWines.length} vinhos sincronizados');
  }

  // Download de vinhos do servidor usando firebaseUid (para sincronização entre dispositivos)
  Future<void> downloadWinesFromFirebase(String firebaseUid, int localUserId) async {
    if (!firebaseEnabled || _firestore == null) {
      print('Firebase não habilitado para sincronização');
      return;
    }

    print('🔄 Sincronizando vinhos do Firebase para usuário $firebaseUid...');

    try {
      // Buscar vinhos do servidor usando firebaseUid
      final snapshot = await _firestore!
          .collection('users')
          .doc(firebaseUid)
          .collection('wines')
          .get()
          .timeout(const Duration(seconds: 15));

      // Obter IDs dos vinhos locais
      final localWines = await _dbService.getWinesByUser(localUserId);
      final localWineIds = localWines.map((w) => w.id).toSet();

      int newWinesCount = 0;
      int updatedWinesCount = 0;

      for (final doc in snapshot.docs) {
        final serverWine = Wine.fromFirestore(doc.data());

        // Se o vinho não existe localmente, adicionar
        if (!localWineIds.contains(serverWine.id)) {
          await _dbService.insertWine(serverWine, localUserId);
          await _dbService.markWineAsSynced(serverWine.id, localUserId);
          newWinesCount++;
          print('✅ Vinho ${serverWine.name} baixado do servidor!');
        } else {
          // Verificar se o vinho do servidor é mais recente
          final localWine = localWines.firstWhere((w) => w.id == serverWine.id);
          if (serverWine.lastModified != null &&
              localWine.lastModified != null &&
              serverWine.lastModified!.isAfter(localWine.lastModified!)) {
            // Atualizar com dados mais recentes do servidor
            await _dbService.updateWine(serverWine, localUserId);
            await _dbService.markWineAsSynced(serverWine.id, localUserId);
            updatedWinesCount++;
            print('✅ Vinho ${serverWine.name} atualizado com dados do servidor!');
          }
        }
      }

      print('🎉 Sincronização completa: $newWinesCount novos, $updatedWinesCount atualizados');
    } catch (e) {
      print('⚠️ Erro ao sincronizar vinhos do Firebase: $e');
    }
  }

  // Download de vinhos do servidor
  Future<void> downloadWinesFromServer() async {
    if (!firebaseEnabled || _firestore == null) {
      print('ℹ️ Firebase não habilitado - usando apenas dados locais');
      return;
    }
    if (_currentUserId == null && _firebaseUid == null) {
      print('⚠️ Usuário não configurado - não é possível baixar vinhos');
      return;
    }

    final remoteUserDoc = _remoteUserDocId;
    if (remoteUserDoc == null || remoteUserDoc.isEmpty) {
      print('⚠️ ID de usuário remoto inválido');
      return;
    }

    print('📥 Buscando vinhos do Firestore (usuário: $remoteUserDoc)...');

    try {
      // Buscar vinhos do servidor
      final snapshot = await _firestore!
          .collection('users')
          .doc(remoteUserDoc)
          .collection('wines')
          .get()
          .timeout(const Duration(seconds: 15));

      print('📥 Encontrados ${snapshot.docs.length} vinhos no Firestore');

      // Obter IDs dos vinhos locais
      final localWines = await _dbService.getWinesByUser(_currentUserId!);
      final localWineIds = localWines.map((w) => w.id).toSet();

      int newWinesCount = 0;
      int updatedWinesCount = 0;

      for (final doc in snapshot.docs) {
        try {
          final serverWine = Wine.fromFirestore(doc.data());

          // Se o vinho não existe localmente, adicionar
          if (!localWineIds.contains(serverWine.id)) {
            await _dbService.insertWine(serverWine, _currentUserId!);
            await _dbService.markWineAsSynced(serverWine.id, _currentUserId!);
            newWinesCount++;
            print('  ✅ ${serverWine.name} → Local (novo)');
          } else {
            // Verificar se o vinho do servidor é mais recente
            final localWine = localWines.firstWhere((w) => w.id == serverWine.id);
            if (serverWine.lastModified != null &&
                localWine.lastModified != null &&
                serverWine.lastModified!.isAfter(localWine.lastModified!)) {
              // Atualizar com dados mais recentes do servidor
              await _dbService.updateWine(serverWine, _currentUserId!);
              await _dbService.markWineAsSynced(serverWine.id, _currentUserId!);
              updatedWinesCount++;
              print('  ✅ ${serverWine.name} → Local (atualizado)');
            }
          }
        } catch (e) {
          print('  ⚠️ Erro ao processar vinho: $e');
        }
      }

      print('📥 Download completo: $newWinesCount novos, $updatedWinesCount atualizados');
    } catch (e) {
      print('❌ Erro ao baixar vinhos do Firestore: $e');
      // Não lançar exceção - app deve funcionar offline
    }
  }

  // Deletar vinho do servidor
  Future<void> deleteWineFromServer(String wineId) async {
    if (!firebaseEnabled || _firestore == null) return;
    if (_currentUserId == null && _firebaseUid == null) return;

    final remoteUserDoc = _remoteUserDocId;
    if (remoteUserDoc == null || remoteUserDoc.isEmpty) return;

    try {
      await _firestore!
          .collection('users')
          .doc(remoteUserDoc)
          .collection('wines')
          .doc(wineId)
          .delete();

      print('Vinho deletado do servidor!');
    } catch (e) {
      print('Erro ao deletar vinho do servidor: $e');
    }
  }

  // Sincronizar automaticamente quando a conectividade mudar
  Stream<bool> watchConnectivity() {
    return Connectivity().onConnectivityChanged.map((result) {
      return result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi);
    });
  }
}
