import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
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
      connectivityResult.contains(ConnectivityResult.wifi) ||
      connectivityResult.contains(ConnectivityResult.ethernet) ||
      connectivityResult.contains(ConnectivityResult.vpn) ||
      connectivityResult.contains(ConnectivityResult.other);
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

      // DEPOIS: Tentar criar no Firebase
      // No Windows, aguardar a criação para garantir UID/FirebaseAuth
      if (Platform.isWindows) {
        await _tryCreateFirebaseUser(username, email, password, userId);
      } else {
        _tryCreateFirebaseUser(username, email, password, userId);
      }

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
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Se já existe no Firebase, tente login para obter UID e sincronizar
        try {
          print('ℹ️ Email já existe no Firebase. Tentando login para sincronizar...');
          final credential = await _firebaseAuth!
              .signInWithEmailAndPassword(email: email, password: password)
              .timeout(const Duration(seconds: 5));

          final firebaseUid = credential.user?.uid;
          if (firebaseUid != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_firebaseUidKey, firebaseUid);
            await _dbService.updateUser(localUserId, firebaseUid: firebaseUid);
            print('✅ UID do Firebase sincronizado após login: $firebaseUid');
          }
        } catch (loginError) {
          print('⚠️ Falha ao fazer login no Firebase: $loginError');
        }
        return;
      }
      print('⚠️ Erro ao criar no Firebase (usuário já criado localmente): ${e.message ?? e.code}');
      // Não retornar false - usuário JÁ FOI CRIADO LOCALMENTE
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
      final isWindows = Platform.isWindows;
      
      // Determinar se é email ou username
      final isEmail = usernameOrEmail.contains('@');
      
      // NO WINDOWS: Sempre tentar Firebase primeiro (não busca local)
      if (isWindows && firebaseEnabled && _firebaseAuth != null && hasInternet) {
        print('🪟 Windows: Buscando usuário no Firebase...');
        
        String? emailForFirebase;
        
        if (isEmail) {
          emailForFirebase = usernameOrEmail;
        } else {
          // Buscar email pelo username no Firestore
          emailForFirebase = await _findEmailByUsername(usernameOrEmail);
          if (emailForFirebase == null) {
            print('❌ Username não encontrado no Firebase');
            return null;
          }
        }
        
        return await _loginWithFirebase(emailForFirebase, password);
      }
      
      // Outras plataformas: Tentar obter o usuário local primeiro para descobrir o email (se for username)
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
        return await _loginWithFirebase(emailForFirebase, password);
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

      // VERIFICAÇÃO 1: Checar no banco local (SQLite)
      final user = await _dbService.getUserById(userId);
      
      if (user == null) {
        print('🔐 ⚠️ Usuário NÃO existe no banco local! Fazendo logout...');
        await logout(); // Auto-logout se usuário foi deletado
        return null;
      }
      
      // VERIFICAÇÃO 2: Validar dados básicos
      if (user.email == null || user.email!.isEmpty) {
        print('🔐 ⚠️ Email vazio ou nulo! Fazendo logout...');
        await logout(); // Auto-logout se email foi apagado
        return null;
      }

      // VERIFICAÇÃO 3: Se Firebase habilitado, verificar sincronização
      if (firebaseEnabled && _firestore != null && user.firebaseUid != null && user.firebaseUid!.isNotEmpty) {
        final authUid = _firebaseAuth?.currentUser?.uid;
        print('🔐 FirebaseAuth uid atual: ${authUid ?? "NULO"}');
        print('🔐 Firebase UID salvo no usuario: ${user.firebaseUid}');
        if (authUid == null) {
          print('⚠️ FirebaseAuth sem sessão ativa, pulando verificação no Firestore');
          return user;
        }
        print('☁️ Verificando sincronização no Firebase...');
        try {
          final firebaseDoc = await _firestore!
              .collection('users')
              .doc(user.firebaseUid)
              .get()
              .timeout(const Duration(seconds: 5));
          
          if (!firebaseDoc.exists) {
            print('🔐 ⚠️ Usuário não encontrado no Firestore! Fazendo logout...');
            await logout();
            return null;
          }
          print('☁️ ✅ Usuário sincronizado no Firestore');
        } catch (e) {
          print('⚠️ Erro ao verificar Firestore (continuando com cache local): $e');
          // Continua com cache local se Firebase falhar
        }
      }
      
      print('🔐 ✅ Usuário verificado: ${user.username}');
      return user;
    } catch (e) {
      print('🔐 ❌ Erro ao obter usuário atual: $e');
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

  // Buscar usuário por email
  Future<User?> getUserByEmail(String email) async {
    try {
      return await _dbService.getUserByEmail(email);
    } catch (e) {
      print('❌ Erro ao buscar usuário por email: $e');
      return null;
    }
  }

  // Buscar usuário por username ou email
  Future<User?> getUserByUsernameOrEmail(String identifier) async {
    try {
      // Tentar primeiro por username
      final userByUsername = await _dbService.getUserByUsername(identifier);
      if (userByUsername != null) {
        return userByUsername;
      }
      
      // Tentar por email
      return await _dbService.getUserByEmail(identifier);
    } catch (e) {
      print('❌ Erro ao buscar usuário: $e');
      return null;
    }
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

  // Buscar email pelo username no Firestore
  Future<String?> _findEmailByUsername(String username) async {
    try {
      if (_firestore == null) return null;
      
      print('🔍 Buscando email do username "$username" no Firestore...');
      
      final querySnapshot = await _firestore!
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (querySnapshot.docs.isEmpty) {
        print('❌ Username "$username" não encontrado');
        return null;
      }
      
      final email = querySnapshot.docs.first.data()['email'] as String?;
      print('✅ Email encontrado: $email');
      return email;
    } catch (e) {
      print('❌ Erro ao buscar email: $e');
      return null;
    }
  }

  // Login com Firebase (extraído para reutilização)
  Future<User?> _loginWithFirebase(String email, String password) async {
    try {
      print('🔐 Autenticando no Firebase com email: $email');
      
      final credential = await _firebaseAuth!
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      if (credential.user == null) {
        print('❌ Credenciais inválidas');
        return null;
      }

      final firebaseUid = credential.user!.uid;
      print('✅ Autenticado no Firebase: $firebaseUid');

      // Salvar UID do Firebase
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_firebaseUidKey, firebaseUid);

      // Dados do perfil
      String syncedEmail = credential.user!.email ?? email;
      String syncedUsername = credential.user!.displayName ?? syncedEmail.split('@').first;

      // Tentar carregar dados extras do Firestore
      if (_firestore != null) {
        try {
          final userDoc = await _firestore!
              .collection('users')
              .doc(firebaseUid)
              .get()
              .timeout(const Duration(seconds: 10));

          if (userDoc.exists) {
            final data = userDoc.data();
            syncedUsername = data?['username'] ?? syncedUsername;
            syncedEmail = data?['email'] ?? syncedEmail;
            print('✅ Dados do usuário recuperados do Firestore');
          }
        } catch (e) {
          print('⚠️ Erro ao recuperar dados do Firestore: $e');
        }
      }

      // Garantir usuário local sincronizado com dados do Firebase
      var updatedLocalUser = await _dbService.getUserByEmail(syncedEmail);
      if (updatedLocalUser == null) {
        // Tentar reaproveitar usuário local por username (caso email esteja vazio em versões antigas)
        updatedLocalUser = await _dbService.getUserByUsername(syncedUsername);
      }

      if (updatedLocalUser == null) {
        final userId = await _dbService.createUser(
          syncedUsername,
          syncedEmail,
          password,
          firebaseUid: firebaseUid,
        );
        updatedLocalUser = await _dbService.getUserById(userId);
        print('✅ Usuário local criado após login Firebase');
      } else {
        await _dbService.updateUser(
          updatedLocalUser.id!,
          username: syncedUsername,
          email: syncedEmail,
          password: password,
          firebaseUid: firebaseUid,
        );
        updatedLocalUser = await _dbService.getUserById(updatedLocalUser.id!);
        print('✅ Usuário local atualizado com dados do Firebase');
      }

      if (updatedLocalUser != null) {
        final hasLocalWines = await _dbService.hasAnyWinesForUser(updatedLocalUser.id!);
        if (!hasLocalWines) {
          final otherUserId = await _dbService.findAlternateUserIdWithWines(updatedLocalUser.id!);
          if (otherUserId != null) {
            await _dbService.reassignUserData(
              fromUserId: otherUserId,
              toUserId: updatedLocalUser.id!,
            );
            print('✅ Vinhos locais migrados para o usuario logado');
          }
        }

        await _saveSession(updatedLocalUser.id!);
        
        // SINCRONIZAR VINHOS DO FIREBASE para o dispositivo local
        print('🔄 Iniciando sincronização de vinhos do Firebase...');
        await _syncWinesFromFirebase(firebaseUid, updatedLocalUser.id!);
        
        return updatedLocalUser;
      }
      
      return null;
    } catch (e) {
      print('❌ Erro ao fazer login no Firebase: $e');
      return null;
    }
  }
}
