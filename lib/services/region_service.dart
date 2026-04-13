import 'package:shared_preferences/shared_preferences.dart';

import '../models/wine_regions.dart';

class RegionService {
  static const String _customRegionsKey = 'custom_regions_catalog_v1';
  static const String _hiddenDefaultRegionsKey = 'hidden_default_regions_v1';

  static const List<String> _protectedRegions = [
    WineRegions.all,
    'Outra região',
  ];

  Future<List<String>> getCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getStringList(_customRegionsKey) ?? const [];
    final hiddenDefaults = prefs.getStringList(_hiddenDefaultRegionsKey) ?? const [];

    final catalog = <String>[];

    for (final region in WineRegions.regions) {
      final value = region.trim();
      if (value.isEmpty) continue;
      if (_containsIgnoreCase(hiddenDefaults, value)) continue;
      if (!_containsIgnoreCase(catalog, value)) {
        catalog.add(value);
      }
    }

    for (final region in custom) {
      final value = region.trim();
      if (value.isEmpty) continue;
      if (!_containsIgnoreCase(catalog, value)) {
        catalog.add(value);
      }
    }

    if (!_containsIgnoreCase(catalog, 'Outra região')) {
      catalog.add('Outra região');
    }

    return catalog;
  }

  Future<void> addCustomRegion(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (_containsIgnoreCase(WineRegions.regions, trimmed)) {
      final hiddenDefaults = List<String>.from(
        prefs.getStringList(_hiddenDefaultRegionsKey) ?? const [],
      );
      hiddenDefaults.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      await prefs.setStringList(_hiddenDefaultRegionsKey, hiddenDefaults);
      return;
    }

    final custom = List<String>.from(
      prefs.getStringList(_customRegionsKey) ?? const [],
    );
    if (_containsIgnoreCase(custom, trimmed)) return;

    custom.add(trimmed);
    await prefs.setStringList(_customRegionsKey, custom);
  }

  Future<bool> removeRegion(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || isProtectedRegion(trimmed)) return false;

    final prefs = await SharedPreferences.getInstance();

    if (_containsIgnoreCase(WineRegions.regions, trimmed)) {
      final hiddenDefaults = List<String>.from(
        prefs.getStringList(_hiddenDefaultRegionsKey) ?? const [],
      );
      if (_containsIgnoreCase(hiddenDefaults, trimmed)) return false;
      hiddenDefaults.add(trimmed);
      await prefs.setStringList(_hiddenDefaultRegionsKey, hiddenDefaults);
      return true;
    }

    final custom = List<String>.from(
      prefs.getStringList(_customRegionsKey) ?? const [],
    );
    final originalLength = custom.length;
    custom.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    if (custom.length == originalLength) return false;

    await prefs.setStringList(_customRegionsKey, custom);
    return true;
  }

  bool isProtectedRegion(String value) {
    return _containsIgnoreCase(_protectedRegions, value);
  }

  bool _containsIgnoreCase(List<String> source, String value) {
    final normalized = value.toLowerCase();
    return source.any((item) => item.toLowerCase() == normalized);
  }
}
