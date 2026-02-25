import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/wine.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/responsive_wine_image.dart';
import 'wine_detail_screen.dart';
import 'adega_screen.dart';

class AdegaWineListScreen extends StatefulWidget {
  final WineService wineService;
  final UserService? userService;
  final DatabaseService? databaseService;

  const AdegaWineListScreen({
    super.key,
    required this.wineService,
    this.userService,
    this.databaseService,
  });

  @override
  State<AdegaWineListScreen> createState() => _AdegaWineListScreenState();
}

class _AdegaWineListScreenState extends State<AdegaWineListScreen> {
  List<Wine> _wines = [];
  bool _loading = true;
  bool _exporting = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadData();
  }

  List<Wine> get _filteredWines {
    if (_searchQuery.isEmpty) return _wines;
    return _wines.where((wine) {
      final name = wine.name.toLowerCase();
      final region = wine.region.toLowerCase();
      final type = wine.wineType.toLowerCase();
      final description = wine.description.toLowerCase();
      final location = (wine.location ?? '').toLowerCase();
      return name.contains(_searchQuery) ||
          region.contains(_searchQuery) ||
          type.contains(_searchQuery) ||
          description.contains(_searchQuery) ||
          location.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Carregar da coleção dedicada 'adega'
      final adegaWines = await widget.wineService.getAdegaWines();

      if (mounted) {
        setState(() {
          _wines = adegaWines;
          _loading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar vinhos da adega: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_wines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum vinho para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _exporting = true);

    try {
      final excelService = ExcelExportService();

      // Criar planilha Excel personalizada para a adega
      final filePath = await excelService.exportAdegaWinesToExcel(_wines);

      if (!mounted) return;

      setState(() => _exporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exportado com sucesso!\n$filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Abrir',
            textColor: Colors.white,
            onPressed: () async {
              await excelService.openFile(filePath);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _exporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleWines = _filteredWines;
    final content = _wines.isEmpty
        ? Center(
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
                  'Nenhum vinho na adega',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Adicione vinhos pela tela da Adega',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar vinhos',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
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
                          itemCount: visibleWines.length,
                          itemBuilder: (context, index) {
                            return _buildWineCard(visibleWines[index]);
                          },
                        );
                      }

                      // Para múltiplas colunas, usa GridView
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: visibleWines.length,
                        itemBuilder: (context, index) {
                          return _buildWineCard(visibleWines[index]);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Minha Adega Pessoal'),
            if (!_loading)
              Text(
                '${_wines.length} vinhos • ${_wines.fold<int>(0, (sum, w) => sum + w.quantity)} garrafas',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_wines.isNotEmpty)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.file_download),
              tooltip: 'Exportar para Excel',
              onPressed: _exporting ? null : _exportToExcel,
            ),
        ],
      ),
      body: ScrollConfiguration(
        behavior: const _MouseDragScrollBehavior(),
        child: LoadingFadeSwitcher(
          isLoading: _loading,
          loading: const ListSkeleton(itemHeight: 180),
          child: content,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdegaScreen(
                wineService: widget.wineService,
                userService: widget.userService,
              ),
            ),
          );
          _loadData(); // Recarregar lista ao voltar
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Vinho'),
        tooltip: 'Adicionar vinho à adega',
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final imageHeight = imageWidth * 1.4;

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
            // Imagem do vinho
            ResponsiveWineImage(
              imagePath: wine.imagePath,
              imageUrl: wine.imageUrl,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              enablePreview: true,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home,
                                size: 14,
                                color: Colors.purple[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Adega',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.wine_bar, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          wine.wineType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.inventory, size: 14, color: Colors.grey[600]),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          wine.harvestYear != null
                              ? 'Ano: ${wine.harvestYear}'
                              : 'Ano: não informado',
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
                    if (wine.location != null && wine.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              wine.location!,
                              style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
