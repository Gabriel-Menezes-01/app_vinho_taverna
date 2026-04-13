import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';
import '../models/wine.dart';
import '../models/user.dart';
import '../models/wine_regions.dart';
import 'database_service.dart';
import 'sync_service.dart';

/// Adapta dart:io HttpClient (com badCertificateCallback customizado)
/// para o package:http BaseClient. Necessário no Windows por causa do
/// BoringSSL embutido que não lê o certificado raiz do sistema.
class _SecureHttpClient extends http.BaseClient {
  final HttpClient _inner;
  _SecureHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ioRequest = await _inner.openUrl(
        request.method, request.url);
    request.headers.forEach((name, value) {
      ioRequest.headers.set(name, value);
    });
    if (request is http.Request) {
      ioRequest.contentLength = request.bodyBytes.length;
      ioRequest.add(request.bodyBytes);
    }
    final ioResponse = await ioRequest.close();
    final headers = <String, String>{};
    ioResponse.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });
    return http.StreamedResponse(
      ioResponse,
      ioResponse.statusCode,
      headers: headers,
    );
  }

  @override
  void close() {
    _inner.close(force: true);
  }
}

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

    // SEMPRE salvar localmente primeiro (garante que dado nunca se perde)
    print('💾 [WineService] Salvando localmente...');
    await _dbService.insertAdegaWine(updatedWine, userId);
    print('✅ [WineService] Salvo localmente!');

    if (_canUseFirestore()) {
      print('☁️ [WineService] Firebase habilitado, tentando salvar no Firestore...');
      try {
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
        await _dbService.markWineAsSynced(updatedWine.id, userId);
        print('✅ [WineService] Cache local marcado como sincronizado!');
      } catch (e) {
        print('⚠️ [WineService] Falha ao salvar no Firestore: $e');
        print('📱 [WineService] Dados mantidos localmente (serão sincronizados depois)');
        // Não relança: dados já estão salvos localmente
      }
    } else {
      print('📱 [WineService] Firebase não disponível, dados salvos apenas localmente.');
    }
  }

  Future<void> updateAdegaWine(Wine wine) async {
    final userId = await _resolveUserId();
    final updatedWine = await _ensureImageUploaded(wine, isAdega: true);

    // SEMPRE atualizar localmente primeiro
    await _dbService.updateAdegaWine(updatedWine, userId);

    if (_canUseFirestore()) {
      try {
        final uid = _requireFirestoreUid();
        await _firestore!
            .collection('users')
            .doc(uid)
            .collection('adega')
            .doc(updatedWine.id)
            .set(updatedWine.toFirestore(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
        await _dbService.markWineAsSynced(updatedWine.id, userId);
      } catch (e) {
        print('⚠️ [WineService] Falha ao atualizar no Firestore: $e');
        // Não relança: dados já estão salvos localmente
      }
    }
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

      await _backfillMissingImageUrls(
        wines,
        isAdega: true,
        userId: userId,
      );

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

        await _backfillMissingImageUrls(
          merged,
          isAdega: false,
          userId: userId,
        );

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

  Future<List<Wine>> getHomeWines({
    required String selectedRegion,
    required String selectedWineType,
    int limit = 200,
  }) async {
    final userId = await _resolveUserId();

    String? regionFilter;
    bool? dailySpecialFilter;
    double? maxPrice;

    if (selectedRegion == WineRegions.todaySuggestion) {
      dailySpecialFilter = true;
    } else if (selectedRegion == WineRegions.houseWine) {
      maxPrice = 10.0;
    } else if (selectedRegion != WineRegions.all) {
      regionFilter = selectedRegion;
    }

    final normalizedType =
        selectedWineType == 'todos' ? null : selectedWineType;

    // Sempre ter fallback local já filtrado.
    final localFiltered = await _dbService.getWinesForScreen(
      userId,
      excludeAdega: true,
      onlyAvailable: true,
      region: regionFilter,
      wineType: normalizedType,
      isDailySpecial: dailySpecialFilter,
      maxPrice: maxPrice,
      limit: limit,
    );

    if (!_canUseFirestore()) {
      return localFiltered;
    }

    try {
      Query<Map<String, dynamic>> query = _firestore!
          .collection('users')
          .doc(_firebaseUid)
          .collection('wines')
          .where('isFromAdega', isEqualTo: false)
          .where('quantity', isGreaterThan: 0);

      if (regionFilter != null) {
        query = query.where('region', isEqualTo: regionFilter);
      }
      if (normalizedType != null) {
        query = query.where('wineType', isEqualTo: normalizedType);
      }
      if (dailySpecialFilter != null) {
        query = query.where('isDailySpecial', isEqualTo: dailySpecialFilter);
      }
      if (maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: maxPrice);
      }
      if (limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 15));

      final remoteWines = snapshot.docs
          .map((doc) => Wine.fromFirestore(doc.data()))
          .toList();

      for (final wine in remoteWines) {
        await _dbService.insertWine(wine, userId);
      }

      if (remoteWines.isEmpty) {
        return localFiltered;
      }

      final remoteIds = remoteWines.map((w) => w.id).toSet();
      return [
        ...remoteWines,
        ...localFiltered.where((w) => !remoteIds.contains(w.id)),
      ];
    } catch (e) {
      print('⚠️ Erro ao buscar vinhos da Home no Firestore: $e');
      return localFiltered;
    }
  }

  Future<List<Wine>> getSoldOutWines({int limit = 200}) async {
    final userId = await _resolveUserId();

    final localFiltered = await _dbService.getWinesForScreen(
      userId,
      excludeAdega: true,
      onlySoldOut: true,
      limit: limit,
    );

    if (!_canUseFirestore()) {
      return localFiltered;
    }

    try {
      Query<Map<String, dynamic>> query = _firestore!
          .collection('users')
          .doc(_firebaseUid)
          .collection('wines')
          .where('isFromAdega', isEqualTo: false)
          .where('quantity', isEqualTo: 0);

      if (limit > 0) {
        query = query.limit(limit);
      }

      final snapshot = await query.get().timeout(const Duration(seconds: 15));
      final remoteWines = snapshot.docs
          .map((doc) => Wine.fromFirestore(doc.data()))
          .toList();

      for (final wine in remoteWines) {
        await _dbService.insertWine(wine, userId);
      }

      if (remoteWines.isEmpty) {
        return localFiltered;
      }

      final remoteIds = remoteWines.map((w) => w.id).toSet();
      return [
        ...remoteWines,
        ...localFiltered.where((w) => !remoteIds.contains(w.id)),
      ];
    } catch (e) {
      print('⚠️ Erro ao buscar vinhos esgotados no Firestore: $e');
      return localFiltered;
    }
  }

  Future<void> _backfillMissingImageUrls(
    List<Wine> wines, {
    required bool isAdega,
    required int userId,
  }) async {
    if (!_canUseFirestore()) return;
    final uid = _requireFirestoreUid();
    final collection = isAdega ? 'adega' : 'wines';

    for (final wine in wines) {
      final hasUrl = wine.imageUrl != null && wine.imageUrl!.isNotEmpty;
      final hasLocalPath = wine.imagePath != null && wine.imagePath!.isNotEmpty;
      if (!hasLocalPath) continue;

      // Se já tem URL, só tenta corrigir quando a URL do Firebase estiver quebrada.
      if (hasUrl) {
        final isFirebaseUrl =
            wine.imageUrl!.contains('firebasestorage.googleapis.com');
        if (!isFirebaseUrl) continue;
        final isReachable = await _isRemoteImageReachable(wine.imageUrl!);
        if (isReachable) continue;
        print('⚠️ URL de imagem quebrada detectada (${wine.id}), tentando corrigir...');
      }

      final uploadedUrl = await uploadImageIfNeeded(
        imagePath: wine.imagePath,
        // Força reupload quando URL existente estiver quebrada
        imageUrl: hasUrl ? null : wine.imageUrl,
        wineId: wine.id,
        isAdega: isAdega,
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) continue;

      wine.imageUrl = uploadedUrl;

      try {
        await _firestore!
            .collection('users')
            .doc(uid)
            .collection(collection)
            .doc(wine.id)
            .set(wine.toFirestore(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        print('⚠️ Erro ao atualizar imageUrl no Firestore (${wine.id}): $e');
      }

      try {
        if (isAdega) {
          await _dbService.updateAdegaWine(wine, userId);
        } else {
          await _dbService.updateWine(wine, userId);
        }
      } catch (e) {
        print('⚠️ Erro ao atualizar imageUrl no SQLite (${wine.id}): $e');
      }
    }
  }

  Future<bool> _isRemoteImageReachable(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) {
          return host.endsWith('.googleapis.com') ||
              host.endsWith('.firebasestorage.app') ||
              host.endsWith('.google.com');
        };

      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      await response.drain();
      httpClient.close();
      return ok;
    } catch (_) {
      return false;
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
      if (!await file.exists()) {
        print('⚠️ Arquivo de imagem nao encontrado: $imagePath');
        return imageUrl;
      }

      // Detectar content-type pela extensão
      final ext = imagePath.toLowerCase().contains('.')
          ? imagePath.substring(imagePath.lastIndexOf('.')).toLowerCase()
          : '.jpg';
      final contentType = ext == '.png'
          ? 'image/png'
          : ext == '.webp'
              ? 'image/webp'
              : 'image/jpeg';
      final storageName = '$wineId$ext';
      final folder = isAdega ? 'adega' : 'wines';

      print('📤 Iniciando upload: $storageName ($contentType)');

      final bytes = await file.readAsBytes();

      // No Windows/desktop o SDK do Firebase Storage tem bugs de threading.
      // Usar a REST API diretamente é mais confiável nessa plataforma.
      if (Platform.isWindows || Platform.isLinux) {
        final url = await _uploadViaRestApi(
          bytes: bytes,
          contentType: contentType,
          storagePath: 'users/$authUid/$folder/$storageName',
          uid: authUid,
        );
        if (url != null) print('✅ Upload REST concluido! URL: $url');
        return url ?? imageUrl;
      }

      // Mobile/macOS: usar o SDK normalmente
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_firebaseUid!)
          .child(folder)
          .child(storageName);

      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      if (snapshot.state == TaskState.success) {
        final url = await snapshot.ref.getDownloadURL();
        print('✅ Upload SDK concluido! URL: $url');
        return url;
      }
      print('⚠️ Upload nao concluido: ${snapshot.state}');
    } on FirebaseException catch (e) {
      print('⚠️ Erro Firebase ao enviar imagem: ${e.code} - ${e.message}');
    } catch (e) {
      print('⚠️ Erro ao enviar imagem: $e');
    }

    return imageUrl;
  }

  /// Faz upload via Firebase Storage REST API.
  /// Necessário no Windows pois o SDK tem bug de threading no desktop.
  Future<String?> _uploadViaRestApi({
    required Uint8List bytes,
    required String contentType,
    required String storagePath,
    required String uid,
  }) async {
    try {
      // Obter token de autenticação do usuário atual
      final idToken =
          await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        print('⚠️ Sem token de autenticação para upload REST');
        return null;
      }

      final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
      if (bucket == null || bucket.isEmpty) {
        print('⚠️ storageBucket não configurado no firebase_options.dart');
        return null;
      }

      // No Windows, o Flutter usa BoringSSL embutido que não acessa o
      // certificado raiz do sistema. Criamos um HttpClient que aceita
      // certificados válidos dos domínios do Google/Firebase.
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) {
          // Aceitar somente hosts conhecidos do Google/Firebase
          return host.endsWith('.googleapis.com') ||
              host.endsWith('.firebasestorage.app') ||
              host.endsWith('.google.com');
        };

      final innerClient = _SecureHttpClient(httpClient);
      final downloadToken = const Uuid().v4();

      final uploadUri = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
        '?uploadType=media&name=${Uri.encodeComponent(storagePath)}',
      );

      final request = http.Request('POST', uploadUri)
        ..headers['Authorization'] = 'Bearer $idToken'
        ..headers['Content-Type'] = contentType
        ..headers['X-Goog-Meta-firebaseStorageDownloadTokens'] = downloadToken
        ..bodyBytes = bytes;

      final streamedResponse = await innerClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      innerClient.close();

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final objectName = (body['name'] as String?) ?? storagePath;
        final responseTokens = (body['downloadTokens'] as String?)?.trim();
        final effectiveToken =
          (responseTokens != null && responseTokens.isNotEmpty)
            ? responseTokens.split(',').first.trim()
            : downloadToken;
        final encodedPath = Uri.encodeComponent(objectName);
        final downloadUrl =
            'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
          '/$encodedPath?alt=media&token=$effectiveToken';
        return downloadUrl;
      } else {
        print(
            '⚠️ REST upload falhou: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('⚠️ Erro no REST upload: $e');
      return null;
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
