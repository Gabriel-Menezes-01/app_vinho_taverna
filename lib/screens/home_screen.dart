import 'dart:io';
import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/wine_regions.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../widgets/region_navbar.dart';
import 'wine_detail_screen.dart';
import 'add_edit_wine_screen.dart';
import 'sales_screen.dart';
import 'login_screen.dart';
import 'sold_out_wines_screen.dart';

class HomeScreen extends StatefulWidget {
  final WineService wineService;
  final UserService? userService;
  final SyncService syncService;
  final DatabaseService databaseService;

  const HomeScreen({
    super.key, 
    required this.wineService, 
    this.userService,
    required this.syncService,
    required this.databaseService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedRegion = WineRegions.all;
  String _selectedWineType = 'todos'; // todos, tinto, branco, rosé, verde
  List<Wine> _wines = [];
  bool _loading = true;
  String? _username;
  bool _isAuthenticatedForAddingWine = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }



  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    // Carregar usuário atual e configurar no WineService
    final user = await widget.userService?.getUserAsync();
    
    if (user != null && user.id != null) {
      widget.wineService.setCurrentUserId(user.id!);
      widget.syncService.setCurrentUserId(user.id!);
      
      // Tentar sincronizar com servidor
      try {
        await widget.syncService.syncAll();
      } catch (e) {
        print('Erro na sincronização: $e');
        // Continua mesmo se falhar - dados locais ainda funcionam
      }
    }
    
    final wines = await widget.wineService.getAllWines();
    
    if (mounted) {
      setState(() {
        _username = user?.username;
        _wines = wines;
        _loading = false;
      });
    }
  }

  List<Wine> _filterWines(List<Wine> wines) {
    var filteredWines = wines;
    
    // Mostrar apenas vinhos disponíveis (quantidade > 0)
    filteredWines = filteredWines.where((wine) => wine.quantity > 0).toList();
    
    // Filtrar por região
    if (_selectedRegion != WineRegions.all) {
      filteredWines = filteredWines.where((wine) => wine.region == _selectedRegion).toList();
    }
    
    // Filtrar por tipo de vinho
    if (_selectedWineType != 'todos') {
      filteredWines = filteredWines.where((wine) => wine.wineType == _selectedWineType).toList();
    }
    
    return filteredWines;
  }

  void _openSalesScreen() {
    if (widget.userService != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SalesScreen(
            userService: widget.userService!,
            databaseService: widget.databaseService,
          ),
        ),
      );
    }
  }

  Future<void> _goToSoldOutTab() async {
    // Pedir senha antes de acessar
    final authenticated = await _showPasswordDialog();
    if (!authenticated || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SoldOutWinesScreen(
          wineService: widget.wineService,
          userService: widget.userService!,
          databaseService: widget.databaseService,
        ),
      ),
    );
    _loadData(); // Recarregar ao voltar
  }

  Future<void> _logout() async {
    if (widget.userService == null) return;

    final passwordOk = await _confirmPasswordForLogout();
    if (!passwordOk || !mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Escolha uma opção'),
        content: const Text('Deseja fechar o aplicativo ou entrar com outra conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'switch'),
            child: const Text('Entrar em outra conta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'close'),
            child: const Text('Fechar aplicativo'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == 'close') {
      exit(0);
    } else if (action == 'switch') {
      try {
        await widget.userService!.logout();
      } catch (e) {
        debugPrint('Erro ao fazer logout: $e');
      }
      
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            userService: widget.userService!,
            wineService: widget.wineService,
            syncService: widget.syncService,
            databaseService: widget.databaseService,
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<bool> _confirmPasswordForLogout() async {
    final username = _username;

    if (username == null || widget.userService == null) {
      // Fallback: exige login completo
      return _showFullLoginDialog();
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PasswordConfirmDialog(
        username: username,
        userService: widget.userService!,
      ),
    );

    return result ?? false;
  }

  Future<bool> _showFullLoginDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FullLoginDialog(
        userService: widget.userService!,
        onUsernameChanged: (username) {
          if (mounted) {
            setState(() => _username = username);
          }
        },
      ),
    );

    return result ?? false;
  }

  Widget _buildWineTypeChip(String type, String label, IconData icon, [Color? color]) {
    final isSelected = _selectedWineType == type;
    final chipColor = color ?? Theme.of(context).primaryColor;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : chipColor,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedWineType = type;
        });
      },
      selectedColor: chipColor,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      elevation: isSelected ? 4 : 1,
      pressElevation: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartas de Vinhos'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add') {
                _handleAddWine();
              } else if (value == 'sales') {
                _openSalesScreen();
              } else if (value == 'soldout') {
                _goToSoldOutTab();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Header com nome do usuário
              if (_username != null)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usuário logado:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _username!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_username != null) const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Adicionar vinho'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'sales',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 20, color: Colors.purple),
                    SizedBox(width: 12),
                    Text('Vendas do Mês'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'soldout',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Vinhos Esgotados'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: const Icon(Icons.menu, size: 28),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Nav bar com regiões
          RegionNavBar(
            selectedRegion: _selectedRegion,
            onRegionChanged: (region) {
              setState(() {
                _selectedRegion = region;
              });
            },
          ),
          // Botões de tipo de vinho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildWineTypeChip('todos', 'Todos', Icons.wine_bar),
                  const SizedBox(width: 8),
                  _buildWineTypeChip('tinto', 'Tinto', Icons.wine_bar, Colors.red[900]),
                  const SizedBox(width: 8),
                  _buildWineTypeChip('branco', 'Branco', Icons.wine_bar, Colors.amber[200]),
                  const SizedBox(width: 8),
                  _buildWineTypeChip('rosé', 'Rosé', Icons.wine_bar, Colors.pink[300]),
                  const SizedBox(width: 8),
                  _buildWineTypeChip('verde', 'Verde', Icons.wine_bar, Colors.green[400]),
                ],
              ),
            ),
          ),
          // Lista de vinhos
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildWineList(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddWine() async {
    // Pedir a senha para autenticação
    final authenticated = await _showPasswordDialog();
    if (!authenticated) {
      return;
    }

    // Marcar como autenticado para adicionar vinhos
    setState(() {
      _isAuthenticatedForAddingWine = true;
    });

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEditWineScreen(
            wineService: widget.wineService,
            userService: widget.userService!,
          ),
        ),
      );
      // Limpar autenticação ao sair da tela de adicionar vinhos
      setState(() {
        _isAuthenticatedForAddingWine = false;
      });
      _loadData(); // Recarregar após adicionar
    }
  }

  Future<bool> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmar Senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Digite sua senha para adicionar vinhos:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;

                if (password.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Digite a senha';
                  });
                  return;
                }

                // Verificar senha com o username atual
                final success = await widget.userService?.login(_username ?? '', password) ?? false;
                
                if (!context.mounted) return;

                if (success) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() {
                    errorMessage = 'Senha incorreta';
                  });
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();

    return result ?? false;
  }

  Widget _buildWineList() {
    final wines = _filterWines(_wines);

    if (_wines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wine_bar_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum vinho cadastrado',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione seu primeiro vinho!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (wines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum vinho disponível',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Filtre por outra região ou tipo',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: wines.length,
        itemBuilder: (context, index) {
          final wine = wines[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WineDetailScreen(
                      wine: wine,
                      wineService: widget.wineService,
                      userService: widget.userService,
                      databaseService: widget.databaseService,
                    ),
                  ),
                );
                _loadData(); // Recarregar após visualizar detalhes
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagem do vinho
                  Hero(
                    tag: 'wine_${wine.id}',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(color: Colors.grey[200]),
                      child: wine.imagePath != null
                          ? Image.file(
                              File(wine.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.wine_bar,
                                  size: 50,
                                  color: Colors.grey[400],
                                );
                              },
                            )
                          : Icon(
                              Icons.wine_bar,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                    ),
                  ),
                  // Informações do vinho
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  wine.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '€ ${wine.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.public,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  wine.region,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${wine.quantity} garrafas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            wine.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Widget separado para o diálogo de confirmação de senha
class _PasswordConfirmDialog extends StatefulWidget {
  final String username;
  final UserService userService;

  const _PasswordConfirmDialog({
    required this.username,
    required this.userService,
  });

  @override
  State<_PasswordConfirmDialog> createState() => _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState extends State<_PasswordConfirmDialog> {
  final passController = TextEditingController();
  String? error;
  bool isLoading = false;

  @override
  void dispose() {
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Confirmar senha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Usuário: ${widget.username}'),
          const SizedBox(height: 12),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          TextField(
            controller: passController,
            decoration: const InputDecoration(
              labelText: 'Senha',
            ),
            obscureText: true,
            enabled: !isLoading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: isLoading ? null : _handleConfirm,
          child: isLoading ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ) : const Text('Confirmar'),
        ),
      ],
    );
  }

  Future<void> _handleConfirm() async {
    setState(() => isLoading = true);
    
    try {
      final ok = await widget.userService.login(
        widget.username,
        passController.text,
      );
      
      if (!mounted) return;
      
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          error = 'Senha incorreta';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Erro ao verificar senha';
        isLoading = false;
      });
    }
  }
}

// Widget separado para o diálogo de login completo
class _FullLoginDialog extends StatefulWidget {
  final UserService userService;
  final Function(String)? onUsernameChanged;

  const _FullLoginDialog({
    required this.userService,
    this.onUsernameChanged,
  });

  @override
  State<_FullLoginDialog> createState() => _FullLoginDialogState();
}

class _FullLoginDialogState extends State<_FullLoginDialog> {
  final userController = TextEditingController();
  final passController = TextEditingController();
  String? error;
  bool isLoading = false;

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Confirmar usuário'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          TextField(
            controller: userController,
            decoration: const InputDecoration(labelText: 'Usuário'),
            enabled: !isLoading,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passController,
            decoration: const InputDecoration(
              labelText: 'Senha',
            ),
            obscureText: true,
            enabled: !isLoading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: isLoading ? null : _handleConfirm,
          child: isLoading ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ) : const Text('Confirmar'),
        ),
      ],
    );
  }

  Future<void> _handleConfirm() async {
    setState(() => isLoading = true);
    
    try {
      final ok = await widget.userService.login(
        userController.text.trim(),
        passController.text,
      );
      
      if (!mounted) return;
      
      if (ok) {
        widget.onUsernameChanged?.call(userController.text.trim());
        Navigator.pop(context, true);
      } else {
        setState(() {
          error = 'Credenciais inválidas';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Erro ao verificar credenciais';
        isLoading = false;
      });
    }
  }
}
