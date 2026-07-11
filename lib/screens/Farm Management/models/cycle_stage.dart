import 'package:flutter/material.dart';

/// The growth stages a coffee farm cycle moves through, in chronological
/// order. Used to drive stage badges, activity forms and progress banners.
enum CycleStage {
  landPrep,
  planting,
  vegetative,
  flowering,
  cherryDevelopment,
  harvest,
  postHarvest,
}

extension CycleStageX on CycleStage {
  String get label {
    switch (this) {
      case CycleStage.landPrep:
        return 'Land Preparation';
      case CycleStage.planting:
        return 'Planting';
      case CycleStage.vegetative:
        return 'Vegetative Growth';
      case CycleStage.flowering:
        return 'Flowering';
      case CycleStage.cherryDevelopment:
        return 'Cherry Development';
      case CycleStage.harvest:
        return 'Harvest';
      case CycleStage.postHarvest:
        return 'Post-Harvest';
    }
  }

  IconData get icon {
    switch (this) {
      case CycleStage.landPrep:
        return Icons.terrain;
      case CycleStage.planting:
        return Icons.grass;
      case CycleStage.vegetative:
        return Icons.eco;
      case CycleStage.flowering:
        return Icons.local_florist;
      case CycleStage.cherryDevelopment:
        return Icons.circle;
      case CycleStage.harvest:
        return Icons.agriculture;
      case CycleStage.postHarvest:
        return Icons.inventory_2;
    }
  }

  String get storageValue => name;

  static CycleStage fromStorage(String? value) {
    return CycleStage.values.firstWhere(
      (s) => s.name == value,
      orElse: () => CycleStage.landPrep,
    );
  }

  CycleStage? get next {
    final idx = CycleStage.values.indexOf(this);
    if (idx + 1 >= CycleStage.values.length) return null;
    return CycleStage.values[idx + 1];
  }
}
