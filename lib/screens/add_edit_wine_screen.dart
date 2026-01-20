import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wine.dart';
import '../models/wine_regions.dart';
import '../services/wine_service.dart';
import '../services/user_service.dart';

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

  String? _imagePath;
  String _selectedWineType = 'tinto';
  String _selectedRegion = 'Outra região';
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

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
      _selectedWineType = widget.wine!.wineType;
      _selectedRegion = widget.wine!.region;
    }
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

    final wine = Wine(
      id: widget.wine?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      description: _descriptionController.text.trim(),
      imagePath: _imagePath,
      region: _selectedRegion,
      wineType: _selectedWineType,
      quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
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
            _selectedWineType = 'tinto';
            _selectedRegion = 'Outra região';
          });

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
    return Expanded(
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wine != null ? 'Editar Vinho' : 'Adicionar Vinho'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Seleção de imagem
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.wine_bar,
                                  size: 80,
                                  color: Colors.grey[400],
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.wine_bar,
                            size: 80,
                            color: Colors.grey[400],
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
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome do Vinho',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, informe o nome do vinho';
                }
                return null;
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
                prefixIcon: const Icon(Icons.attach_money),
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

            // Quantidade de garrafas
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Quantidade de Garrafas',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.inventory),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, informe a quantidade';
                }
                if (int.tryParse(value.trim()) == null) {
                  return 'Por favor, informe um valor válido';
                }
                final quantity = int.parse(value.trim());
                if (quantity < 0 || quantity > 99999) {
                  return 'Quantidade deve estar entre 0 e 99999';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Local de armazenamento
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Local de Armazenamento',
                hintText: 'Ex: Prateleira A3, Adega 2, Armário...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on),
              ),
              maxLength: 100,
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
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, informe a descrição';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

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
              items: WineRegions.regions
                  .where((region) => region != WineRegions.all)
                  .map(
                    (region) => DropdownMenuItem(
                      value: region,
                      child: Text(region),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRegion = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Tipo de Vinho
            const Text(
              'Tipo de Vinho',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildWineTypeButton('tinto', 'Tinto', Colors.red),
                const SizedBox(width: 12),
                _buildWineTypeButton('branco', 'Branco', Colors.amber),
                const SizedBox(width: 12),
                _buildWineTypeButton('rosé', 'Rosé', Colors.pink),
                const SizedBox(width: 12),
                _buildWineTypeButton('verde', 'Verde', Colors.green),
              ],
            ),
            const SizedBox(height: 32),

            // Botão salvar
            ElevatedButton(
              onPressed: _saving ? null : _saveWine,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Salvando...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      widget.wine != null ? 'Atualizar' : 'Adicionar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Botão sair
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Colors.grey, width: 1),
              ),
              child: const Text(
                'Sair',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
