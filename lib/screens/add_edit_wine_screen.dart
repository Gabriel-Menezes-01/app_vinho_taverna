import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/wine.dart';
import '../models/wine_regions.dart';
import '../services/casta_service.dart';
import '../services/location_service.dart';
import '../services/region_service.dart';
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

  List<Wine> _allWines = [];
  Wine? _selectedAdegaWine;
  String? _imagePath;
  String? _imageUrl;
  final CastaService _castaService = CastaService();
  final LocationService _locationService = LocationService();
  final RegionService _regionService = RegionService();
  List<String> _castas = List<String>.from(CastaService.defaultCastas);
  List<String> _locations = List<String>.from(LocationService.defaultLocations);
  List<String> _regions = List<String>.from(WineRegions.regions);
  final Set<String> _selectedCastas = <String>{};
  final Set<String> _selectedLocations = <String>{};
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
      final parsed = _parseCastasFromStorage(widget.wine!.casta);
      _selectedCastas
        ..clear()
        ..addAll(parsed);
      for (final c in parsed) {
        if (!_castas.contains(c)) _castas.add(c);
      }
      final parsedLocations = _parseLocationsFromStorage(widget.wine!.location);
      _selectedLocations
        ..clear()
        ..addAll(parsedLocations);
      for (final location in parsedLocations) {
        if (!_locations.contains(location)) _locations.add(location);
      }
      _imagePath = widget.wine!.imagePath;
      _imageUrl = widget.wine!.imageUrl;
      _selectedWineType = widget.wine!.wineType;
      _selectedRegion = widget.wine!.region;
      _isHouseWine = widget.wine!.isHouseWine;
      _isDailySpecial = widget.wine!.isDailySpecial;
    }
    _loadCastasCatalog();
    _loadLocationsCatalog();
    _loadRegionsCatalog();
    _carregarSugestoesVinhos();
  }

  Future<void> _loadCastasCatalog() async {
    final catalog = await _castaService.getCatalog();
    if (!mounted) return;
    setState(() {
      _castas = List<String>.from(catalog);
      for (final selected in _selectedCastas) {
        if (!_castas.contains(selected)) {
          _castas.add(selected);
        }
      }
    });
  }

  Future<void> _loadLocationsCatalog() async {
    final catalog = await _locationService.getCatalog();
    if (!mounted) return;
    setState(() {
      _locations = List<String>.from(catalog);
      for (final selected in _selectedLocations) {
        if (!_locations.contains(selected)) {
          _locations.add(selected);
        }
      }
    });
  }

  Future<void> _loadRegionsCatalog() async {
    final catalog = await _regionService.getCatalog();
    if (!mounted) return;
    setState(() {
      _regions = List<String>.from(catalog);
      if (!_regions.contains(_selectedRegion)) {
        _regions.add(_selectedRegion);
      }
    });
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
    final parsed = _parseCastasFromStorage(wine.casta);
    _selectedCastas
      ..clear()
      ..addAll(parsed);
    for (final c in parsed) {
      if (!_castas.contains(c)) _castas.add(c);
    }
    final parsedLocations = _parseLocationsFromStorage(wine.location);
    _selectedLocations
      ..clear()
      ..addAll(parsedLocations);
    for (final location in parsedLocations) {
      if (!_locations.contains(location)) _locations.add(location);
    }
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
    super.dispose();
  }

  List<String> _parseCastasFromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _formatCastasForStorage() {
    if (_selectedCastas.isEmpty) return null;
    return _selectedCastas.join(', ');
  }

  List<String> _parseLocationsFromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _formatLocationsForStorage() {
    if (_selectedLocations.isEmpty) return null;
    return _selectedLocations.join(', ');
  }

  void _addCustomCasta() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova casta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: Baga, Encruzado...'
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;

              await _castaService.addCustomCasta(value);
              final updatedCatalog = await _castaService.getCatalog();
              if (!mounted) return;

              setState(() {
                _castas = List<String>.from(updatedCatalog);
                _selectedCastas.add(value);
              });
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCustomCasta(String casta) async {
    await _castaService.removeCustomCasta(casta);
    if (!mounted) return;

    setState(() {
      _castas.removeWhere((c) => c.toLowerCase() == casta.toLowerCase());
      _selectedCastas.removeWhere((c) => c.toLowerCase() == casta.toLowerCase());
    });
  }

  void _addCustomLocation() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova localizacao'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: Prateleira A3, Adega Climatizada...'
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;

              await _locationService.addCustomLocation(value);
              final updatedCatalog = await _locationService.getCatalog();
              if (!mounted) return;

              setState(() {
                _locations = List<String>.from(updatedCatalog);
                _selectedLocations.add(value);
              });
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeLocation(String location) async {
    await _locationService.removeLocation(location);
    if (!mounted) return;

    setState(() {
      _locations.removeWhere((c) => c.toLowerCase() == location.toLowerCase());
      _selectedLocations.removeWhere((c) => c.toLowerCase() == location.toLowerCase());
    });
  }

  void _addCustomRegion() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova regiao'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: Ribatejo, Minho, Serra da Estrela...'
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;

              await _regionService.addCustomRegion(value);
              await _loadRegionsCatalog();
              if (!mounted) return;

              setState(() {
                _selectedRegion = value;
              });
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSelectedRegion() async {
    final region = _selectedRegion;
    if (_regionService.isProtectedRegion(region)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa regiao nao pode ser excluida.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final removed = await _regionService.removeRegion(region);
    if (!mounted) return;

    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel excluir a regiao selecionada.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _loadRegionsCatalog();
    if (!mounted) return;

    setState(() {
      _selectedRegion = _regions.contains('Outra região')
          ? 'Outra região'
          : (_regions.isNotEmpty ? _regions.first : 'Outra região');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Regiao "$region" excluida da lista.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // No Windows/desktop, câmera não é suportada
      if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
          source == ImageSource.camera) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Câmera não disponível no desktop. Use a Galeria.'),
            ),
          );
        }
        return;
      }

      // No desktop, não usar imageQuality pois pode causar problemas
      final bool isDesktop =
          Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: isDesktop ? null : 1920,
        maxHeight: isDesktop ? null : 1080,
        imageQuality: isDesktop ? null : 85,
      );

      if (image != null) {
        final dir = await getApplicationDocumentsDirectory();
        final imagesDir =
            Directory('${dir.path}${Platform.pathSeparator}wine_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        // Preservar extensão original do arquivo
        final originalExt = image.path.contains('.')
            ? image.path.substring(image.path.lastIndexOf('.'))
            : '.jpg';
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}$originalExt';
        final destPath =
            '${imagesDir.path}${Platform.pathSeparator}$fileName';
        final savedFile = await File(image.path).copy(destPath);
        debugPrint('✅ Imagem salva em: ${savedFile.path}');
        setState(() {
          _imagePath = savedFile.path;
          _imageUrl = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagem selecionada com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint('ℹ️ Nenhuma imagem selecionada (cancelado pelo usuário)');
      }
    } catch (e) {
      debugPrint('❌ Erro ao selecionar imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    final bool isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) {
      // No desktop, ir direto para a galeria (câmera não suportada)
      _pickImage(ImageSource.gallery);
      return;
    }
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

    try {
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
        casta: _formatCastasForStorage(),
        imagePath: _imagePath,
        imageUrl: _imageUrl,
        region: _selectedRegion,
        wineType: _selectedWineType,
        quantity: requestedQuantity,
        location: _formatLocationsForStorage(),
        harvestYear: widget.wine?.harvestYear,
        isHouseWine: _isHouseWine,
        isDailySpecial: _isDailySpecial,
      );

      if (widget.wine != null) {
        await widget.wineService.updateWine(wine);
        if (mounted) {
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
            casta: currentAdega.casta,
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
          setState(() {
            _imagePath = null;
            _imageUrl = null;
            _selectedCastas.clear();
            _selectedLocations.clear();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar vinho: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

          // Casta
          const Text(
            'Casta (opcional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Nova casta'),
                onPressed: _addCustomCasta,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final casta in _castas)
                InputChip(
                  label: Text(casta),
                  selected: _selectedCastas.contains(casta),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCastas.add(casta);
                      } else {
                        _selectedCastas.remove(casta);
                      }
                    });
                  },
                  onDeleted: _castaService.isDefaultCasta(casta)
                      ? null
                      : () => _removeCustomCasta(casta),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Localizacao
          const Text(
            'Localizacao (opcional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add_location_alt, size: 18),
                label: const Text('Nova localizacao'),
                onPressed: _addCustomLocation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final location in _locations)
                InputChip(
                  label: Text(location),
                  selected: _selectedLocations.contains(location),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLocations.add(location);
                      } else {
                        _selectedLocations.remove(location);
                      }
                    });
                  },
                  onDeleted: () => _removeLocation(location),
                ),
            ],
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
            items: _regions.map((region) {
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Nova regiao'),
                onPressed: _addCustomRegion,
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Excluir regiao selecionada'),
                onPressed: _removeSelectedRegion,
              ),
            ],
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
 
