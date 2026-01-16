import 'package:flutter/material.dart';
import '../models/wine_regions.dart';

class RegionNavBar extends StatefulWidget {
  final String selectedRegion;
  final ValueChanged<String> onRegionChanged;

  const RegionNavBar({
    super.key,
    required this.selectedRegion,
    required this.onRegionChanged,
  });

  @override
  State<RegionNavBar> createState() => _RegionNavBarState();
}

class _RegionNavBarState extends State<RegionNavBar> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredPortugalRegions = [];

  // Regiões de Portugal
  static const List<String> portugueseRegions = [
    'Douro (Portugal)',
    'Alentejo (Portugal)',
    'Dão (Portugal)',
    'Vinho Verde (Portugal)',
  ];

  @override
  void initState() {
    super.initState();
    _filteredPortugalRegions = portugueseRegions;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterPortugalRegions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPortugalRegions = portugueseRegions;
      } else {
        _filteredPortugalRegions = portugueseRegions
            .where((region) =>
                region.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: _buildPortugalTab(),
    );
  }

  Widget _buildPortugalTab() {
    return Column(
      children: [
        // Campo de busca
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar vinhos...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _filterPortugalRegions('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: _filterPortugalRegions,
          ),
        ),
        // Lista horizontal de regiões de Portugal
        Expanded(
          child: _filteredPortugalRegions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nenhuma região encontrada',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _filteredPortugalRegions.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final region = isAll
                        ? WineRegions.all
                        : _filteredPortugalRegions[index - 1];
                    final isSelected = widget.selectedRegion == region;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 110,
                        child: Card(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Colors.white,
                          elevation: isSelected ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: isSelected
                                ? BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    width: 1.5,
                                  )
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => widget.onRegionChanged(region),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isAll ? Icons.all_inclusive : Icons.wine_bar,
                                    size: 26,
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isAll
                                        ? 'Todos'
                                        : region.replaceAll(' (Portugal)', ''),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 12,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

