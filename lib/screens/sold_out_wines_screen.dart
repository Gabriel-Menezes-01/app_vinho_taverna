import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/responsive_wine_image.dart';
import 'wine_detail_screen.dart';

class SoldOutWinesScreen extends StatefulWidget {
  final WineService wineService;
  final UserService userService;
  final DatabaseService databaseService;

  const SoldOutWinesScreen({
    super.key,
    required this.wineService,
    required this.userService,
    required this.databaseService,
  });

  @override
  State<SoldOutWinesScreen> createState() => _SoldOutWinesScreenState();
}

class _SoldOutWinesScreenState extends State<SoldOutWinesScreen> {
  List<Wine> _wines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final user = await widget.userService.getUserAsync();
      if (user != null) {
        final wines = await widget.wineService.getAllWines();
        final soldOutWines = wines.where((wine) => wine.quantity == 0).toList();

        setState(() {
          _wines = soldOutWines;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vinhos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _wines.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Nenhum vinho esgotado',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todos os vinhos ainda têm garrafas!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        : RefreshIndicator(
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
                    itemCount: _wines.length,
                    itemBuilder: (context, index) {
                      return _buildWineCard(_wines[index]);
                    },
                  );
                }

                // Para múltiplas colunas, usa GridView
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _wines.length,
                  itemBuilder: (context, index) {
                    return _buildWineCard(_wines[index]);
                  },
                );
              },
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vinhos Esgotados'),
        backgroundColor: Colors.orange[700],
      ),
      body: LoadingFadeSwitcher(
        isLoading: _loading,
        loading: const ListSkeleton(itemHeight: 120),
        child: content,
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
    final imageHeight = imageWidth * 1.3;

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
          _loadData();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
            ResponsiveWineImage(
              imagePath: wine.imagePath,
              imageUrl: wine.imageUrl,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              enablePreview: true,
            ),
            // Informações
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wine.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '€ ${wine.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ESGOTADO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${wine.region} • ${wine.wineType}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Repor estoque'),
                        onPressed: () => _showRestockDialog(wine),
                      ),
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

  Future<void> _showRestockDialog(Wine wine) async {
    final controller = TextEditingController(text: '1');
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Repor "${wine.name}"'),
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

    if (quantity == null || quantity <= 0) return;

    try {
      final updatedWine = Wine(
        id: wine.id,
        name: wine.name,
        price: wine.price,
        description: wine.description,
        imagePath: wine.imagePath,
        imageUrl: wine.imageUrl,
        region: wine.region,
        wineType: wine.wineType,
        quantity: wine.quantity + quantity,
        location: wine.location,
        harvestYear: wine.harvestYear,
        synced: false,
        isFromAdega: wine.isFromAdega,
        lastModified: DateTime.now(),
        createdAt: wine.createdAt,
      );

      await widget.wineService.updateWine(updatedWine);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estoque reposto: +$quantity garrafas'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
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
}
