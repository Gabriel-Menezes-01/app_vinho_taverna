import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/sale.dart';
import '../models/wine.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/export_dialog.dart';

class SalesScreen extends StatefulWidget {
  final UserService userService;
  final DatabaseService databaseService;

  const SalesScreen({
    super.key,
    required this.userService,
    required this.databaseService,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Sale> _sales = [];
  Map<String, List<Sale>> _salesByDay = {};
  Map<String, List<Sale>> _salesByWine = {};
  bool _isLoading = true;
  bool _isExporting = false;
  DateTime _selectedMonth = DateTime.now();
  final ExcelExportService _excelService = ExcelExportService();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_PT', null);
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await widget.userService.getUserAsync();
      if (user != null) {
        final sales = await widget.databaseService.getSalesByUserAndMonth(
          user.id!,
          _selectedMonth,
        );
        
        // Agrupar vendas por dia
        final Map<String, List<Sale>> groupedSales = {};
        for (var sale in sales) {
          final dateKey = DateFormat('yyyy-MM-dd').format(sale.saleDate);
          if (!groupedSales.containsKey(dateKey)) {
            groupedSales[dateKey] = [];
          }
          groupedSales[dateKey]!.add(sale);
        }

        // Agrupar vendas por vinho
        final Map<String, List<Sale>> groupedByWine = {};
        for (var sale in sales) {
          if (!groupedByWine.containsKey(sale.wineName)) {
            groupedByWine[sale.wineName] = [];
          }
          groupedByWine[sale.wineName]!.add(sale);
        }
        
        setState(() {
          _sales = sales;
          _salesByDay = groupedSales;
          _salesByWine = groupedByWine;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar vendas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Selecione o mês',
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadSales();
    }
  }

  double _getTotalValue() {
    return _sales.fold(0, (sum, sale) => sum + sale.totalValue);
  }

  int _getTotalQuantity() {
    return _sales.fold(0, (sum, sale) => sum + sale.quantity);
  }

  List<String> _getSoldOutWines() {
    final soldOut = <String>[];
    _salesByWine.forEach((wineName, sales) {
      final totalQty = sales.fold<int>(0, (sum, sale) => sum + sale.quantity);
      if (totalQty > 0) {
        soldOut.add(wineName);
      }
    });
    return soldOut;
  }

  Future<void> _exportToExcel() async {
    // Mostrar diálogo de opções
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ExportDialog(),
    );

    if (result == null) return;

    setState(() => _isExporting = true);
    
    try {
      final user = await widget.userService.getUserAsync();
      if (user == null) {
        throw Exception('Usuário não encontrado');
      }
      
      // Buscar todos os vinhos do usuário
      final wines = await widget.databaseService.getWinesByUser(user.id!);
      
      // Exportar dados com as opções selecionadas
      final filePath = await _excelService.exportSalesAndStockAdvanced(
        sales: _sales,
        wines: wines,
        selectedMonth: _selectedMonth,
        includeAllInventory: result['includeAllInventory'] as bool,
        monthsOption: result['monthsOption'] as int,
      );
      
      setState(() => _isExporting = false);
      
      if (mounted) {
        // Mostrar snackbar com opção de abrir
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relatório exportado com sucesso!\n$filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Abrir',
              textColor: Colors.white,
              onPressed: () {
                _openExportedFile(filePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openExportedFile(String filePath) async {
    try {
      await _excelService.openFile(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir arquivo: $e'),
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
        title: const Text('Vendas do Mês'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Selecionar mês',
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download),
            onPressed: _isExporting ? null : _exportToExcel,
            tooltip: 'Exportar para Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Cabeçalho com mês selecionado e resumo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', 'pt_PT').format(_selectedMonth),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_getTotalQuantity()}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Garrafas vendidas',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '€ ${_getTotalValue().toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Total vendido',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Lista de vendas agrupadas por dia
                Expanded(
                  child: _salesByDay.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma venda neste mês',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _salesByDay.length,
                          itemBuilder: (context, index) {
                            final dateKey = _salesByDay.keys.elementAt(index);
                            final daySales = _salesByDay[dateKey]!;
                            final date = DateTime.parse(dateKey);
                            
                            final dayTotal = daySales.fold<double>(
                              0,
                              (sum, sale) => sum + sale.totalValue,
                            );
                            final dayQuantity = daySales.fold<int>(
                              0,
                              (sum, sale) => sum + sale.quantity,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Theme.of(context).primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat('EEEE, d \"de\" MMMM', 'pt_PT')
                                                  .format(date),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$dayQuantity garrafas • € ${dayTotal.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: daySales.map((sale) {
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 4,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.purple.withOpacity(0.2),
                                        child: const Icon(
                                          Icons.wine_bar,
                                          color: Colors.purple,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        sale.wineName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${sale.quantity}x • € ${sale.winePrice.toStringAsFixed(2)} cada',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      trailing: Text(
                                        '€ ${sale.totalValue.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
