import 'package:shared_preferences/shared_preferences.dart';

class CastaService {
  static const String _customCastasKey = 'custom_castas_catalog_v1';

  static const List<String> defaultCastas = [
    'Touriga Nacional',
    'Arinto',
    'Syrah',
    'Cabernet Sauvignon',
    'Merlot',
    'Tempranillo',
    'Chardonnay',
    'Sauvignon Blanc',
    'Pinot Noir',
    'Alvarinho',
  ];

  Future<List<String>> getCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customCastasKey) ?? const [];

    final catalog = <String>[];
    for (final casta in [...defaultCastas, ...custom]) {
      final value = casta.trim();
      if (value.isEmpty) continue;
      if (!_containsIgnoreCase(catalog, value)) {
        catalog.add(value);
      }
    }

    return catalog;
  }

  Future<void> addCustomCasta(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final custom = List<String>.from(
      prefs.getStringList(_customCastasKey) ?? const [],
    );

    if (_containsIgnoreCase(defaultCastas, trimmed) ||
        _containsIgnoreCase(custom, trimmed)) {
      return;
    }

    custom.add(trimmed);
    await prefs.setStringList(_customCastasKey, custom);
  }

  Future<void> removeCustomCasta(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final custom = List<String>.from(
      prefs.getStringList(_customCastasKey) ?? const [],
    );

    custom.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    await prefs.setStringList(_customCastasKey, custom);
  }

  bool isDefaultCasta(String value) {
    return _containsIgnoreCase(defaultCastas, value);
  }

  bool _containsIgnoreCase(List<String> source, String value) {
    final normalized = value.toLowerCase();
    return source.any((item) => item.toLowerCase() == normalized);
  }
}
