import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user.dart';
import '../models/wine.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _dbService;
  final bool firebaseEnabled;
  firebase_auth.FirebaseAuth? _firebaseAuth;
  FirebaseFirestore? _firestore;
  static const String _currentUserKey = 'current_user_id';
  static const String _firebaseUidKey = 'firebase_uid';

  AuthService(this._dbService, {this.firebaseEnabled = false}) {
    if (firebaseEnabled) {
      try {
        _firebaseAuth = firebase_auth.FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        print('Erro ao inicializar Firebase Auth: $e');
      }
    }
  }

  // Verificar conexão com internet
  Future<bool> _hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  // Hash de senha usando SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Registrar novo usuário
  Future<bool> register(String username, String email, String password) async {
    try {
      print('📝 Iniciando registro: $username ($email)');
      
      // PRIMEIRO: Verificar se usuário ou email já existe localmente
      print('🔍 Verificando se usuário/email já existe...');
      final existingUsername = await _dbService.getUserByUsername(username);
      if (existingUsername != null) {
        print('⚠️ Nome de usuário já existe localmente');
        return false;
      }
      
      final existingEmail = await _dbService.getUserByEmail(email);
      if (existingEmail != null) {
        print('⚠️ Email já existe localmente');
        return false;
      }

      print('✅ Usuário/email disponível');

      // SEMPRE criar usuário local primeiro (garantia)
      // Salvar senha em texto plano (como digitada)
      print('📝 Criando usuário no banco local: $username ($email)');
      final userId = await _dbService.createUser(username, email, password, firebaseUid: null);
      print('✅ Usuário criado no banco local com ID: $userId');

      // Salvar sessão (login automático) IMEDIATAMENTE
      print('💾 Salvando sessão...');
      await _saveSession(userId);
      print('✅ Sessão salva para usuário ID: $userId');
      print('✅ REGISTRO COMPLETO - Usuário pode fazer login!');

      // DEPOIS: Tentar criar no Firebase em background (não bloqueia)
      _tryCreateFirebaseUser(username, email, password, userId);

      return true;
    } catch (e) {
      print('❌ Erro no registro: $e');
      return false;
    }
  }

  // Criar usuário no Firebase em background (não bloqueia o registro)
  Future<void> _tryCreateFirebaseUser(String username, String email, String password, int localUserId) async {
    try {
      final hasInternet = await _hasInternetConnection();
      
      if (!firebaseEnabled || _firebaseAuth == null || !hasInternet) {
        print('ℹ️ Firebase desabilitado ou sem internet - apenas banco local');
        return;
      }

      print('☁️ Tentando criar usuário no Firebase (background)...');
      
      // Criar usuário no Firebase Auth com timeout
      final credential = await _firebaseAuth!
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ Timeout ao criar usuário no Firebase');
              throw Exception('Timeout Firebase');
            },
          );

      if (credential.user != null) {
        final firebaseUid = credential.user!.uid;
        
        // Atualizar display name
        await credential.user!.updateDisplayName(username);

        // Salvar dados no Firestore
        if (_firestore != null) {
          await _firestore!.collection('users').doc(firebaseUid).set(
            {
              'username': username,
              'email': email,
              'createdAt': DateTime.now().toIso8601String(),
            },
          ).timeout(const Duration(seconds: 5));
          print('✓ Dados do usuário salvos no Firestore');
        }

        // Salvar UID do Firebase
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_firebaseUidKey, firebaseUid);

        // Persistir UID do Firebase no usuário local para sincronização entre dispositivos
        await _dbService.updateUser(localUserId, firebaseUid: firebaseUid);
        print('✓ firebaseUid persistido localmente para o usuário $localUserId');

        print('✅ Usuário criado no Firebase Auth: $firebaseUid');
      }
    } catch (e) {
      print('⚠️ Erro ao criar no Firebase (usuário já criado localmente): $e');
      // Não retornar false - usuário JÁ FOI CRIADO LOCALMENTE
    }
  }

  // Sincronizar vinhos do Firestore para o banco local
  Future<void> _syncWinesFromFirebase(String firebaseUid, int localUserId) async {
    if (!firebaseEnabled || _firestore == null) {
      print('ℹ️ Firebase não habilitado, pulando sincronização de vinhos');
      return;
    }

    try {
      print('🔄 Buscando vinhos do usuário $firebaseUid...');
      
      final snapshot = await _firestore!
          .collection('users')
          .doc(firebaseUid)
          .collection('wines')
          .get()
          .timeout(const Duration(seconds: 15));

      if (snapshot.docs.isEmpty) {
        print('ℹ️ Nenhum vinho encontrado no Firebase');
        return;
      }

      // Obter vinhos locais
      final localWines = await _dbService.getWinesByUser(localUserId);
      final localWineIds = localWines.map((w) => w.id).toSet();

      int newWinesCount = 0;
      int updatedWinesCount = 0;

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final serverWine = Wine.fromFirestore(data);

          if (!localWineIds.contains(serverWine.id)) {
            // Vinho novo - inserir
            await _dbService.insertWine(serverWine, localUserId);
            await _dbService.markWineAsSynced(serverWine.id, localUserId);
            newWinesCount++;
            print('✅ Vinho ${serverWine.name} adicionado');
          } else {
            // Vinho existe - verificar se servidor é mais recente
            final localWine = localWines.firstWhere((w) => w.id == serverWine.id);
            if (serverWine.lastModified != null &&
                localWine.lastModified != null &&
                serverWine.lastModified!.isAfter(localWine.lastModified!)) {
              await _dbService.updateWine(serverWine, localUserId);
              await _dbService.markWineAsSynced(serverWine.id, localUserId);
              updatedWinesCount++;
              print('✅ Vinho ${serverWine.name} atualizado');
            }
          }
        } catch (e) {
          print('⚠️ Erro ao processar vinho: $e');
        }
      }

      print('🎉 Sincronização completa: $newWinesCount novos, $updatedWinesCount atualizados');
    } catch (e) {
      print('⚠️ Erro ao sincronizar vinhos: $e');
    }
  }

  // Login de usuário (aceita username ou email)
  Future<User?> login(String usernameOrEmail, String password) async {
    try {
      final hasInternet = await _hasInternetConnection();
      
      // Determinar se é email ou username
      final isEmail = usernameOrEmail.contains('@');
      
      // Tentar obter o usuário local primeiro para descobrir o email (se for username)
      User? localUser;
      String? emailForFirebase;
      
      if (isEmail) {
        localUser = await _dbService.getUserByEmail(usernameOrEmail);
        emailForFirebase = usernameOrEmail;
      } else {
        localUser = await _dbService.getUserByUsername(usernameOrEmail);
        emailForFirebase = localUser?.email;
      }

      // Se tiver Firebase e internet, tentar autenticar na nuvem primeiro e sincronizar local
      if (firebaseEnabled && _firebaseAuth != null && hasInternet && emailForFirebase != null) {
        try {
          final credential = await _firebaseAuth!
              .signInWithEmailAndPassword(email: emailForFirebase, password: password)
              .timeout(const Duration(seconds: 8));

          if (credential.user != null) {
            final firebaseUid = credential.user!.uid;
            print('✓ Autenticado no Firebase: $firebaseUid');

            // Salvar UID do Firebase
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_firebaseUidKey, firebaseUid);

            // Dados do perfil
            String syncedEmail = credential.user!.email ?? emailForFirebase;
            String syncedUsername = credential.user!.displayName ?? syncedEmail.split('@').first;

            // Tentar carregar dados extras do Firestore
            if (_firestore != null) {
              try {
                final userDoc = await _firestore!
                    .collection('users')
                    .doc(firebaseUid)
                    .get();

                if (userDoc.exists) {
                  final data = userDoc.data();
                  syncedUsername = data?['username'] ?? syncedUsername;
                  syncedEmail = data?['email'] ?? syncedEmail;
                  print('✓ Dados do usuário recuperados do Firestore');
                }
              } catch (e) {
                print('⚠️ Erro ao recuperar dados do Firestore: $e');
              }
            }

            // Garantir usuário local sincronizado com dados do Firebase
            var updatedLocalUser = await _dbService.getUserByEmail(syncedEmail);
            if (updatedLocalUser == null) {
              final userId = await _dbService.createUser(
                syncedUsername,
                syncedEmail,
                password, // salvar mesma senha digitada
                firebaseUid: firebaseUid,
              );
              updatedLocalUser = await _dbService.getUserById(userId);
              print('✓ Usuário local criado após login Firebase');
            } else {
              await _dbService.updateUser(
                updatedLocalUser.id!,
                username: syncedUsername,
                email: syncedEmail,
                password: password,
                firebaseUid: firebaseUid,
              );
              updatedLocalUser = await _dbService.getUserById(updatedLocalUser.id!);
              print('✓ Usuário local atualizado com dados do Firebase');
            }

            if (updatedLocalUser != null) {
              await _saveSession(updatedLocalUser.id!);
              
              // SINCRONIZAR VINHOS DO FIREBASE para o dispositivo local
              print('🔄 Iniciando sincronização de vinhos do Firebase...');
              await _syncWinesFromFirebase(firebaseUid, updatedLocalUser.id!);
              
              return updatedLocalUser;
            }
          }
        } catch (e) {
          print('⚠️ Erro ao autenticar no Firebase: $e');
          // Continua com fallback local
        }
      }

      // Autenticação local (fallback ou modo offline)
      if (isEmail) {
        print('🔍 Tentando login local com email: $usernameOrEmail');
        localUser = await _dbService.getUserByEmail(usernameOrEmail);
      } else {
        print('🔍 Tentando login local com username: $usernameOrEmail');
        localUser = await _dbService.getUserByUsername(usernameOrEmail);
      }
      
      if (localUser == null) {
        print('❌ Usuário não encontrado no banco local: $usernameOrEmail');
        return null;
      }

      print('✓ Usuário encontrado: ${localUser.username} (${localUser.email})');
      
      // Verificar senha (em texto plano)
      print('🔐 Verificando senha...');
      if (localUser.password != password) {
        print('❌ Senha incorreta');
        return null;
      }

      print('✅ Senha correta! Login bem-sucedido');
      
      // Salvar sessão
      await _saveSession(localUser.id!);

      return localUser;
    } catch (e) {
      print('❌ Erro no login: $e');
      return null;
    }
  }

  // Salvar sessão do usuário
  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserKey, userId);
  }

  // Obter usuário logado atual
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_currentUserKey);
      print('🔐 getCurrentUser: userId = $userId');

      if (userId == null) {
        print('🔐 Sem userId salvo na sessão');
        return null;
      }

      final user = await _dbService.getUserById(userId);
      
      if (user == null) {
        print('🔐 ⚠️ Usuário não existe mais no banco! Fazendo logout...');
        await logout(); // Auto-logout se usuário foi deletado
        return null;
      }
      
      // Verificar se o email existe
      if (user.email == null || user.email!.isEmpty) {
        print('🔐 ⚠️ Email vazio ou nulo! Fazendo logout...');
        await logout(); // Auto-logout se email foi apagado
        return null;
      }
      
      print('🔐 Usuário encontrado: ${user.username}');
      return user;
    } catch (e) {
      print('🔐 Erro ao obter usuário atual: $e');
      return null;
    }
  }

  // Verificar se há usuário logado
  Future<bool> isLoggedIn() async {
    print('🔐 Verificando isLoggedIn...');
    final user = await getCurrentUser();
    final result = user != null;
    print('🔐 isLoggedIn = $result');
    return result;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Obter ID do usuário logado
  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentUserKey);
  }

  // Obter UID Firebase atual (ordem de preferência: sessão Auth, SharedPreferences, banco local)
  Future<String?> getFirebaseUid() async {
    if (firebaseEnabled && _firebaseAuth?.currentUser != null) {
      return _firebaseAuth!.currentUser!.uid;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_firebaseUidKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final user = await getCurrentUser();
    return user?.firebaseUid;
  }
}
