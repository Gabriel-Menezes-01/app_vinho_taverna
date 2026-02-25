import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wine.dart';
import 'firebase_auth_service.dart';
import 'database_service.dart';

/// Serviço de vinhos com Firestore como banco principal e SQLite como cache
class FirebaseWineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _authService;
  final DatabaseService _dbService;

  FirebaseWineService(this._authService, this._dbService);

  /// Obter UID do usuário logado
  String? get _currentUid => _authService.getCurrentFirebaseUid();

  /// Adicionar vinho (salva no Firestore E no cache local)
  Future<bool> addWine(Wine wine) async {
    final uid = _currentUid;
    if (uid == null) return false;

    try {
      // Salvar no Firestore (fonte primária)
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('wines')
          .doc(wine.id)
          .set({
        'id': wine.id,
        'name': wine.name,
        'price': wine.price,
        'description': wine.description,
        'image_path': wine.imagePath,
        'image_url': wine.imageUrl,
        'region': wine.region,
        'wine_type': wine.wineType,
        'quantity': wine.quantity,
        'location': wine.location,
        'harvest_year': wine.harvestYear,
        'last_modified': FieldValue.serverTimestamp(),
        'created_at': wine.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      });

      // Salvar no cache local (SQLite) para acesso offline
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _dbService.insertWine(wine, userId);
      }

      return true;
    } catch (e) {
      print('Erro ao adicionar vinho: $e');
      
      // Se falhou no Firestore, salva pelo menos no local
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _dbService.insertWine(wine, userId);
      }
      
      return false;
    }
  }

  /// Atualizar vinho
  Future<bool> updateWine(Wine wine) async {
    final uid = _currentUid;
    if (uid == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('wines')
          .doc(wine.id)
          .update({
        'name': wine.name,
        'price': wine.price,
        'description': wine.description,
        'image_path': wine.imagePath,
        'image_url': wine.imageUrl,
        'region': wine.region,
        'wine_type': wine.wineType,
        'quantity': wine.quantity,
        'location': wine.location,
        'harvest_year': wine.harvestYear,
        'last_modified': FieldValue.serverTimestamp(),
      });

      // Atualizar cache local
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _dbService.updateWine(wine, userId);
      }

      return true;
    } catch (e) {
      print('Erro ao atualizar vinho: $e');
      
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _dbService.updateWine(wine, userId);
      }
      
      return false;
    }
  }

  /// Deletar vinho
  Future<bool> deleteWine(String wineId) async {
    final uid = _currentUid;
    if (uid == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('wines')
          .doc(wineId)
          .delete();

      // Deletar do cache local
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _dbService.deleteWine(wineId, userId);
      }

      return true;
    } catch (e) {
      print('Erro ao deletar vinho: $e');
      
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _dbService.deleteWine(wineId, userId);
      }
      
      return false;
    }
  }

  /// Obter todos os vinhos do usuário (carrega do Firestore e atualiza cache)
  Future<List<Wine>> getWines() async {
    final uid = _currentUid;
    if (uid == null) {
      // Sem login, retorna cache local
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        return await _dbService.getWinesByUser(userId);
      }
      return [];
    }

    try {
      // Buscar do Firestore (fonte primária)
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('wines')
          .orderBy('created_at', descending: true)
          .get();

      final wines = snapshot.docs.map((doc) {
        final data = doc.data();
        return Wine(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          description: data['description'] ?? '',
          imagePath: data['image_path'],
          imageUrl: data['image_url'] ?? data['imageUrl'],
          region: data['region'] ?? '',
          wineType: data['wine_type'] ?? '',
          quantity: data['quantity'] ?? 0,
          location: data['location'],
          harvestYear: (data['harvest_year'] as num?)?.toInt() ?? (data['harvestYear'] as num?)?.toInt(),
          lastModified: (data['last_modified'] as Timestamp?)?.toDate() ?? DateTime.now(),
          createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();

      // Atualizar cache local para acesso offline
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        // Limpar cache antigo e salvar novos
        for (final wine in wines) {
          await _dbService.insertWine(wine, userId);
        }
      }

      return wines;
    } catch (e) {
      print('Erro ao carregar vinhos do Firestore: $e');
      
      // Fallback: retornar cache local
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        return await _dbService.getWinesByUser(userId);
      }
      return [];
    }
  }

  /// Obter vinho por ID
  Future<Wine?> getWineById(String wineId) async {
    final uid = _currentUid;
    if (uid == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('wines')
          .doc(wineId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return Wine(
        id: data['id'] ?? doc.id,
        name: data['name'] ?? '',
        price: (data['price'] ?? 0).toDouble(),
        description: data['description'] ?? '',
        imagePath: data['image_path'],
        imageUrl: data['image_url'] ?? data['imageUrl'],
        region: data['region'] ?? '',
        wineType: data['wine_type'] ?? '',
        quantity: data['quantity'] ?? 0,
        location: data['location'],
        harvestYear: (data['harvest_year'] as num?)?.toInt() ?? (data['harvestYear'] as num?)?.toInt(),
        lastModified: (data['last_modified'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      print('Erro ao buscar vinho: $e');
      
      // Fallback: cache local
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        return await _dbService.getWineById(wineId, userId);
      }
      return null;
    }
  }

  /// Stream de vinhos (atualização em tempo real)
  Stream<List<Wine>> watchWines() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('wines')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Wine(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          description: data['description'] ?? '',
          imagePath: data['image_path'],
          imageUrl: data['image_url'] ?? data['imageUrl'],
          region: data['region'] ?? '',
          wineType: data['wine_type'] ?? '',
          quantity: data['quantity'] ?? 0,
          location: data['location'],
          harvestYear: (data['harvest_year'] as num?)?.toInt() ?? (data['harvestYear'] as num?)?.toInt(),
          lastModified: (data['last_modified'] as Timestamp?)?.toDate() ?? DateTime.now(),
          createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    });
  }

  /// Sincronizar cache local com Firestore
  Future<void> syncLocalToFirestore() async {
    final uid = _currentUid;
    final userId = await _authService.getCurrentUserId();
    
    if (uid == null || userId == null) return;

    try {
      // Buscar vinhos não sincronizados do cache local
      final localWines = await _dbService.getUnsyncedWines(userId);
      
      for (final wine in localWines) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('wines')
            .doc(wine.id)
            .set({
          'id': wine.id,
          'name': wine.name,
          'price': wine.price,
          'description': wine.description,
          'image_path': wine.imagePath,
          'image_url': wine.imageUrl,
          'region': wine.region,
          'wine_type': wine.wineType,
          'quantity': wine.quantity,
          'location': wine.location,
          'harvest_year': wine.harvestYear,
          'last_modified': FieldValue.serverTimestamp(),
          'created_at': wine.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        });

        // Marcar como sincronizado
        await _dbService.markWineAsSynced(wine.id, userId);
      }
    } catch (e) {
      print('Erro ao sincronizar: $e');
    }
  }
}
