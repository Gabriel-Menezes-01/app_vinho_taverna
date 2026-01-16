// Regiões de vinho de Portugal
class WineRegions {
  static const String all = 'Todas';
  
  // Regiões de Portugal
  static const List<String> regions = [
    all,
    // Portugal
    'Douro (Portugal)',
    'Alentejo (Portugal)',
    'Dão (Portugal)',
    'Vinho Verde (Portugal)',
    'Outra região',
  ];
  
  static List<String> getRegionsByCountry(String country) {
    return regions
        .where((region) => region.contains(country) || region == all || region == 'Outra região')
        .toList();
  }
}
