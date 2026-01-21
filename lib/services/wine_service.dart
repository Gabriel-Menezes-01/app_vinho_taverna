import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wine.dart';
import '../models/user.dart';
import 'database_service.dart';
import 'sync_service.dart';

class WineService {
  final DatabaseService _dbService;
  final bool firebaseEnabled;
  final SyncService syncService;
  int? _currentUserId;
  String? _firebaseUid;
  String? _currentUserEmail;
  FirebaseFirestore? _firestore;

  WineService(this._dbService, {this.firebaseEnabled = false, required this.syncService}) {
    if (firebaseEnabled) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        print('Erro ao inicializar Firestore: $e');
      }
    }
  }

  // Definir usuário atual
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  // Definir usuário atual via email (resolve o id automaticamente)
  void setCurrentUserEmail(String email) {
    _currentUserEmail = email;
  }

  // Definir Firebase UID (para sincronização entre dispositivos)
  void setFirebaseUid(String? uid) {
    _firebaseUid = uid;
  }

  // Resolver userId: usa id já definido ou busca pelo email
  Future<int> _resolveUserId() async {
    if (_currentUserId != null) return _currentUserId!;

    if (_currentUserEmail != null) {
      final User? user = await _dbService.getUserByEmail(_currentUserEmail!);
      if (user != null && user.id != null) {
        _currentUserId = user.id;
        return _currentUserId!;
      }
    }

    throw Exception('Nenhum usuário está logado');
  }

  // Adicionar um vinho
  Future<void> addWine(Wine wine) async {
    print('🍷 Adicionando vinho: ${wine.name}');
    final userId = await _resolveUserId();
    
    // SEMPRE salvar no Firestore (se Firebase está habilitado)
    if (firebaseEnabled && _firestore != null && _firebaseUid != null) {
      print('☁️ Salvando direto no Firestore...');
      await _addWineToFirebase(wine);
    } else {
      // Fallback para SQLite se Firebase não disponível
      print('📱 Firebase não disponível, salvando localmente...');
      await _dbService.insertWine(wine, userId);
      print('✅ Vinho adicionado localmente');
    }
  }

  // Atualizar um vinho
  Future<void> updateWine(Wine wine) async {
    print('🍷 Atualizando vinho: ${wine.name}');
    final userId = await _resolveUserId();
    
    // SEMPRE atualizar no Firestore (se Firebase está habilitado)
    if (firebaseEnabled && _firestore != null && _firebaseUid != null) {
      print('☁️ Atualizando no Firestore...');
      await _updateWineInFirebase(wine);
    } else {
      // Fallback para SQLite se Firebase não disponível
      print('📱 Firebase não disponível, atualizando localmente...');
      await _dbService.updateWine(wine, userId);
      print('✅ Vinho atualizado localmente');
    }
  }

  // Excluir um vinho
  Future<void> deleteWine(String id) async {
    print('🗑️ Deletando vinho: $id');
    final userId = await _resolveUserId();
    
    // SEMPRE deletar no Firestore (se Firebase está habilitado)
    if (firebaseEnabled && _firestore != null && _firebaseUid != null) {
      print('☁️ Deletando do Firestore...');
      await _deleteWineFromFirebase(id);
    } else {
      // Fallback para SQLite se Firebase não disponível
      print('📱 Firebase não disponível, deletando localmente...');
      await _dbService.deleteWine(id, userId);
      print('✅ Vinho deletado localmente');
    }
  }

  // Obter um vinho pelo ID
  Future<Wine?> getWine(String id) async {
    final userId = await _resolveUserId();
    return await _dbService.getWineById(id, userId);
  }

  // Obter todos os vinhos do usuário atual (DO FIRESTORE)
  Future<List<Wine>> getAllWines() async {
    final userId = await _resolveUserId();
    
    // PRIORIDADE: Ler do Firestore
    if (firebaseEnabled && _firestore != null && _firebaseUid != null) {
      print('☁️ Buscando vinhos no Firestore...');
      try {
        final snapshot = await _firestore!
            .collection('users')
            .doc(_firebaseUid)
            .collection('wines')
            .get()
            .timeout(const Duration(seconds: 15));
        
        final wines = snapshot.docs
            .map((doc) => Wine.fromFirestore(doc.data()))
            .toList();
        
        print('✅ ${wines.length} vinhos carregados do Firestore');
        
        // Guardar no cache local para offline
        for (var wine in wines) {
          await _dbService.insertWine(wine, userId);
        }
        
        return wines;
      } catch (e) {
        print('⚠️ Erro ao ler do Firestore: $e, usando cache local');
        // Fallback para cache local
        return await _dbService.getWinesByUser(userId);
      }
    } else {
      // Fallback: ler do SQLite local
      print('📱 Firebase não disponível, usando cache local');
      return await _dbService.getWinesByUser(userId);
    }
  }

  // ==================== MÉTODOS PRIVADOS FIREBASE ====================

  // Adicionar vinho diretamente no Firebase
  Future<void> _addWineToFirebase(Wine wine) async {
    final userId = await _resolveUserId();
    try {
      print('📤 Enviando para Firebase: ${wine.name}');
      
      await _firestore!
          .collection('users')
          .doc(_firebaseUid)
          .collection('wines')
          .doc(wine.id)
          .set(wine.toFirestore(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));

      print('✅ ${wine.name} salvo no Firebase!');
      
      // Salvar cópia local também (cache)
      await _dbService.insertWine(wine, userId);
      await _dbService.markWineAsSynced(wine.id, userId);
      print('✅ Cópia local salva como cache');
    } catch (e) {
      print('❌ Erro ao salvar no Firebase: $e');
      rethrow;
    }
  }

  // Atualizar vinho diretamente no Firebase
  Future<void> _updateWineInFirebase(Wine wine) async {
    final userId = await _resolveUserId();
    try {
      print('📤 Atualizando no Firebase: ${wine.name}');
      
      await _firestore!
          .collection('users')
          .doc(_firebaseUid)
          .collection('wines')
          .doc(wine.id)
          .update(wine.toFirestore())
          .timeout(const Duration(seconds: 15));

      print('✅ ${wine.name} atualizado no Firebase!');
      
      // Atualizar cópia local também (cache)
      await _dbService.updateWine(wine, userId);
      await _dbService.markWineAsSynced(wine.id, userId);
      print('✅ Cópia local atualizada');
    } catch (e) {
      print('❌ Erro ao atualizar no Firebase: $e');
      rethrow;
    }
  }

  // Deletar vinho diretamente no Firebase
  Future<void> _deleteWineFromFirebase(String wineId) async {
    final userId = await _resolveUserId();
    try {
      print('📤 Deletando do Firebase: $wineId');
      
      await _firestore!
          .collection('users')
          .doc(_firebaseUid)
          .collection('wines')
          .doc(wineId)
          .delete()
          .timeout(const Duration(seconds: 15));

      print('✅ Vinho deletado do Firebase!');
      
      // Deletar cópia local também (cache)
      await _dbService.deleteWine(wineId, userId);
      print('✅ Cópia local deletada');
    } catch (e) {
      print('❌ Erro ao deletar do Firebase: $e');
      rethrow;
    }
  }
}
