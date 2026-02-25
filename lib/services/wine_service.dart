import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';
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

  bool _canUseFirestore() {
    if (!firebaseEnabled || _firestore == null) {
      return false;
    }
    final authUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      return false;
    }
    // Garante UID do Firebase mesmo se não foi configurado via UserService
    _firebaseUid ??= authUid;
    return true;
  }

  String _requireFirestoreUid() {
    if (!_canUseFirestore() || _firebaseUid == null) {
      throw Exception('Firebase nao disponivel ou usuario nao autenticado');
    }
    return _firebaseUid!;
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
    final updatedWine = await _ensureImageUploaded(wine, isAdega: false);
    
    // SEMPRE salvar no Firestore (se Firebase está habilitado)
    if (_canUseFirestore()) {
      print('☁️ Salvando direto no Firestore...');
      try {
        await _addWineToFirebase(updatedWine);
      } catch (e) {
        print('⚠️ Erro ao salvar no Firestore: $e');
        print('📱 Salvando apenas localmente como fallback...');
        await _dbService.insertWine(updatedWine, userId);
        print('✅ Vinho salvo localmente');
      }
    } else {
      // Fallback para SQLite se Firebase não disponível
      print('📱 Firebase não disponível, salvando localmente...');
      await _dbService.insertWine(updatedWine, userId);
      print('✅ Vinho adicionado localmente');
    }
  }

  // ==================== ADEGA (VINHOS PESSOAIS) ====================

  Future<void> addAdegaWine(Wine wine) async {
    print('📦 [WineService] addAdegaWine iniciado para: ${wine.name}');
    final userId = await _resolveUserId();
    print('👤 [WineService] userId resolvido: $userId');
    final updatedWine = await _ensureImageUploaded(wine, isAdega: true);
    print('📸 [WineService] Imagem processada');

    if (firebaseEnabled) {
      print('☁️ [WineService] Firebase habilitado, tentando salvar no Firestore...');
      final uid = _requireFirestoreUid();
      print('🔑 [WineService] Firebase UID: $uid');
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('adega')
          .doc(updatedWine.id)
          .set(updatedWine.toFirestore(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      print('✅ [WineService] Salvo no Firestore com sucesso!');
      // Cache local para offline, mas somente apos salvar no Firestore
      print('💾 [WineService] Salvando cache local...');
      await _dbService.insertAdegaWine(updatedWine, userId);
      await _dbService.markWineAsSynced(updatedWine.id, userId);
      print('✅ [WineService] Cache local salvo!');
      return;
    }

    print('💾 [WineService] Firebase desabilitado, salvando apenas localmente...');
    await _dbService.insertAdegaWine(updatedWine, userId);
    print('✅ [WineService] Salvo localmente com sucesso!');
  }

  Future<void> updateAdegaWine(Wine wine) async {
    final userId = await _resolveUserId();
    final updatedWine = await _ensureImageUploaded(wine, isAdega: true);
    if (firebaseEnabled) {
      final uid = _requireFirestoreUid();
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('adega')
          .doc(updatedWine.id)
          .update(updatedWine.toFirestore())
          .timeout(const Duration(seconds: 15));
      await _dbService.updateAdegaWine(updatedWine, userId);
      await _dbService.markWineAsSynced(updatedWine.id, userId);
      return;
    }

    await _dbService.updateAdegaWine(updatedWine, userId);
  }

  Future<void> deleteAdegaWine(String id) async {
    final userId = await _resolveUserId();
    if (firebaseEnabled) {
      final uid = _requireFirestoreUid();
      await _firestore!
          .collection('users')
          .doc(uid)
          .collection('adega')
          .doc(id)
          .delete()
          .timeout(const Duration(seconds: 15));
      await _dbService.deleteAdegaWine(id, userId);
      return;
    }

    await _dbService.deleteAdegaWine(id, userId);
  }

  Future<List<Wine>> getAdegaWines() async {
    print('🔍 [WineService] getAdegaWines iniciado');
    final userId = await _resolveUserId();
    print('👤 [WineService] userId: $userId');
    if (firebaseEnabled) {
      print('☁️ [WineService] Buscando no Firestore...');
      final uid = _requireFirestoreUid();
      print('🔑 [WineService] Firebase UID: $uid');
      final snapshot = await _firestore!
          .collection('users')
          .doc(uid)
          .collection('adega')
          .get()
          .timeout(const Duration(seconds: 15));
      print('📦 [WineService] Documentos retornados do Firestore: ${snapshot.docs.length}');
      var wines = snapshot.docs
        .map((doc) => Wine.fromFirestore(doc.data()))
        .toList();

      // Fallback: dados antigos podem estar em /wines com isFromAdega = true
      if (wines.isEmpty) {
        print('⚠️ [WineService] Nenhum vinho na coleção adega, tentando fallback...');
        final fallbackSnapshot = await _firestore!
            .collection('users')
            .doc(uid)
            .collection('wines')
            .where('isFromAdega', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 15));

        final fallbackWines = fallbackSnapshot.docs
            .map((doc) => Wine.fromFirestore(doc.data()))
            .toList();
        print('📦 [WineService] Fallback encontrou: ${fallbackWines.length} vinhos');

        if (fallbackWines.isNotEmpty) {
          wines = fallbackWines;

          // Migrar para a colecao correta da adega
          print('🔄 [WineService] Migrando vinhos para coleção adega...');
          for (final w in fallbackWines) {
            await _firestore!
                .collection('users')
                .doc(uid)
                .collection('adega')
                .doc(w.id)
                .set(w.toFirestore(), SetOptions(merge: true));
          }
          print('✅ [WineService] Migração concluída');
        }
      }

      // Cache local para offline
      print('💾 [WineService] Salvando cache local de ${wines.length} vinhos...');
      for (final w in wines) {
        await _dbService.insertAdegaWine(w, userId);
      }
      print('✅ [WineService] getAdegaWines retornando ${wines.length} vinhos');
      return wines;
    }

    print('💾 [WineService] Buscando localmente no SQLite...');
    final localWines = await _dbService.getAdegaWinesByUser(userId);
    print('✅ [WineService] getAdegaWines retornando ${localWines.length} vinhos locais');
    return localWines;
  }

  // Atualizar um vinho
  Future<void> updateWine(Wine wine) async {
    print('🍷 Atualizando vinho: ${wine.name}');
    final userId = await _resolveUserId();
    final updatedWine = await _ensureImageUploaded(wine, isAdega: false);
    
    // SEMPRE atualizar no Firestore (se Firebase está habilitado)
    if (_canUseFirestore()) {
      print('☁️ Atualizando no Firestore...');
      try {
        await _updateWineInFirebase(updatedWine);
      } catch (e) {
        print('⚠️ Erro ao atualizar no Firestore: $e');
        print('📱 Atualizando apenas localmente como fallback...');
        await _dbService.updateWine(updatedWine, userId);
        print('✅ Vinho atualizado localmente');
      }
    } else {
      // Fallback para SQLite se Firebase não disponível
      print('📱 Firebase não disponível, atualizando localmente...');
      await _dbService.updateWine(updatedWine, userId);
      print('✅ Vinho atualizado localmente');
    }
  }

  // Excluir um vinho
  Future<void> deleteWine(String id) async {
    print('🗑️ Deletando vinho: $id');
    final userId = await _resolveUserId();
    
    // SEMPRE deletar no Firestore (se Firebase está habilitado)
    if (_canUseFirestore()) {
      print('☁️ Deletando do Firestore...');
      try {
        await _deleteWineFromFirebase(id);
      } catch (e) {
        print('⚠️ Erro ao deletar no Firestore: $e');
        print('📱 Deletando apenas localmente como fallback...');
        await _dbService.deleteWine(id, userId);
        print('✅ Vinho deletado localmente');
      }
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
    if (_canUseFirestore()) {
      final authUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      print('🔐 FirebaseAuth uid atual: ${authUid ?? "NULO"}');
      print('🔐 UID configurado no WineService: $_firebaseUid');
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

        // Se o Firestore estiver vazio, usar cache local para nao mostrar lista vazia
        final localWines = await _dbService.getWinesByUser(userId);
        if (wines.isEmpty && localWines.isNotEmpty) {
          return localWines;
        }

        // Mesclar vinhos locais que ainda nao estao no Firestore
        final remoteIds = wines.map((w) => w.id).toSet();
        final merged = [
          ...wines,
          ...localWines.where((w) => !remoteIds.contains(w.id)),
        ];

        return merged;
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

  Future<Wine> _ensureImageUploaded(Wine wine, {required bool isAdega}) async {
    final uploadedUrl = await uploadImageIfNeeded(
      imagePath: wine.imagePath,
      imageUrl: wine.imageUrl,
      wineId: wine.id,
      isAdega: isAdega,
    );
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      wine.imageUrl = uploadedUrl;
    }
    return wine;
  }

  Future<String?> uploadImageIfNeeded({
    required String? imagePath,
    required String? imageUrl,
    required String wineId,
    required bool isAdega,
  }) async {
    if (!firebaseEnabled) return imageUrl;
    final authUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      print('⚠️ Upload ignorado: usuario nao autenticado');
      return imageUrl;
    }
    _firebaseUid ??= authUid;

    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    if (imagePath == null || imagePath.isEmpty) return imageUrl;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return imageUrl;

      final folder = isAdega ? 'adega' : 'wines';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_firebaseUid!)
          .child(folder)
          .child('$wineId.jpg');

      final snapshot = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      }
      print('⚠️ Upload nao concluido: ${snapshot.state}');
    } on FirebaseException catch (e) {
      print('⚠️ Erro ao enviar imagem: ${e.code} - ${e.message}');
    } catch (e) {
      print('⚠️ Erro ao enviar imagem: $e');
    }

    return imageUrl;
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
