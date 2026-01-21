import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/wine.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../models/wine_regions.dart';

class AdegaScreen extends StatefulWidget {
  final WineService wineService;
  final UserService? userService;

  const AdegaScreen({
    super.key,
    required this.wineService,
    this.userService,
  });

  @override
  State<AdegaScreen> createState() => _AdegaScreenState();
}

class _AdegaScreenState extends State<AdegaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _anoController = TextEditingController();
  final _precoController = TextEditingController();
  final _descricaoController = TextEditingController();
  
  String _tipoSelecionado = 'tinto';
  String _regiaoSelecionada = WineRegions.douro;
  bool _loading = false;

  final List<String> _tipos = ['tinto', 'branco', 'rosé', 'verde'];

  @override
  void initState() {
    super.initState();
    _anoController.text = DateTime.now().year.toString();
  }

  Future<void> _adicionarVinho() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final novoVinho = Wine(
        id: const Uuid().v4(),
        name: _nomeController.text.trim(),
        price: double.parse(_precoController.text),
        description: _descricaoController.text.trim(),
        region: _regiaoSelecionada,
        wineType: _tipoSelecionado,
        quantity: 1,
        imagePath: null,
        synced: false,
        lastModified: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );

      await widget.wineService.addWine(novoVinho);

      if (!mounted) return;

      // Limpar campos
      _formKey.currentState!.reset();
      _nomeController.clear();
      _descricaoController.clear();
      _precoController.clear();
      _anoController.text = DateTime.now().year.toString();
      _tipoSelecionado = 'tinto';
      _regiaoSelecionada = WineRegions.douro;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Vinho "${novoVinho.name}" adicionado à adega!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar vinho: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍷 Adega de Vinhos'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== NOME DO VINHO =====
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome do Vinho',
                  hintText: 'Ex: Quinta dos Sonhos',
                  prefixIcon: const Icon(Icons.wine_bar),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o nome do vinho';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ===== TIPO DE VINHO =====
              DropdownButtonFormField<String>(
                value: _tipoSelecionado,
                decoration: InputDecoration(
                  labelText: 'Tipo de Vinho',
                  prefixIcon: const Icon(Icons.palette),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _tipos.map((tipo) {
                  final emojis = {
                    'tinto': '🔴',
                    'branco': '⚪',
                    'rosé': '🌸',
                    'verde': '🟢',
                  };
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text('${emojis[tipo]} ${tipo.toUpperCase()}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _tipoSelecionado = value ?? 'tinto');
                },
              ),
              const SizedBox(height: 16),

              // ===== REGIÃO =====
              DropdownButtonFormField<String>(
                value: _regiaoSelecionada,
                decoration: InputDecoration(
                  labelText: 'Região',
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: WineRegions.all_regions.map((regiao) {
                  return DropdownMenuItem(
                    value: regiao,
                    child: Text(regiao),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _regiaoSelecionada = value ?? WineRegions.douro);
                },
              ),
              const SizedBox(height: 16),

              // ===== ANO =====
              TextFormField(
                controller: _anoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ano de Colheita',
                  hintText: '2020',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o ano';
                  }
                  final ano = int.tryParse(value);
                  if (ano == null || ano < 1900 || ano > DateTime.now().year + 1) {
                    return 'Ano inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ===== PREÇO =====
              TextFormField(
                controller: _precoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Preço (€)',
                  hintText: '25.50',
                  prefixIcon: const Icon(Icons.euro),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe o preço';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Preço inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ===== DESCRIÇÃO =====
              TextFormField(
                controller: _descricaoController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descrição (Opcional)',
                  hintText: 'Notas de degustação, características...',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ===== BOTÃO ADICIONAR =====
              ElevatedButton.icon(
                onPressed: _loading ? null : _adicionarVinho,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF722F37),
                  foregroundColor: Colors.white,
                ),
                label: Text(
                  _loading ? 'Adicionando...' : 'Adicionar à Adega',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // ===== INFORMAÇÕES =====
              Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Dica:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Os vinhos adicionados aqui serão salvos no banco de dados e sincronizados com seus outros dispositivos via Firestore.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _anoController.dispose();
    _precoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }
}
