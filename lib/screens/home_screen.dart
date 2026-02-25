import 'dart:io';
import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/wine_regions.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../widgets/region_navbar.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/responsive_wine_image.dart';
import 'wine_detail_screen.dart';
import 'add_edit_wine_screen.dart';
import 'sales_screen.dart';
import 'login_screen.dart';
import 'sold_out_wines_screen.dart';
import 'adega_screen.dart';
import 'adega_wine_list_screen.dart';

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
  String _selectedWineType = 'todos'; // todos, tinto, branco, rosé, verde, espumante, champagne
  List<Wine> _wines = [];
  bool _loading = true;
  String? _username;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('📱 HomeScreen._loadData iniciando...');
    setState(() => _loading = true);

    try {
      // VERIFICAÇÃO CRÍTICA: Confirmar que usuário ainda existe no banco
      final user = await widget.userService?.getUserAsync();
      print('👤 Usuário carregado: ${user?.username ?? "NENHUM"}');

      if (user == null || user.id == null) {
        print(
          '❌ Usuário não encontrado no banco! Redirecionando para login...',
        );
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
          // Fallback se rota nomeada não existir
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
        return;
      }

      if (user.id != null) {
        print(
          '⚙️ Configurando usuário ${user.id} no WineService e SyncService',
        );
        widget.wineService.setCurrentUserId(user.id!);
        if (user.email != null && user.email!.isNotEmpty) {
          widget.wineService.setCurrentUserEmail(user.email!);
        }
        widget.syncService.setCurrentUserId(user.id!);

        // Vincular UID do Firebase (se existir) para sincronização entre dispositivos
        final firebaseUid = user.firebaseUid?.isNotEmpty == true
            ? user.firebaseUid
            : await widget.userService?.getFirebaseUid();
        if (firebaseUid != null && firebaseUid.isNotEmpty) {
          widget.syncService.setFirebaseUid(firebaseUid);
          widget.wineService.setFirebaseUid(firebaseUid);
          print('☁️ Firebase UID configurado:');
          print('   ▪ SyncService: $firebaseUid');
          print('   ▪ WineService: $firebaseUid');
        }

        // Tentar sincronizar com servidor
        try {
          print('🔄 Iniciando sincronização...');
          await widget.syncService.syncAll();
          print('✅ Sincronização concluída');
        } catch (e) {
          print('⚠️ Erro na sincronização: $e');
          // Continua mesmo se falhar - dados locais ainda funcionam
        }
      }

      final wines = await widget.wineService.getAllWines();
      print('🍷 Carregados ${wines.length} vinhos');

      if (mounted) {
        setState(() {
          _username = user.username;
          _email = user.email;
          _wines = wines;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Erro em _loadData: $e');
      print('Stack: $stackTrace');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        // Em caso de erro crítico, voltar para login
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
  }

  List<Wine> _filterWines(List<Wine> wines) {
    var filteredWines = wines;

    // Filtrar vinhos da adega pessoal (não mostrar na tela inicial)
    filteredWines = filteredWines.where((wine) => !wine.isFromAdega).toList();

    // Mostrar apenas vinhos disponíveis (quantidade > 0)
    filteredWines = filteredWines.where((wine) => wine.quantity > 0).toList();

    // Filtrar por região ou filtros especiais
    if (_selectedRegion == WineRegions.houseWine) {
      // Vinho da Casa: vinhos marcados como "casa" ou com preço especial
      // Aqui você pode definir sua lógica, por exemplo, vinhos com tag especial
      // Por enquanto, vou mostrar vinhos com preço <= 10 euros como exemplo
      filteredWines = filteredWines
          .where((wine) => wine.price <= 10.0)
          .toList();
    } else if (_selectedRegion == WineRegions.todaySuggestion) {
      // Sugestão do Dia: apenas vinhos marcados manualmente
      filteredWines = filteredWines.where((wine) => wine.isDailySpecial).toList();
    } else if (_selectedRegion != WineRegions.all) {
      filteredWines = filteredWines
          .where((wine) => wine.region == _selectedRegion)
          .toList();
    }

    // Filtrar por tipo de vinho
    if (_selectedWineType != 'todos') {
      filteredWines = filteredWines
          .where((wine) => wine.wineType == _selectedWineType)
          .toList();
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

  void _openAdegaScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdegaScreen(
          wineService: widget.wineService,
          userService: widget.userService,
        ),
      ),
    ).then((_) {
      // Recarregar vinhos ao voltar da adega
      _loadData();
    });
  }

  void _openAdegaListScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdegaWineListScreen(
          wineService: widget.wineService,
          userService: widget.userService,
          databaseService: widget.databaseService,
        ),
      ),
    ).then((_) {
      // Recarregar vinhos ao voltar
      _loadData();
    });
  }

  Future<void> _goToSoldOutTab() async {
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

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Escolha uma opção'),
        content: const Text(
          'Deseja fechar o aplicativo ou entrar com outra conta?',
        ),
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

  Widget _buildWineTypeChip(
    String type,
    String label,
    IconData icon, [
    Color? color,
  ]) {
    final isSelected = _selectedWineType == type;
    final chipColor = color ?? Theme.of(context).primaryColor;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : chipColor),
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
              } else if (value == 'adega') {
                _openAdegaScreen();
              } else if (value == 'adega_list') {
                _openAdegaListScreen();
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
                value: 'adega',
                child: Row(
                  children: [
                    Icon(Icons.wine_bar, size: 20, color: Color(0xFF722F37)),
                    SizedBox(width: 12),
                    Text('🍷 Adega'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'adega_list',
                child: Row(
                  children: [
                    Icon(Icons.home, size: 20, color: Colors.purple),
                    SizedBox(width: 12),
                    Text('Minha Adega Pessoal'),
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
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: Colors.orange,
                    ),
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
              child: Center(child: const Icon(Icons.menu, size: 28)),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactHeight = constraints.maxHeight < 560;
          final regionHeight = isCompactHeight ? 140.0 : 180.0;
          final chipPadding = isCompactHeight ? 6.0 : 12.0;

          return Column(
            children: [
              // Nav bar com regiões
              RegionNavBar(
                selectedRegion: _selectedRegion,
                height: regionHeight,
                onRegionChanged: (region) {
                  setState(() {
                    _selectedRegion = region;
                  });
                },
              ),
              // Botões de tipo de vinho
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: chipPadding,
                ),
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
                      _buildWineTypeChip(
                        'tinto',
                        'Tinto',
                        Icons.wine_bar,
                        Colors.red[900],
                      ),
                      const SizedBox(width: 8),
                      _buildWineTypeChip(
                        'branco',
                        'Branco',
                        Icons.wine_bar,
                        Colors.amber[200],
                      ),
                      const SizedBox(width: 8),
                      _buildWineTypeChip(
                        'rosé',
                        'Rosé',
                        Icons.wine_bar,
                        Colors.pink[300],
                      ),
                      const SizedBox(width: 8),
                      _buildWineTypeChip(
                        'verde',
                        'Verde',
                        Icons.wine_bar,
                        Colors.green[400],
                      ),
                      const SizedBox(width: 8),
                      _buildWineTypeChip(
                        'espumante',
                        'Espumante',
                        Icons.wine_bar,
                        Colors.yellow[700],
                      ),
                      const SizedBox(width: 8),
                      _buildWineTypeChip(
                        'champagne',
                        'Champagne',
                        Icons.wine_bar,
                        Colors.amber[700],
                      ),
                    ],
                  ),
                ),
              ),
              // Lista de vinhos
              Expanded(
                child: LoadingFadeSwitcher(
                  isLoading: _loading,
                  loading: const ListSkeleton(itemHeight: 140),
                  child: _buildWineList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAddWine() async {
    // Navegar para tela de adicionar vinhos sem pedir senha
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
      _loadData(); // Recarregar após adicionar
    }
  }

  Future<bool> _showPasswordDialog() async {
    // Garantir que temos um email válido para autenticar
    final currentUser = await widget.userService?.getUserAsync();
    final email = currentUser?.email ?? _email;

    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessão expirada. Faça login novamente.'),
          ),
        );
      }
      return false;
    }

    final passwordController = TextEditingController();
    String? errorMessage;
    bool obscurePassword = true;

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
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: obscurePassword,
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

                // Buscar usuário do banco para verificar senha
                final user = await widget.userService?.getUserByEmail(email);

                if (!context.mounted) return;

                if (user != null && user.password == password) {
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
            Icon(Icons.wine_bar_outlined, size: 80, color: Colors.grey[400]),
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
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calcula quantas colunas baseado na largura da tela
          int crossAxisCount = 1;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 3;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 2;
          }

          // Se for apenas 1 coluna, usa ListView
          if (crossAxisCount == 1) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: wines.length,
              itemBuilder: (context, index) {
                return _buildWineCard(wines[index]);
              },
            );
          }

          // Para múltiplas colunas, usa GridView
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: wines.length,
            itemBuilder: (context, index) {
              return _buildWineCard(wines[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildWineCard(Wine wine) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageWidth = screenWidth < 360
        ? 90.0
        : screenWidth < 600
            ? 110.0
            : screenWidth < 900
                ? 130.0
                : 150.0;
    final imageHeight = imageWidth * 1.2;

    return Card(
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
            ResponsiveWineImage(
              imagePath: wine.imagePath,
              imageUrl: wine.imageUrl,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              enablePreview: true,
              heroTag: 'wine_${wine.id}',
            ),
            // Informações do vinho
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        Icon(Icons.public, size: 14, color: Colors.grey[600]),
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
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
                    Text(
                      wine.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
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
  bool _obscurePassword = true;

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
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
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
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }

  Future<void> _handleConfirm() async {
    setState(() => isLoading = true);

    try {
      // Buscar usuário do banco de dados
      final user = await widget.userService.getUserByUsernameOrEmail(
        widget.username,
      );

      if (user == null) {
        setState(() {
          error = 'Usuário não encontrado';
          isLoading = false;
        });
        return;
      }

      // Verificar senha diretamente do banco
      if (user.password == passController.text) {
        if (!mounted) return;
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

  const _FullLoginDialog({required this.userService, this.onUsernameChanged});

  @override
  State<_FullLoginDialog> createState() => _FullLoginDialogState();
}

class _FullLoginDialogState extends State<_FullLoginDialog> {
  final userController = TextEditingController();
  final passController = TextEditingController();
  String? error;
  bool isLoading = false;
  bool _obscurePassword = true;

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
            decoration: InputDecoration(
              labelText: 'Senha',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
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
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar'),
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
