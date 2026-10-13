import 'package:biolivestock_capture/species.dart';
import 'package:flutter_test/flutter_test.dart';

SpeciesConfig config(Map<String, dynamic> numbering) => SpeciesConfig.fromJson({
  'species': 'cattle',
  'enabled': true,
  'quality': <String, dynamic>{},
  'numbering': numbering,
});

void main() {
  test(
    'series preview and cached rules round trip without allocating an ID',
    () {
      final current = config({'prefix': 'M', 'digits': 8, 'series_letters': 2});
      expect(current.numberingExample, 'MAA00000001');
      expect(
        SpeciesConfig.fromJson(current.toJson()).numberingExample,
        'MAA00000001',
      );
    },
  );
  test('older cached rules and legacy IDs keep their original shape', () {
    expect(config({'prefix': 'M', 'digits': 8}).numberingExample, 'M00000001');
    expect(
      SpeciesConfig.fromJson({
        'species': 'cattle',
        'enabled': true,
        'quality': <String, dynamic>{},
      }).numberingExample,
      isNull,
    );
  });
  test('invalid cached numbering is not displayed as valid guidance', () {
    for (final rules in [
      {'prefix': 'M', 'digits': 100},
      {'prefix': 'M', 'digits': 8, 'series_letters': -1},
      {'prefix': 'M', 'digits': 8, 'series_letters': 3},
      {'prefix': 'M', 'digits': '8'},
      {'prefix': 'bad prefix', 'digits': 8},
    ]) {
      expect(config(rules).numberingExample, isNull);
    }
  });
}
