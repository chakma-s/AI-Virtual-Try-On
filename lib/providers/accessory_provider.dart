import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/accessory.dart';

/// Provides the full list of available accessories.
final accessoryListProvider = Provider<List<Accessory>>((ref) {
  return [];
});

/// Currently selected category filter.
final selectedCategoryProvider = StateProvider<AccessoryCategory?>(
  (ref) => null,
);

/// Currently selected accessory for try-on.
final selectedAccessoryProvider = StateProvider<Accessory?>(
  (ref) => null,
);
