import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kMeasurementUnit = 'measurement_unit';

enum MeasurementUnit { inches, cm }

extension MeasurementUnitX on MeasurementUnit {
  String get label => this == MeasurementUnit.inches ? 'Inches' : 'Centimetres';
  String get shortLabel => this == MeasurementUnit.inches ? 'in' : 'cm';
}

final measurementUnitProvider =
    StateNotifierProvider<MeasurementUnitNotifier, MeasurementUnit>((ref) {
  return MeasurementUnitNotifier();
});

class MeasurementUnitNotifier extends StateNotifier<MeasurementUnit> {
  MeasurementUnitNotifier() : super(MeasurementUnit.inches) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kMeasurementUnit);
    if (stored == 'cm') {
      state = MeasurementUnit.cm;
    } else {
      state = MeasurementUnit.inches;
    }
  }

  Future<void> setUnit(MeasurementUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMeasurementUnit, unit == MeasurementUnit.cm ? 'cm' : 'inches');
  }
}
