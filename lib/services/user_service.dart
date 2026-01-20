import '../models/user.dart';
import 'database_service.dart';
import 'auth_service.dart';

// Classe mantida para compatibilidade com código existente
class UserService {
  final AuthService _authService;
  final bool firebaseEnabled;

  UserService(DatabaseService dbService, {this.firebaseEnabled = false})
      : _authService = AuthService(dbService, firebaseEnabled: firebaseEnabled);

  // Login com email
  Future<bool> login(String email, String password) async {
    final user = await _authService.login(email, password);
    return user != null;
  }

  // Registro
  Future<bool> register(String username, String email, String password) async {
    return await _authService.register(username, email, password);
  }

  // Obter usuário atual
  Future<User?> getUserAsync() async {
    return await _authService.getCurrentUser();
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
  }

  // Verificar se está logado
  Future<bool> isLoggedIn() async {
    return await _authService.isLoggedIn();
  }

  // Obter ID do usuário atual
  Future<int?> getCurrentUserId() async {
    return await _authService.getCurrentUserId();
  }
}
