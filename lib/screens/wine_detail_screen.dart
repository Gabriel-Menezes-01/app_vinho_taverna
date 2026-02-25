import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/sale.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';
import '../widgets/responsive_wine_image.dart';
import 'add_edit_wine_screen.dart';
import 'adega_screen.dart';

class WineDetailScreen extends StatefulWidget {
  final Wine wine;
  final WineService wineService;
  final UserService? userService;
  final DatabaseService? databaseService;

  const WineDetailScreen({
    super.key,
    required this.wine,
    required this.wineService,
    this.userService,
    this.databaseService,
  });

  @override
  State<WineDetailScreen> createState() => _WineDetailScreenState();
}

class _WineDetailScreenState extends State<WineDetailScreen> {
  late Wine currentWine;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    currentWine = widget.wine;
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (widget.userService == null) return;
    final user = await widget.userService!.getUserAsync();
    if (mounted) {
      setState(() {
        _currentUsername = user?.username;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final imageHeight = (screenSize.height * 0.35).clamp(200.0, 360.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Vinho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (widget.userService != null && !currentWine.isFromAdega) {
                final ok = await _requirePasswordConfirmation(context);
                if (!ok) return;
              }

              if (!context.mounted) return;

              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => currentWine.isFromAdega
                      ? AdegaScreen(
                          wineService: widget.wineService,
                          userService: widget.userService,
                          wine: currentWine,
                        )
                      : AddEditWineScreen(
                          wineService: widget.wineService,
                          userService: widget.userService!,
                          wine: currentWine,
                        ),
                ),
              );

              if (updated == true) {
                _refreshWineData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _handleDelete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Imagem em destaque
            Hero(
              tag: 'wine_${currentWine.id}',
              child: ResponsiveWineImage(
                imagePath: currentWine.imagePath,
                imageUrl: currentWine.imageUrl,
                width: screenSize.width,
                height: imageHeight,
                fit: BoxFit.contain,
                enablePreview: true,
              ),
            ),
            // Informações do vinho
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome e avaliação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          currentWine.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Preço (não mostrar na Adega Pessoal)
                  if (!currentWine.isFromAdega) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '€ ${currentWine.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Quantidade disponível
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory,
                          color: Colors.green[700],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${currentWine.quantity} garrafas disponíveis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Região
                  Row(
                    children: [
                      Icon(Icons.public, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        currentWine.region,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Local de armazenamento
                  if (currentWine.location != null && currentWine.location!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentWine.location!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Descrição
                  const Text(
                    'Descrição',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentWine.description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.65,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Botão Vendido (não mostrar na Adega Pessoal)
                  if (!currentWine.isFromAdega) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: currentWine.quantity > 0 ? _handleSold : null,
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text(
                          'Vendido',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Botão Repor (aparece quando esgotado)
                  if (currentWine.quantity <= 0)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showRestockDialog,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Repor estoque',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.orange),
                          foregroundColor: Colors.orange[800],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _requirePasswordConfirmation(BuildContext context) async {
    // Se soubermos o usuário logado, pedimos apenas a senha; caso contrário, usamos o diálogo completo.
    if (_currentUsername == null) {
      return _showLoginDialog(context);
    }

    final passController = TextEditingController();
    String? error;
    bool obscurePassword = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Confirmar senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Usuário: $_currentUsername'),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  errorText: error,
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
            TextButton(
              onPressed: () async {
                // Buscar usuário do banco
                final user = await widget.userService!.getUserByUsernameOrEmail(_currentUsername!);
                
                if (!context.mounted) return;
                
                if (user != null && user.password == passController.text) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => error = 'Senha incorreta');
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    passController.dispose();
    return result ?? false;
  }

  Future<void> _handleSold() async {
    if (currentWine.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há garrafas disponíveis!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Registrar a venda
      if (widget.databaseService != null && widget.userService != null) {
        final user = await widget.userService!.getUserAsync();
        if (user != null) {
          final sale = Sale(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            wineId: currentWine.id,
            wineName: currentWine.name,
            winePrice: currentWine.price,
            quantity: 1,
            saleDate: DateTime.now(),
            userId: user.id!,
          );
          await widget.databaseService!.insertSale(sale);
        }
      }

      // Diminuir a quantidade em 1
      final updatedWine = Wine(
        id: currentWine.id,
        name: currentWine.name,
        price: currentWine.price,
        description: currentWine.description,
        imagePath: currentWine.imagePath,
          imageUrl: currentWine.imageUrl,
        region: currentWine.region,
        wineType: currentWine.wineType,
        quantity: currentWine.quantity - 1,
        location: currentWine.location,
        harvestYear: currentWine.harvestYear,
        synced: false,
        isFromAdega: currentWine.isFromAdega,
        lastModified: DateTime.now(),
        createdAt: currentWine.createdAt,
      );

      await widget.wineService.updateWine(updatedWine);

      setState(() {
        currentWine = updatedWine;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Venda registrada! ${currentWine.quantity} garrafas restantes',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar venda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRestockDialog() async {
      final controller = TextEditingController(text: '1');
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Repor estoque'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantidade a adicionar',
              hintText: 'Ex: 6',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Informe uma quantidade válida (> 0).'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Repor'),
            ),
          ],
        ),
      );

      controller.dispose();

      if (result != null && result > 0) {
        await _restockWine(result);
      }
    }

    Future<void> _restockWine(int quantityToAdd) async {
      try {
        final updatedWine = Wine(
          id: currentWine.id,
          name: currentWine.name,
          price: currentWine.price,
          description: currentWine.description,
          imagePath: currentWine.imagePath,
          imageUrl: currentWine.imageUrl,
          region: currentWine.region,
          wineType: currentWine.wineType,
          quantity: currentWine.quantity + quantityToAdd,
          location: currentWine.location,
          harvestYear: currentWine.harvestYear,
          synced: false,
          isFromAdega: currentWine.isFromAdega,
          lastModified: DateTime.now(),
          createdAt: currentWine.createdAt,
        );

        await widget.wineService.updateWine(updatedWine);

        if (mounted) {
          setState(() {
            currentWine = updatedWine;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estoque reposto: +$quantityToAdd garrafas'),
              backgroundColor: Colors.green,
            ),
          );

          // Volta para a tela anterior já atualizada
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao repor estoque: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

  Future<void> _refreshWineData() async {
    try {
      final updatedWine = await widget.wineService.getWine(currentWine.id);
      if (updatedWine != null && mounted) {
        setState(() {
          currentWine = updatedWine;
        });
      }
    } catch (e) {
      // Silenciosamente ignora erro ao atualizar
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    if (widget.userService != null) {
      final isLogged = await widget.userService!.isLoggedIn();
      if (!isLogged) {
        final ok = await _showLoginDialog(context);
        if (!ok) return;
      }
    }

    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o vinho "${currentWine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      if (currentWine.isFromAdega) {
        await widget.wineService.deleteAdegaWine(currentWine.id);
      } else {
        await widget.wineService.deleteWine(currentWine.id);
      }
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _showLoginDialog(BuildContext context) async {
    final userController = TextEditingController();
    final passController = TextEditingController();
    String? error;
    bool obscurePassword = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Login Necessário'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: 'Usuário'),
              ),
              TextField(
                controller: passController,
                decoration: InputDecoration(
                  labelText: 'Senha',
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
            TextButton(
              onPressed: () async {
                // Buscar usuário do banco
                final user = await widget.userService!.getUserByUsernameOrEmail(userController.text.trim());
                
                if (!context.mounted) return;
                
                if (user != null && user.password == passController.text) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => error = 'Usuário ou senha inválidos');
                }
              },
              child: const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
