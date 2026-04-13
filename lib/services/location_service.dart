import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _customLocationsKey = 'custom_locations_catalog_v1';
  static const String _hiddenDefaultLocationsKey =
      'hidden_default_locations_v1';

  static const List<String> defaultLocations = [
    'Adega Principal',
    'Adega Climatizada',
    'Prateleira A',
    'Prateleira B',
    'Prateleira C',
    'Armario',
    'Deposito',
    'Balcao',
    'Salao',
    'Cave',
  ];

  Future<List<String>> getCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customLocationsKey) ?? const [];
    final hiddenDefaults =
        prefs.getStringList(_hiddenDefaultLocationsKey) ?? const [];

    final catalog = <String>[];
    for (final location in defaultLocations) {
      final value = location.trim();
      if (value.isEmpty) continue;
      if (_containsIgnoreCase(hiddenDefaults, value)) continue;
      if (!_containsIgnoreCase(catalog, value)) {
        catalog.add(value);
      }
    }

    for (final location in custom) {
      final value = location.trim();
      if (value.isEmpty) continue;
      if (!_containsIgnoreCase(catalog, value)) {
        catalog.add(value);
      }
    }

    return catalog;
  }

  Future<void> addCustomLocation(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (_containsIgnoreCase(defaultLocations, trimmed)) {
      final hiddenDefaults = List<String>.from(
        prefs.getStringList(_hiddenDefaultLocationsKey) ?? const [],
      );
      hiddenDefaults.removeWhere(
        (item) => item.toLowerCase() == trimmed.toLowerCase(),
      );
      await prefs.setStringList(_hiddenDefaultLocationsKey, hiddenDefaults);
      return;
    }

    final custom = List<String>.from(
      prefs.getStringList(_customLocationsKey) ?? const [],
    );

    if (_containsIgnoreCase(custom, trimmed)) {
      return;
    }

    custom.add(trimmed);
    await prefs.setStringList(_customLocationsKey, custom);
  }

  Future<void> removeCustomLocation(String value) async {
    await removeLocation(value);
  }

  Future<bool> removeLocation(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();

    if (_containsIgnoreCase(defaultLocations, trimmed)) {
      final hiddenDefaults = List<String>.from(
        prefs.getStringList(_hiddenDefaultLocationsKey) ?? const [],
      );
      if (!_containsIgnoreCase(hiddenDefaults, trimmed)) {
        hiddenDefaults.add(trimmed);
        await prefs.setStringList(_hiddenDefaultLocationsKey, hiddenDefaults);
      }
      return true;
    }

    final custom = List<String>.from(
      prefs.getStringList(_customLocationsKey) ?? const [],
    );

    final originalLength = custom.length;
    custom.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    await prefs.setStringList(_customLocationsKey, custom);
    return custom.length != originalLength;
  }

  bool isDefaultLocation(String value) {
    return _containsIgnoreCase(defaultLocations, value);
  }

  bool _containsIgnoreCase(List<String> source, String value) {
    final normalized = value.toLowerCase();
    return source.any((item) => item.toLowerCase() == normalized);
  }
}
