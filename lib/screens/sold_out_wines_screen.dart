import 'dart:io';
import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../services/database_service.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vinhos Esgotados'),
        backgroundColor: Colors.orange[700],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum vinho esgotado',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Todos os vinhos ainda têm garrafas!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _wines.length,
                    itemBuilder: (context, index) {
                      final wine = _wines[index];
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
                            _loadData();
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Imagem
                              Container(
                                width: 120,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                ),
                                child: wine.imagePath != null
                                    ? Image.file(
                                        File(wine.imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(
                                              Icons.wine_bar,
                                              size: 50,
                                              color: Colors.grey[400],
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.wine_bar,
                                          size: 50,
                                          color: Colors.grey[400],
                                        ),
                                      ),
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
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
                    },
                  ),
                ),
    );
  }
}
