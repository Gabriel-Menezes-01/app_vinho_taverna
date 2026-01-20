import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Serviço de autenticação centralizada usando Firebase Auth
/// Todos os dispositivos compartilham o mesmo login
class FirebaseAuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registrar novo usuário (cria conta Firebase + perfil no Firestore)
  Future<User?> register(String username, String password) async {
    try {
      print('🔥 Iniciando registro no Firebase para: $username');
      
      // Email fake para usar Firebase Auth (username@app.local)
      final email = '$username@app.local';
      
      print('📧 Email: $email');
      
      // Criar conta no Firebase Auth
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      print('✅ Usuário criado no Firebase Auth com UID: $uid');

      // Criar perfil do usuário no Firestore
      await _firestore.collection('users').doc(uid).set({
        'username': username,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ Perfil criado no Firestore para: $username');

      return User(
        id: uid.hashCode, // ID numérico para compatibilidade
        username: username,
        email: email,
        password: _hashPassword(password),
        createdAt: DateTime.now(),
        firebaseUid: uid,
      );
    } catch (e) {
      print('❌ Erro ao registrar: $e');
      print('Stack trace: $e');
      return null;
    }
  }

  /// Login (usa Firebase Auth)
  Future<User?> login(String username, String password) async {
    try {
      print('🔥 Iniciando login no Firebase para: $username');
      
      final email = '$username@app.local';
      
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      print('✅ Login bem-sucedido! UID: $uid');

      // Buscar perfil no Firestore
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        print('⚠️ Perfil não encontrado no Firestore');
        return null;
      }

      final data = doc.data()!;
      print('✅ Perfil carregado: ${data['username']}');
      
      return User(
        id: uid.hashCode,
        username: data['username'],
        email: data['email'] as String? ?? email,
        password: _hashPassword(password),
        createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        firebaseUid: uid,
      );
    } catch (e) {
      print('❌ Erro ao fazer login: $e');
      return null;
    }
  }

  /// Obter usuário logado atual
  Future<User?> getCurrentUser() async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) return null;

      final uid = firebaseUser.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) return null;

      final data = doc.data()!;
      return User(
        id: uid.hashCode,
        username: data['username'],
        email: data['email'] as String? ?? firebaseUser.email ?? '',
        password: '', // Não armazenamos senha
        createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        firebaseUid: uid,
      );
    } catch (e) {
      print('Erro ao obter usuário: $e');
      return null;
    }
  }

  /// Verificar se está logado
  Future<bool> isLoggedIn() async {
    return _firebaseAuth.currentUser != null;
  }

  /// Logout
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  /// Obter Firebase UID do usuário logado
  String? getCurrentFirebaseUid() {
    return _firebaseAuth.currentUser?.uid;
  }

  /// Obter ID numérico do usuário logado (para compatibilidade)
  Future<int?> getCurrentUserId() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return null;
    return uid.hashCode;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
