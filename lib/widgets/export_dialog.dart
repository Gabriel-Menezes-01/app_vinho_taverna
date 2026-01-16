import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  // 0 = todos os meses, 1 = últimos 3 meses, 2 = últimos 6 meses, 3 = último mês
  int _monthsOption = 0;
  bool _includeAllInventory = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Opções de Exportação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'O que deseja exportar?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Opções de tipo de exportação
            Card(
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('Toda a adega'),
                    subtitle: const Text('Exporta todo o inventário e vendas'),
                    value: true,
                    groupValue: _includeAllInventory,
                    onChanged: (value) {
                      setState(() => _includeAllInventory = value ?? true);
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('Apenas vinhos vendidos'),
                    subtitle: const Text('Exporta somente vinhos com vendas'),
                    value: false,
                    groupValue: _includeAllInventory,
                    onChanged: (value) {
                      setState(() => _includeAllInventory = value ?? false);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Período de exportação',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Opções de período
            Card(
              child: Column(
                children: [
                  RadioListTile<int>(
                    title: const Text('Apenas o mês atual'),
                    value: 0,
                    groupValue: _monthsOption,
                    onChanged: (value) {
                      setState(() => _monthsOption = value ?? 0);
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('Últimos 3 meses'),
                    value: 1,
                    groupValue: _monthsOption,
                    onChanged: (value) {
                      setState(() => _monthsOption = value ?? 1);
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('Últimos 6 meses'),
                    value: 2,
                    groupValue: _monthsOption,
                    onChanged: (value) {
                      setState(() => _monthsOption = value ?? 2);
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('Todo o histórico'),
                    value: 3,
                    groupValue: _monthsOption,
                    onChanged: (value) {
                      setState(() => _monthsOption = value ?? 3);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'includeAllInventory': _includeAllInventory,
              'monthsOption': _monthsOption,
            });
          },
          child: const Text('Exportar'),
        ),
      ],
    );
  }
}
