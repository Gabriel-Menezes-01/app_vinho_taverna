// Regiões de vinho de Portugal
class WineRegions {
  static const String all = 'Todas';
  static const String houseWine = 'Vinho da Casa';
  static const String todaySuggestion = 'Sugestão do Dia';

  // Regiões de Portugal
  static const List<String> regions = [
    all,
    // Portugal
    'Vinho Verde (Portugal)',
    'Trás-os-Montes (Portugal)',
    'Douro (Portugal)',
    'Távora-Varosa (Portugal)',
    'Dão (Portugal)',
    'Bairrada (Portugal)',
    'Beira Interior (Portugal)',
    'Lisboa (Portugal)',
    'Tejo (Portugal)',
    'Península de Setúbal (Portugal)',
    'Alentejo (Portugal)',
    'Algarve (Portugal)',
    'Madeira (Ilha da Madeira)',
    'Açores (Ilhas dos Açores)',
    'Outra região',
  ];

  static List<String> getRegionsByCountry(String country) {
    return regions
        .where(
          (region) =>
              region.contains(country) ||
              region == all ||
              region == 'Outra região',
        )
        .toList();
  }
}
