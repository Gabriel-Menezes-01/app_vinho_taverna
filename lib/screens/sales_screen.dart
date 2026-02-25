import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/loading_widgets.dart';

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

        final Map<String, List<Sale>> groupedSales = {};
        for (final sale in sales) {
          final dateKey = DateFormat('yyyy-MM-dd').format(sale.saleDate);
          if (!groupedSales.containsKey(dateKey)) {
            groupedSales[dateKey] = [];
          }
          groupedSales[dateKey]!.add(sale);
        }

        setState(() {
          _sales = sales;
          _salesByDay = groupedSales;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
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

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final user = await widget.userService.getUserAsync();
      if (user == null) {
        throw Exception('Usuário não encontrado');
      }

      final salesFromDb = await widget.databaseService.getSalesByUserAndMonth(
        user.id!,
        _selectedMonth,
      );

      final wines = await widget.databaseService.getWinesByUser(user.id!);

      final filePath = await _excelService.exportSalesAndStockAdvanced(
        sales: salesFromDb,
        wines: wines,
        selectedMonth: _selectedMonth,
        includeAllInventory: false,
        monthsOption: 0,
      );

      setState(() => _isExporting = false);

      if (mounted) {
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

  Widget _buildDayGroup(DateTime date, List<Sale> daySales) {
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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      DateFormat('EEEE, d "de" MMMM', 'pt_PT').format(date),
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
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${sale.quantity}x • € ${sale.winePrice.toStringAsFixed(2)} cada',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
  }

  @override
  Widget build(BuildContext context) {
    final entries = _salesByDay.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final content = Column(
      children: [
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'pt_PT').format(_selectedMonth),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SummaryCard(
                    icon: Icons.euro_symbol,
                    label: 'Total',
                    value: '€ ${_getTotalValue().toStringAsFixed(2)}',
                  ),
                  const SizedBox(width: 12),
                  _SummaryCard(
                    icon: Icons.local_drink,
                    label: 'Garrafas',
                    value: _getTotalQuantity().toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _sales.isEmpty
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
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecione outro mês ou registre uma venda',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: entries
                      .map((entry) {
                        final date = DateTime.parse(entry.key);
                        return _buildDayGroup(date, entry.value);
                      })
                      .toList(),
                ),
        ),
      ],
    );

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
      body: LoadingFadeSwitcher(
        isLoading: _isLoading,
        loading: const ListSkeleton(itemHeight: 90),
        child: content,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
