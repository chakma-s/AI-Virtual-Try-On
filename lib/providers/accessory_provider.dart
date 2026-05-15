import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/accessory.dart';

/// Provides the full list of available accessories.
final accessoryListProvider = Provider<List<Accessory>>((ref) {
  // In production, load from JSON. For MVP, hardcoded catalog.
  return _sampleAccessories;
});

/// Currently selected category filter.
final selectedCategoryProvider = StateProvider<AccessoryCategory?>(
  (ref) => null,
);

/// Currently selected accessory for try-on.
final selectedAccessoryProvider = StateProvider<Accessory?>(
  (ref) => null,
);

/// Filtered accessories based on selected category.
final filteredAccessoriesProvider = Provider<List<Accessory>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final all = ref.watch(accessoryListProvider);
  if (category == null) return all;
  return all.where((a) => a.category == category).toList();
});

// ─── Sample Catalog ───
// These use placeholder paths — we'll generate actual accessory images next.
const _sampleAccessories = <Accessory>[
  // Glasses
  Accessory(
    id: 'glasses_aviator',
    name: 'Classic Aviator',
    category: AccessoryCategory.glasses,
    imagePath: 'assets/accessories/glasses/aviator.png',
    scaleAdjust: 1.15,
    offsetY: 2.0,
  ),
  Accessory(
    id: 'glasses_round',
    name: 'Retro Round',
    category: AccessoryCategory.glasses,
    imagePath: 'assets/accessories/glasses/round.png',
    scaleAdjust: 1.0,
  ),
  Accessory(
    id: 'glasses_cat_eye',
    name: 'Cat Eye',
    category: AccessoryCategory.glasses,
    imagePath: 'assets/accessories/glasses/cat_eye.png',
    scaleAdjust: 1.1,
    offsetY: -2.0,
  ),
  Accessory(
    id: 'glasses_wayfarer',
    name: 'Wayfarer',
    category: AccessoryCategory.glasses,
    imagePath: 'assets/accessories/glasses/wayfarer.png',
    scaleAdjust: 1.05,
  ),
  Accessory(
    id: 'glasses_oversized',
    name: 'Oversized Glam',
    category: AccessoryCategory.glasses,
    imagePath: 'assets/accessories/glasses/oversized.png',
    scaleAdjust: 1.25,
  ),

  // Earrings
  Accessory(
    id: 'earring_hoop_gold',
    name: 'Gold Hoops',
    category: AccessoryCategory.earrings,
    imagePath: 'assets/accessories/earrings/hoop_gold.png',
    scaleAdjust: 1.0,
  ),
  Accessory(
    id: 'earring_drop_crystal',
    name: 'Crystal Drops',
    category: AccessoryCategory.earrings,
    imagePath: 'assets/accessories/earrings/drop_crystal.png',
    scaleAdjust: 1.2,
    offsetY: 5.0,
  ),
  Accessory(
    id: 'earring_stud_diamond',
    name: 'Diamond Studs',
    category: AccessoryCategory.earrings,
    imagePath: 'assets/accessories/earrings/stud_diamond.png',
    scaleAdjust: 0.7,
  ),
  Accessory(
    id: 'earring_chandelier',
    name: 'Chandelier',
    category: AccessoryCategory.earrings,
    imagePath: 'assets/accessories/earrings/chandelier.png',
    scaleAdjust: 1.4,
    offsetY: 8.0,
  ),

  // Hats
  Accessory(
    id: 'hat_fedora',
    name: 'Classic Fedora',
    category: AccessoryCategory.hats,
    imagePath: 'assets/accessories/hats/fedora.png',
    scaleAdjust: 1.1,
    offsetY: -10.0,
  ),
  Accessory(
    id: 'hat_beanie',
    name: 'Cozy Beanie',
    category: AccessoryCategory.hats,
    imagePath: 'assets/accessories/hats/beanie.png',
    scaleAdjust: 1.0,
  ),
  Accessory(
    id: 'hat_cap',
    name: 'Baseball Cap',
    category: AccessoryCategory.hats,
    imagePath: 'assets/accessories/hats/cap.png',
    scaleAdjust: 1.15,
    offsetY: -5.0,
  ),

  // Necklaces
  Accessory(
    id: 'necklace_pearl',
    name: 'Pearl Strand',
    category: AccessoryCategory.necklaces,
    imagePath: 'assets/accessories/necklaces/pearl.png',
    scaleAdjust: 1.0,
  ),
  Accessory(
    id: 'necklace_chain_gold',
    name: 'Gold Chain',
    category: AccessoryCategory.necklaces,
    imagePath: 'assets/accessories/necklaces/chain_gold.png',
    scaleAdjust: 0.9,
  ),
  Accessory(
    id: 'necklace_choker',
    name: 'Velvet Choker',
    category: AccessoryCategory.necklaces,
    imagePath: 'assets/accessories/necklaces/choker.png',
    scaleAdjust: 0.85,
    offsetY: -5.0,
  ),
];
