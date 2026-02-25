import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../models/sale.dart';
import '../models/wine.dart';

class ExcelExportService {
  // Exportação com opções avançadas
  Future<String> exportSalesAndStockAdvanced({
    required List<Sale> sales,
    required List<Wine> wines,
    required DateTime selectedMonth,
    required bool includeAllInventory,
    required int monthsOption,
  }) async {
    // Solicitar permissões
    await _requestPermissions();

    var excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Determinar o período de exportação
    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (monthsOption) {
      case 0: // Apenas o mês atual
        startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
        endDate = DateTime(
          selectedMonth.year,
          selectedMonth.month + 1,
          0,
          23,
          59,
          59,
        );
        break;
      case 1: // Últimos 3 meses
        startDate = DateTime(selectedMonth.year, selectedMonth.month - 2, 1);
        break;
      case 2: // Últimos 6 meses
        startDate = DateTime(selectedMonth.year, selectedMonth.month - 5, 1);
        break;
      case 3: // Todo o histórico
        startDate = DateTime(2020, 1, 1);
        break;
      default:
        startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    }

    // Filtrar vendas pelo período
    final filteredSales = sales.where((sale) {
      return sale.saleDate.isAfter(startDate) &&
          sale.saleDate.isBefore(endDate);
    }).toList();

    // Criar planilha de vendas
    if (filteredSales.isNotEmpty) {
      await _createSalesSheetAdvanced(
        excel,
        filteredSales,
        wines,
        startDate,
        endDate,
      );
    }

    // Criar planilha de estoque se selecionado
    if (includeAllInventory) {
      _createStockSheet(excel, wines);
    } else {
      // Apenas vinhos vendidos
      final soldWines = wines.where((wine) {
        return filteredSales.any((sale) => sale.wineId == wine.id);
      }).toList();
      if (soldWines.isNotEmpty) {
        _createSoldWinesSheet(excel, soldWines, filteredSales);
      }
    }

    final fileName =
        'relatorio_vinhos_${DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now())}.xlsx';

    // Salvar arquivo
    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Erro ao gerar arquivo Excel');
    }

    // Tentar salvar na pasta Downloads primeiro
    String? filePath = await _saveToDownloads(fileName, fileBytes);

    // Se não conseguir, salvar no cache
    if (filePath == null) {
      filePath = await _saveToCache(fileName, fileBytes);
    }

    return filePath;
  }

  Future<void> openFile(String filePath) async {
    try {
      await OpenFile.open(filePath);
    } catch (e) {
      throw Exception('Erro ao abrir arquivo: $e');
    }
  }

  // Método original para compatibilidade
  Future<String> exportSalesAndStock({
    required List<Sale> sales,
    required List<Wine> wines,
    required DateTime month,
  }) async {
    // Solicitar permissões
    await _requestPermissions();

    var excel = Excel.createExcel();

    // Remover a sheet padrão
    excel.delete('Sheet1');

    // Criar planilha de vendas
    await _createSalesSheet(excel, sales, wines, month);

    // Criar planilha de estoque
    _createStockSheet(excel, wines);

    final fileName =
        'relatorio_vinhos_${DateFormat('yyyy_MM').format(month)}.xlsx';

    // Salvar arquivo
    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Erro ao gerar arquivo Excel');
    }

    // Tentar salvar na pasta Downloads primeiro
    String? filePath = await _saveToDownloads(fileName, fileBytes);

    // Se não conseguir, salvar no cache e compartilhar
    if (filePath == null) {
      filePath = await _saveToCache(fileName, fileBytes);
      // Compartilhar o arquivo
      await Share.shareXFiles(
        [XFile(filePath)],
        text:
            'Relatório de Vinhos - ${DateFormat('MMMM yyyy', 'pt_PT').format(month)}',
      );
    }

    return filePath;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Para Android 13+ (API 33+)
      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        await openAppSettings();
      }

      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        // Tentar permissão de storage normal
        await Permission.storage.request();
      }
    }
  }

  /// Exportar vinhos da adega pessoal para Excel
  Future<String> exportAdegaWinesToExcel(List<Wine> wines) async {
    // Solicitar permissões
    await _requestPermissions();

    var excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Criar aba da adega
    var sheet = excel['Minha Adega'];

    // Título
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('F1'));
    var titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('🍷 MINHA ADEGA PESSOAL');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#6B2737'),
      fontColorHex: ExcelColor.white,
    );

    // Data de exportação
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('F2'));
    var dateCell = sheet.cell(CellIndex.indexByString('A2'));
    dateCell.value = TextCellValue(
      'Exportado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    dateCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      italic: true,
    );

    // Linha em branco
    sheet.appendRow([TextCellValue('')]);

    // Cabeçalhos
    final headers = [
      'Nome do Vinho',
      'Tipo',
      'Região',
      'Ano/Descrição',
      'Quantidade',
      'Observações',
    ];
    var headerRow = <CellValue>[];
    for (var header in headers) {
      headerRow.add(TextCellValue(header));
    }
    sheet.appendRow(headerRow);

    // Estilizar cabeçalhos
    final headerRowIndex = 4;
    for (var col = 0; col < headers.length; col++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: headerRowIndex - 1,
        ),
      );
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D4AF37'),
        fontColorHex: ExcelColor.black,
      );
    }

    // Adicionar dados dos vinhos
    int totalGarrafas = 0;
    for (var wine in wines) {
      final row = <CellValue>[
        TextCellValue(wine.name),
        TextCellValue(wine.wineType.toUpperCase()),
        TextCellValue(wine.region.replaceAll(' (Portugal)', '')),
        TextCellValue(wine.description),
        IntCellValue(wine.quantity),
        TextCellValue(wine.location ?? ''),
      ];

      sheet.appendRow(row);
      totalGarrafas += wine.quantity;
    }

    // Linha de totais
    if (wines.isNotEmpty) {
      sheet.appendRow([TextCellValue('')]);

      final totalRow = <CellValue>[
        TextCellValue('TOTAL DE VINHOS: ${wines.length}'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        IntCellValue(totalGarrafas),
        TextCellValue(''),
      ];
      sheet.appendRow(totalRow);

      // Estilizar linha de totais
      final lastRow = sheet.maxRows;
      for (var col = 0; col < 6; col++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRow - 1),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#D4AF37'),
        );
      }
    }

    // Ajustar largura das colunas
    sheet.setColumnWidth(0, 30); // Nome
    sheet.setColumnWidth(1, 12); // Tipo
    sheet.setColumnWidth(2, 20); // Região
    sheet.setColumnWidth(3, 35); // Descrição
    sheet.setColumnWidth(4, 12); // Quantidade
    sheet.setColumnWidth(5, 25); // Observações

    // Salvar arquivo
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Adega_Pessoal_$timestamp.xlsx';

    // Salvar arquivo
    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Erro ao gerar arquivo Excel');
    }

    // Tentar salvar na pasta Downloads primeiro
    String? filePath = await _saveToDownloads(fileName, fileBytes);

    // Se não conseguir, salvar no cache
    if (filePath == null) {
      filePath = await _saveToCache(fileName, fileBytes);
    }

    return filePath;
  }

  Future<String?> _saveToDownloads(String fileName, List<int> fileBytes) async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final filePath = '${downloadsDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        return filePath;
      }
    } catch (e) {
      print('Erro ao salvar em Downloads: $e');
    }
    return null;
  }

  Future<String> _saveToCache(String fileName, List<int> fileBytes) async {
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    return filePath;
  }

  Future<void> _createSalesSheet(
    Excel excel,
    List<Sale> sales,
    List<Wine> wines,
    DateTime month,
  ) async {
    var sheet = excel['Vendas - ${DateFormat('MM-yyyy').format(month)}'];

    // Criar um mapa de vinhos para busca rápida
    final wineMap = {for (var wine in wines) wine.id: wine};

    // Configurar cabeçalhos
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Data da Venda',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
      'Nome do Vinho',
    );
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Quantidade',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
      'Preço Unitário',
    );
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
      'Valor Total',
    );
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Região');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('Tipo');

    // Estilizar cabeçalhos
    for (var col in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
      var cell = sheet.cell(CellIndex.indexByString('${col}1'));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Ordenar vendas por data
    sales.sort((a, b) => a.saleDate.compareTo(b.saleDate));

    // Preencher dados
    int row = 2;
    double totalValue = 0;
    int totalQuantity = 0;

    for (var sale in sales) {
      final wine = wineMap[sale.wineId];

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate),
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        sale.wineName,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        sale.quantity,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
        sale.winePrice,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = DoubleCellValue(
        sale.totalValue,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(
        wine?.region ?? '-',
      );
      sheet.cell(CellIndex.indexByString('G$row')).value = TextCellValue(
        wine?.wineType ?? '-',
      );

      totalValue += sale.totalValue;
      totalQuantity += sale.quantity;
      row++;
    }

    // Adicionar linha de totais
    if (sales.isNotEmpty) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        'TOTAL',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        totalQuantity,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = DoubleCellValue(
        totalValue,
      );

      for (var col in ['A', 'C', 'E']) {
        var cell = sheet.cell(CellIndex.indexByString('$col$row'));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#A5D6A7'),
        );
      }
    }
  }

  void _createStockSheet(Excel excel, List<Wine> wines) {
    var sheet = excel['Estoque Atual'];

    // Configurar cabeçalhos
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nome do Vinho',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Preço');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Quantidade em Estoque',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Região');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Tipo');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue(
      'Descrição',
    );
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('Status');

    // Estilizar cabeçalhos
    for (var col in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
      var cell = sheet.cell(CellIndex.indexByString('${col}1'));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Ordenar vinhos por nome
    wines.sort((a, b) => a.name.compareTo(b.name));

    // Preencher dados
    int row = 2;
    int totalQuantity = 0;
    double totalValue = 0;

    for (var wine in wines) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        wine.name,
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
        wine.price,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        wine.quantity,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        wine.region,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(
        wine.wineType,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(
        wine.description,
      );

      // Status baseado na quantidade
      String status;
      ExcelColor colorHex;
      if (wine.quantity == 0) {
        status = 'Sem estoque';
        colorHex = ExcelColor.fromHexString('#F44336');
      } else if (wine.quantity < 5) {
        status = 'Estoque baixo';
        colorHex = ExcelColor.fromHexString('#FFC107');
      } else {
        status = 'Em estoque';
        colorHex = ExcelColor.fromHexString('#4CAF50');
      }

      sheet.cell(CellIndex.indexByString('G$row')).value = TextCellValue(
        status,
      );
      sheet.cell(CellIndex.indexByString('G$row')).cellStyle = CellStyle(
        bold: true,
        fontColorHex: colorHex,
      );

      totalQuantity += wine.quantity;
      totalValue += wine.price * wine.quantity;
      row++;
    }

    // Adicionar linha de totais
    if (wines.isNotEmpty) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        'TOTAL',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        'Valor total: € ${totalValue.toStringAsFixed(2)}',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        totalQuantity,
      );

      for (var col in ['A', 'B', 'C']) {
        var cell = sheet.cell(CellIndex.indexByString('$col$row'));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#A5D6A7'),
        );
      }
    }
  }

  Future<void> _createSalesSheetAdvanced(
    Excel excel,
    List<Sale> sales,
    List<Wine> wines,
    DateTime startDate,
    DateTime endDate,
  ) async {
    var sheet =
        excel['Vendas - ${DateFormat('MM/yyyy').format(startDate)} a ${DateFormat('MM/yyyy').format(endDate)}'];

    // Criar um mapa de vinhos para busca rápida
    final wineMap = {for (var wine in wines) wine.id: wine};

    // Agrupar vendas pelo nome do vinho
    final Map<String, Map<String, dynamic>> groupedSales = {};
    
    for (var sale in sales) {
      final wineName = sale.wineName;
      
      if (groupedSales.containsKey(wineName)) {
        // Adicionar à quantidade existente
        groupedSales[wineName]!['quantity'] += sale.quantity;
        groupedSales[wineName]!['totalValue'] += sale.totalValue;
      } else {
        // Criar nova entrada
        final wine = wineMap[sale.wineId];
        groupedSales[wineName] = {
          'quantity': sale.quantity,
          'price': sale.winePrice,
          'totalValue': sale.totalValue,
          'region': wine?.region ?? '-',
          'type': wine?.wineType ?? '-',
        };
      }
    }

    // Configurar cabeçalhos
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nome do Vinho',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
      'Quantidade Total Vendida',
    );
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Preço Unitário',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
      'Valor Total',
    );
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Região');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Tipo');

    // Estilizar cabeçalhos
    for (var col in ['A', 'B', 'C', 'D', 'E', 'F']) {
      var cell = sheet.cell(CellIndex.indexByString('${col}1'));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Ordenar vinhos por nome
    final sortedWineNames = groupedSales.keys.toList()..sort();

    // Preencher dados
    int row = 2;
    double totalValue = 0;
    int totalQuantity = 0;

    for (var wineName in sortedWineNames) {
      final data = groupedSales[wineName]!;

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        wineName,
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(
        data['quantity'] as int,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(
        data['price'] as double,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
        data['totalValue'] as double,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(
        data['region'] as String,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(
        data['type'] as String,
      );

      totalValue += data['totalValue'] as double;
      totalQuantity += data['quantity'] as int;
      row++;
    }

    // Adicionar linha de totais
    if (groupedSales.isNotEmpty) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        'TOTAL',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(
        totalQuantity,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(
        totalValue,
      );

      for (var col in ['A', 'B', 'D']) {
        var cell = sheet.cell(CellIndex.indexByString('$col$row'));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#A5D6A7'),
        );
      }
    }
  }

  void _createSoldWinesSheet(Excel excel, List<Wine> wines, List<Sale> sales) {
    var sheet = excel['Vinhos Vendidos'];

    // Configurar cabeçalhos
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nome do Vinho',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Preço');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Quantidade Atual',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Região');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Tipo');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue(
      'Total Vendido',
    );

    // Estilizar cabeçalhos
    for (var col in ['A', 'B', 'C', 'D', 'E', 'F']) {
      var cell = sheet.cell(CellIndex.indexByString('${col}1'));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Ordenar vinhos por nome
    wines.sort((a, b) => a.name.compareTo(b.name));

    // Preencher dados
    int row = 2;
    int totalSoldQuantity = 0;
    double totalSoldValue = 0;

    for (var wine in wines) {
      final wineSales = sales.where((sale) => sale.wineId == wine.id).toList();
      final soldQty = wineSales.fold<int>(
        0,
        (sum, sale) => sum + sale.quantity,
      );
      final soldValue = wineSales.fold<double>(
        0,
        (sum, sale) => sum + sale.totalValue,
      );

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        wine.name,
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(
        wine.price,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        wine.quantity,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        wine.region,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(
        wine.wineType,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = IntCellValue(
        soldQty,
      );

      totalSoldQuantity += soldQty;
      totalSoldValue += soldValue;
      row++;
    }

    // Adicionar linha de totais
    if (wines.isNotEmpty) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        'TOTAL',
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = IntCellValue(
        totalSoldQuantity,
      );
      sheet.cell(CellIndex.indexByString('G$row')).value = DoubleCellValue(
        totalSoldValue,
      );

      for (var col in ['A', 'F', 'G']) {
        var cell = sheet.cell(CellIndex.indexByString('$col$row'));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#A5D6A7'),
        );
      }
    }
  }
}
