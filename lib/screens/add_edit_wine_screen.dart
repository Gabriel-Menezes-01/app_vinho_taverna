import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wine.dart';
import '../models/wine_regions.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/responsive_wine_image.dart';

class AddEditWineScreen extends StatefulWidget {
  final WineService wineService;
  final UserService userService;
  final Wine? wine;

  const AddEditWineScreen({
    super.key,
    required this.wineService,
    required this.userService,
    this.wine,
  });

  @override
  State<AddEditWineScreen> createState() => _AddEditWineScreenState();
}

class _AddEditWineScreenState extends State<AddEditWineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  List<Wine> _allWines = [];
  Wine? _selectedAdegaWine;
  String? _imagePath;
  String? _imageUrl;
  String _selectedWineType = 'tinto';
  String _selectedRegion = 'Outra região';
  bool _isHouseWine = false;
  bool _isDailySpecial = false;
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;
  bool _loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    if (widget.wine != null) {
      _nameController.text = widget.wine!.name;
      _priceController.text = widget.wine!.price.toString();
      _quantityController.text = widget.wine!.quantity.toString();
      _descriptionController.text = widget.wine!.description;
      _locationController.text = widget.wine!.location ?? '';
      _imagePath = widget.wine!.imagePath;
      _imageUrl = widget.wine!.imageUrl;
      _selectedWineType = widget.wine!.wineType;
      _selectedRegion = widget.wine!.region;
      _isHouseWine = widget.wine!.isHouseWine;
      _isDailySpecial = widget.wine!.isDailySpecial;
    }
    _carregarSugestoesVinhos();
  }

  Future<void> _carregarSugestoesVinhos() async {
    if (mounted) {
      setState(() => _loadingSuggestions = true);
    }
    try {
      final results = await Future.wait([
        widget.wineService.getAllWines(),
        widget.wineService.getAdegaWines(),
      ]);
      final wines = results.expand((list) => list).toList();
      final unique = <String, Wine>{
        for (final wine in wines) wine.id: wine,
      };
      if (!mounted) return;
      setState(() {
        _allWines = unique.values.toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  void _preencherComSugestao(Wine wine) {
    _nameController.text = wine.name;
    _priceController.text = wine.price.toString();
    _quantityController.text = wine.quantity.toString();
    _descriptionController.text = wine.description;
    _locationController.text = wine.location ?? '';
    _imagePath = wine.imagePath;
    _imageUrl = wine.imageUrl;
    _selectedRegion = wine.region;
    _selectedWineType = wine.wineType;
    _isHouseWine = wine.isHouseWine;
    _isDailySpecial = wine.isDailySpecial;
    _selectedAdegaWine = wine.isFromAdega ? wine : null;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
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

  Future<void> _saveWine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    final requestedQuantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final shouldDeductAdega = widget.wine == null &&
        _selectedAdegaWine != null &&
        _nameController.text.trim() == _selectedAdegaWine!.name &&
        _selectedRegion == _selectedAdegaWine!.region &&
        _selectedWineType == _selectedAdegaWine!.wineType;

    final wineId = widget.wine?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final uploadedUrl = await widget.wineService.uploadImageIfNeeded(
      imagePath: _imagePath,
      imageUrl: _imageUrl,
      wineId: wineId,
      isAdega: false,
    );
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      _imageUrl = uploadedUrl;
    }

    Wine? currentAdega;
    if (shouldDeductAdega && requestedQuantity > 0) {
      final adegaWines = await widget.wineService.getAdegaWines();
      for (final wine in adegaWines) {
        if (wine.id == _selectedAdegaWine!.id) {
          currentAdega = wine;
          break;
        }
      }

      if (currentAdega != null && requestedQuantity > currentAdega.quantity) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Quantidade indisponível na adega. Restam ${currentAdega.quantity} garrafas.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    final wine = Wine(
      id: wineId,
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      description: _descriptionController.text.trim(),
      imagePath: _imagePath,
      imageUrl: _imageUrl,
      region: _selectedRegion,
      wineType: _selectedWineType,
      quantity: requestedQuantity,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      harvestYear: widget.wine?.harvestYear,
      isHouseWine: _isHouseWine,
      isDailySpecial: _isDailySpecial,
    );

    try {
      if (widget.wine != null) {
        await widget.wineService.updateWine(wine);
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vinho atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await widget.wineService.addWine(wine);

        if (currentAdega != null && requestedQuantity > 0) {
          final updatedAdega = Wine(
            id: currentAdega.id,
            name: currentAdega.name,
            price: currentAdega.price,
            description: currentAdega.description,
            imagePath: currentAdega.imagePath,
            imageUrl: currentAdega.imageUrl,
            region: currentAdega.region,
            wineType: currentAdega.wineType,
            quantity: currentAdega.quantity - requestedQuantity,
            location: currentAdega.location,
            harvestYear: currentAdega.harvestYear,
            synced: false,
            isFromAdega: true,
            isHouseWine: currentAdega.isHouseWine,
            isDailySpecial: currentAdega.isDailySpecial,
            lastModified: DateTime.now(),
            createdAt: currentAdega.createdAt,
          );

          await widget.wineService.updateAdegaWine(updatedAdega);
        }
        if (mounted) {
          setState(() => _saving = false);
          // Manter a tela aberta após adicionar e limpar o formulário
          _nameController.clear();
          _priceController.clear();
          _quantityController.clear();
          _descriptionController.clear();
          _locationController.clear();
          setState(() {
            _imagePath = null;
            _imageUrl = null;
            _selectedWineType = 'tinto';
            _selectedRegion = 'Outra região';
            _isHouseWine = false;
            _isDailySpecial = false;
            _selectedAdegaWine = null;
          });
          // Atualizar lista de sugestões
          _carregarSugestoesVinhos();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vinho adicionado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar vinho: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWineTypeButton(String type, String label, Color color) {
    final isSelected = _selectedWineType == type;
    return SizedBox(
      width: 110,
      child: InkWell(
        onTap: () => setState(() => _selectedWineType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.wine_bar,
                color: isSelected ? color : Colors.grey[400],
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageSize = (screenWidth * 0.5).clamp(160.0, 240.0).toDouble();

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final formContent = Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
        children: [
          // Seleção de imagem
          Center(
            child: Stack(
              children: [
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: ResponsiveWineImage(
                    imagePath: _imagePath,
                    imageUrl: _imageUrl,
                    width: imageSize,
                    height: imageSize,
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
          const SizedBox(height: 32),

          // Nome do vinho
          Autocomplete<Wine>(
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim().toLowerCase();
              if (query.isEmpty) return const Iterable<Wine>.empty();

              return _allWines.where(
                (wine) => wine.name.toLowerCase().contains(query),
              );
            },
            displayStringForOption: (option) => option.name,
            onSelected: _preencherComSugestao,
            fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) {
              // Inicializar com o nome existente ao editar
              if (textEditingController.text.isEmpty && _nameController.text.isNotEmpty) {
                textEditingController.text = _nameController.text;
                textEditingController.selection = TextSelection.fromPosition(
                  TextPosition(offset: textEditingController.text.length),
                );
              }
              
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Nome do Vinho',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.label),
                  suffixIcon: _allWines.isNotEmpty 
                    ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                    : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, informe o nome do vinho';
                  }
                  return null;
                },
                onChanged: (value) => _nameController.text = value,
                onFieldSubmitted: (_) => onSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              final optionList = options.toList();
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                      maxWidth: MediaQuery.of(context).size.width - 48,
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      shrinkWrap: true,
                      itemCount: optionList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = optionList[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.wine_bar, size: 20, color: Color(0xFF722F37)),
                          title: Text(
                            option.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${option.region} • ${option.wineType} • €${option.price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Preço
          TextFormField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: 'Preço (€)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.euro_symbol),
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, informe o preço';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'Por favor, informe um valor válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Quantidade
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantidade',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.inventory_2),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Por favor, informe a quantidade';
              }
              if (int.tryParse(value.trim()) == null) {
                return 'Por favor, informe um número válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Descrição
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Localização
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Localização (opcional)',
              hintText: 'Ex: Prateleira A3, Adega 2, Armário...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 24),

          // Tipo de vinho
          const Text(
            'Tipo de Vinho',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildWineTypeButton('tinto', 'Tinto', Colors.red[900]!),
              _buildWineTypeButton('branco', 'Branco', Colors.amber[200]!),
              _buildWineTypeButton('rosé', 'Rosé', Colors.pink[300]!),
              _buildWineTypeButton('verde', 'Verde', Colors.green[400]!),
              _buildWineTypeButton('espumante', 'Espumante', Colors.yellow[700]!),
              _buildWineTypeButton('champagne', 'Champagne', Colors.amber[700]!),
            ],
          ),
          const SizedBox(height: 24),

          // Região
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: InputDecoration(
              labelText: 'Região',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.public),
            ),
            items: WineRegions.regions.map((region) {
              return DropdownMenuItem(
                value: region,
                child: Text(region),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRegion = value);
              }
            },
          ),
          const SizedBox(height: 24),

          // Checkboxes para Vinho da Casa e Sugestão do Dia
          Card(
            elevation: 0,
            color: Colors.grey[50],
            child: Column(
              children: [
                CheckboxListTile(
                  value: _isHouseWine,
                  onChanged: (value) {
                    setState(() => _isHouseWine = value ?? false);
                  },
                  title: const Text('Vinho da Casa'),
                  subtitle: const Text('Marque para destacar como vinho da casa'),
                  secondary: Icon(Icons.home, color: Colors.red[900]),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  value: _isDailySpecial,
                  onChanged: (value) {
                    setState(() => _isDailySpecial = value ?? false);
                  },
                  title: const Text('Sugestão do Dia'),
                  subtitle: const Text('Marque para destacar como sugestão do dia'),
                  secondary: Icon(Icons.star, color: Colors.amber[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botão salvar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveWine,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF722F37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.wine != null ? 'Atualizar Vinho' : 'Salvar Vinho'),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wine != null ? 'Editar Vinho' : 'Adicionar Vinho'),
      ),
      body: SafeArea(
        child: LoadingFadeSwitcher(
          isLoading: _loadingSuggestions,
          loading: const FormSkeleton(),
          child: formContent,
        ),
      ),
    );
  }
}
 
