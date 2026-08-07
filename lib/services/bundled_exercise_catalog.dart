import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/exercise.dart';

/// Loads the reviewed asset for catalog migration tools and tests.
///
/// Production exercise screens intentionally use Firestore only.
class BundledExerciseCatalog {
  const BundledExerciseCatalog({this.assetPath = _defaultAssetPath});

  static const _defaultAssetPath = 'assets/data/free_exercise_db_reviewed.json';

  final String assetPath;

  Future<List<Exercise>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['exercises'] is! List) {
      throw const FormatException('Bundled exercise catalog is invalid.');
    }
    return (decoded['exercises'] as List)
        .whereType<Map>()
        .map((item) => Exercise.fromJson(Map<String, dynamic>.from(item)))
        .where((exercise) => exercise.isCatalogApproved)
        .toList(growable: false);
  }
}
