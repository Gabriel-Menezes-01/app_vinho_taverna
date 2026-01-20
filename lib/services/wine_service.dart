import '../models/wine.dart';
import 'database_service.dart';
import 'sync_service.dart';

class WineService {
  final DatabaseService _dbService;
  final bool firebaseEnabled;
  final SyncService syncService;
  int? _currentUserId;

  WineService(this._dbService, {this.firebaseEnabled = false, required this.syncService});

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
    print('🍷 Adicionando vinho: ${wine.name}');
    await _dbService.insertWine(wine, _userId);
    print('✅ Vinho adicionado localmente');
    
    // Tentar sincronizar com Firebase em background
    print('☁️ Tentando sincronizar com Firebase...');
    try {
      await syncService.uploadUnsyncedWines();
    } catch (e) {
      print('⚠️ Erro ao sincronizar vinho: $e');
    }
  }

  // Atualizar um vinho
  Future<void> updateWine(Wine wine) async {
    print('🍷 Atualizando vinho: ${wine.name}');
    await _dbService.updateWine(wine, _userId);
    print('✅ Vinho atualizado localmente');
    
    // Tentar sincronizar com Firebase em background
    print('☁️ Tentando sincronizar com Firebase...');
    try {
      await syncService.uploadUnsyncedWines();
    } catch (e) {
      print('⚠️ Erro ao sincronizar vinho: $e');
    }
  }

  // Excluir um vinho
  Future<void> deleteWine(String id) async {
    print('🗑️ Deletando vinho: $id');
    await _dbService.deleteWine(id, _userId);
    print('✅ Vinho deletado localmente');
    
    // Tentar sincronizar com Firebase em background
    print('☁️ Tentando sincronizar deleção com Firebase...');
    try {
      await syncService.deleteWineFromServer(id);
    } catch (e) {
      print('⚠️ Erro ao sincronizar deleção: $e');
    }
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
