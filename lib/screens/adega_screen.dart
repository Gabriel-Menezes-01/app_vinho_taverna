import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wine.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../models/wine_regions.dart';
import '../widgets/responsive_wine_image.dart';

class AdegaScreen extends StatefulWidget {
  final WineService wineService;
  final UserService? userService;
  final Wine? wine;

  const AdegaScreen({
    super.key,
    required this.wineService,
    this.userService,
    this.wine,
  });

  @override
  State<AdegaScreen> createState() => _AdegaScreenState();
}

class _AdegaScreenState extends State<AdegaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _anoController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _localController = TextEditingController();
  final _quantidadeAdegaController = TextEditingController();
  final _quantidadeVendaController = TextEditingController();
  
  String _tipoSelecionado = 'tinto';
  String _regiaoSelecionada = 'Douro (Portugal)';
  bool _loading = false;
  bool _isEditing = false;
  bool _adicionarParaVenda = false;
  String? _imagePath;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _tipos = ['tinto', 'branco', 'rosé', 'verde', 'espumante', 'champagne'];

  @override
  void initState() {
    super.initState();
    _anoController.text = DateTime.now().year.toString();
    _quantidadeAdegaController.text = '1';
    _quantidadeVendaController.text = '1';
    
    // Se há um vinho para editar
    if (widget.wine != null) {
      _isEditing = true;
      _nomeController.text = widget.wine!.name;
      _descricaoController.text = widget.wine!.description;
      _localController.text = widget.wine!.location ?? '';
      _imagePath = widget.wine!.imagePath;
      _imageUrl = widget.wine!.imageUrl;
      _tipoSelecionado = widget.wine!.wineType;
      _regiaoSelecionada = widget.wine!.region;
      _anoController.text = (widget.wine!.harvestYear ?? DateTime.now().year).toString();
      _quantidadeAdegaController.text = widget.wine!.quantity.toString();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imagePath = image.path;
          _imageUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adicionarVinho({int? saleQuantity}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final harvestYear = int.tryParse(_anoController.text.trim()) ?? DateTime.now().year;

      if (_isEditing && widget.wine != null) {
        // Atualizar vinho existente
        final novaQuantidade = int.tryParse(_quantidadeAdegaController.text.trim()) ?? widget.wine!.quantity;
        
        final updatedWine = Wine(
          id: widget.wine!.id,
          name: _nomeController.text.trim(),
          price: 0.0,
          description: _descricaoController.text.trim(),
          region: _regiaoSelecionada,
          wineType: _tipoSelecionado,
          quantity: novaQuantidade,
          location: _localController.text.trim(),
          imagePath: _imagePath,
          imageUrl: _imageUrl,
          isFromAdega: true,
          synced: false,
          harvestYear: harvestYear,
          lastModified: DateTime.now(),
          createdAt: widget.wine!.createdAt ?? DateTime.now(),
        );

        await widget.wineService.updateAdegaWine(updatedWine);

        // Se houver quantidade para venda, adicionar para venda também
        if (saleQuantity != null && saleQuantity > 0) {
          final novoVinhoParaVenda = Wine(
            id: const Uuid().v4(),
            name: _nomeController.text.trim(),
            price: 0.0,
            description: _descricaoController.text.trim(),
            region: _regiaoSelecionada,
            wineType: _tipoSelecionado,
            quantity: saleQuantity,
            location: _localController.text.trim(),
            imagePath: _imagePath,
            imageUrl: _imageUrl,
            isFromAdega: false,
            synced: false,
            harvestYear: harvestYear,
            lastModified: DateTime.now(),
            createdAt: DateTime.now(),
          );
          await widget.wineService.addWine(novoVinhoParaVenda);
        }

        if (!mounted) return;

        var mensagem = 'Vinho "${updatedWine.name}" atualizado com sucesso!';
        if (saleQuantity != null && saleQuantity > 0) {
          mensagem = 'Vinho atualizado e $saleQuantity garrafa(s) adicionada(s) à venda!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $mensagem'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      // Adicionar novo vinho na adega
      final quantidadeAdegaTotal = int.tryParse(_quantidadeAdegaController.text.trim()) ?? 1;
      final quantidadeVenda = _adicionarParaVenda 
          ? (int.tryParse(_quantidadeVendaController.text.trim()) ?? 0) 
          : 0;
      
      // Quantidade que fica na adega = Total - Quantidade para venda
      final quantidadeNaAdega = quantidadeAdegaTotal - quantidadeVenda;
      
      // Só adiciona na adega se sobrar quantidade
      if (quantidadeNaAdega > 0) {
        print('🍷 Adicionando vinho na adega: $quantidadeNaAdega garrafas');
        final novoVinho = Wine(
          id: const Uuid().v4(),
          name: _nomeController.text.trim(),
          price: 0.0,
          description: _descricaoController.text.trim(),
          region: _regiaoSelecionada,
          wineType: _tipoSelecionado,
          quantity: quantidadeNaAdega,
          location: _localController.text.trim(),
          imagePath: _imagePath,
          isFromAdega: true,
          synced: false,
          harvestYear: harvestYear,
          lastModified: DateTime.now(),
          createdAt: DateTime.now(),
        );

        print('🔵 Chamando addAdegaWine...');
        await widget.wineService.addAdegaWine(novoVinho);
        print('✅ Vinho adicionado na adega com sucesso!');
      }

      // Se marcado, adicionar também para venda
      if (_adicionarParaVenda && quantidadeVenda > 0) {
        final novoVinhoVenda = Wine(
          id: const Uuid().v4(),
          name: _nomeController.text.trim(),
          price: 0.0,
          description: _descricaoController.text.trim(),
          region: _regiaoSelecionada,
          wineType: _tipoSelecionado,
          quantity: quantidadeVenda,
          location: _localController.text.trim(),
          imagePath: _imagePath,
          imageUrl: _imageUrl,
          isFromAdega: false,
          synced: false,
          harvestYear: harvestYear,
          lastModified: DateTime.now(),
          createdAt: DateTime.now(),
        );
        
        await widget.wineService.addWine(novoVinhoVenda);
      }

      if (!mounted) return;

      // Salvar estado antes de limpar
      final foiAdicionadoParaVenda = _adicionarParaVenda;

      // Limpar campos
      _formKey.currentState!.reset();
      _nomeController.clear();
      _descricaoController.clear();
      _localController.clear();
      _anoController.text = DateTime.now().year.toString();
      _quantidadeAdegaController.text = '1';
      _quantidadeVendaController.text = '1';
      _tipoSelecionado = 'tinto';
      _regiaoSelecionada = 'Douro (Portugal)';
      _adicionarParaVenda = false;
      _imagePath = null;
      _imageUrl = null;

      // Mensagem de sucesso
      String mensagem;
      if (foiAdicionadoParaVenda) {
        if (quantidadeNaAdega > 0) {
          mensagem = '✅ ${quantidadeNaAdega} garrafa(s) na adega, $quantidadeVenda para venda!';
        } else {
          mensagem = '✅ $quantidadeVenda garrafa(s) adicionada(s) para venda!';
        }
      } else {
        mensagem = '✅ ${quantidadeAdegaTotal} garrafa(s) adicionada(s) à adega!';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ ERRO ao adicionar vinho: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar vinho: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _adicionarParaVendaAoEditar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final harvestYear = int.tryParse(_anoController.text.trim()) ?? DateTime.now().year;

      final vineForSale = Wine(
        id: const Uuid().v4(),
        name: _nomeController.text.trim(),
        price: 0.0,
        description: _descricaoController.text.trim(),
        region: _regiaoSelecionada,
        wineType: _tipoSelecionado,
        quantity: 1,
        location: _localController.text.trim(),
        imagePath: _imagePath,
        imageUrl: _imageUrl,
        isFromAdega: false,
        synced: false,
        harvestYear: harvestYear,
        lastModified: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await widget.wineService.addWine(vineForSale);

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${_nomeController.text.trim()}" adicionada para venda!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar para venda: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Vinho da Adega' : '🍷 Adega de Vinhos'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== IMAGEM DO VINHO =====
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 150,
                      height: 210,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                      child: ResponsiveWineImage(
                        imagePath: _imagePath,
                        imageUrl: _imageUrl,
                        width: 150,
                        height: 210,
                        borderRadius: 16,
                        fit: BoxFit.contain,
                        enablePreview: true,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: FloatingActionButton.small(
                        onPressed: _showImageSourceDialog,
                        child: const Icon(Icons.camera_alt),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                    'espumante': '🥂',
                    'champagne': '🍾',
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
                items: WineRegions.regions.map((regiao) {
                  return DropdownMenuItem(
                    value: regiao,
                    child: Text(regiao),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _regiaoSelecionada = value ?? 'Douro (Portugal)');
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
              const SizedBox(height: 16),

              // ===== LOCALIZAÇÃO =====
              TextFormField(
                controller: _localController,
                decoration: InputDecoration(
                  labelText: 'Localização (Opcional)',
                  hintText: 'Ex: Adega Temperatura, Prateleira 3, etc.',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== QUANTIDADE PARA ADEGA =====
              TextFormField(
                controller: _quantidadeAdegaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantidade para Adega',
                  hintText: 'Número de garrafas',
                  prefixIcon: const Icon(Icons.inventory),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Informe a quantidade';
                  }
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 1) {
                    return 'Quantidade deve ser maior que 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ===== MARCADOR PARA VENDA =====
              if (!_isEditing)
                Card(
                  color: Colors.green.withOpacity(0.05),
                  child: CheckboxListTile(
                    title: const Text(
                      'Adicionar também para Venda',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Marque para adicionar este vinho nas vendas também',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _adicionarParaVenda,
                    onChanged: (value) {
                      setState(() {
                        _adicionarParaVenda = value ?? false;
                      });
                    },
                    secondary: Icon(
                      Icons.storefront,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              
              // ===== QUANTIDADE PARA VENDA =====
              if (!_isEditing && _adicionarParaVenda) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantidadeVendaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantidade para Venda',
                    hintText: 'Número de garrafas para venda',
                    helperText: 'Esta quantidade será deduzida da adega',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.storefront, color: Colors.green[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                  ),
                  validator: (value) {
                    if (_adicionarParaVenda) {
                      if (value == null || value.isEmpty) {
                        return 'Informe a quantidade para venda';
                      }
                      final qtyVenda = int.tryParse(value);
                      if (qtyVenda == null || qtyVenda < 1) {
                        return 'Quantidade deve ser maior que 0';
                      }
                      final qtyAdega = int.tryParse(_quantidadeAdegaController.text.trim()) ?? 0;
                      if (qtyVenda > qtyAdega) {
                        return 'Quantidade para venda não pode ser maior que a quantidade da adega';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              if (!_isEditing) const SizedBox(height: 16),

              // ===== BOTÃO =====
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
                    : Icon(_isEditing ? Icons.save : Icons.add_circle_outline),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF722F37),
                  foregroundColor: Colors.white,
                ),
                label: Text(
                  _loading 
                    ? (_isEditing ? 'Salvando...' : 'Adicionando...')
                    : (_isEditing ? 'Salvar Alterações' : 'Adicionar à Adega'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _adicionarParaVendaAoEditar,
                  icon: const Icon(Icons.storefront),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  label: const Text(
                    'Adicionar para Venda',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
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
                      Text(
                        _isEditing
                          ? 'Clique em "Adicionar para Venda" para colocar quantidades deste vinho à venda!'
                          : 'Os vinhos adicionados aqui serão salvos no banco de dados e sincronizados com seus outros dispositivos via Firestore.',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
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
    _descricaoController.dispose();
    _localController.dispose();
    _quantidadeAdegaController.dispose();
    _quantidadeVendaController.dispose();
    super.dispose();
  }
}
