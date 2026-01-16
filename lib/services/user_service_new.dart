import '../models/user.dart';
import 'database_service.dart';
import 'auth_service.dart';

// Classe mantida para compatibilidade com código existente
class UserService {
  final AuthService _authService;

  UserService(DatabaseService dbService)
      : _authService = AuthService(dbService);

  // Login
  Future<bool> login(String username, String password) async {
    final user = await _authService.login(username, password);
    return user != null;
  }

  // Registro
  Future<bool> register(String username, String password) async {
    return await _authService.register(username, password);
  }

  // Obter usuário atual
  User? getUser() {
    // Método síncrono removido - use getUserAsync
    return null;
  }

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
