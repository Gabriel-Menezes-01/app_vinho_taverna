import '../models/wine.dart';
import 'database_service.dart';

class WineService {
  final DatabaseService _dbService;
  final bool firebaseEnabled;
  int? _currentUserId;

  WineService(this._dbService, {this.firebaseEnabled = false});

  // Definir usuário atual
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  // Verificar se há usuário definido
  int get _userId {
    if (_currentUserId == null) {
      throw Exception('Nenhum usuário está logado');
    }
    return _currentUserId!;
  }

  // Adicionar um vinho
  Future<void> addWine(Wine wine) async {
    await _dbService.insertWine(wine, _userId);
  }

  // Atualizar um vinho
  Future<void> updateWine(Wine wine) async {
    await _dbService.updateWine(wine, _userId);
  }

  // Excluir um vinho
  Future<void> deleteWine(String id) async {
    await _dbService.deleteWine(id, _userId);
  }

  // Obter um vinho pelo ID
  Future<Wine?> getWine(String id) async {
    return await _dbService.getWineById(id, _userId);
  }

  // Obter todos os vinhos do usuário atual
  Future<List<Wine>> getAllWines() async {
    return await _dbService.getWinesByUser(_userId);
  }
}
