import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/user.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _dbService;
  final bool firebaseEnabled;
  static const String _currentUserKey = 'current_user_id';

  AuthService(this._dbService, {this.firebaseEnabled = false});

  // Hash de senha usando SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Registrar novo usuário
  Future<bool> register(String username, String password) async {
    try {
      // Verificar se usuário já existe
      final existing = await _dbService.getUserByUsername(username);
      if (existing != null) {
        return false; // Usuário já existe
      }

      // Criar novo usuário com senha hash
      final hashedPassword = _hashPassword(password);
      final userId = await _dbService.createUser(username, hashedPassword);

      // Salvar sessão
      await _saveSession(userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Login de usuário
  Future<User?> login(String username, String password) async {
    try {
      final user = await _dbService.getUserByUsername(username);
      if (user == null) return null;

      // Verificar senha
      final hashedPassword = _hashPassword(password);
      if (user.password != hashedPassword) {
        return null;
      }

      // Salvar sessão
      await _saveSession(user.id!);

      return user;
    } catch (e) {
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

      if (userId == null) return null;

      return await _dbService.getUserById(userId);
    } catch (e) {
      return null;
    }
  }

  // Verificar se há usuário logado
  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
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
}
