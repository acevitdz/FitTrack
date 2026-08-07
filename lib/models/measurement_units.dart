enum MeasurementUnitSystem {
  metric,
  imperial;

  static const _centimetersPerInch = 2.54;
  static const _kilogramsPerPound = 0.45359237;

  static MeasurementUnitSystem fromStored(String? value) => switch (value) {
    'imperial' || 'lb' || 'lbs' || 'inch' => imperial,
    _ => metric,
  };

  String get storageKey => name;
  String get heightSymbol => this == metric ? 'cm' : 'in';
  String get weightSymbol => this == metric ? 'kg' : 'lb';
  String get label => this == metric ? 'Hệ mét (cm, kg)' : 'Hệ Anh (in, lb)';

  double heightFromCentimeters(double centimeters) =>
      this == metric ? centimeters : centimeters / _centimetersPerInch;

  double weightFromKilograms(double kilograms) =>
      this == metric ? kilograms : kilograms / _kilogramsPerPound;

  double heightToCentimeters(double value) =>
      this == metric ? value : value * _centimetersPerInch;

  double weightToKilograms(double value) =>
      this == metric ? value : value * _kilogramsPerPound;

  String formatHeight(double centimeters) =>
      '${heightFromCentimeters(centimeters).toStringAsFixed(this == metric ? 0 : 1)} $heightSymbol';

  String formatWeight(double kilograms) =>
      '${weightFromKilograms(kilograms).toStringAsFixed(1)} $weightSymbol';
}
