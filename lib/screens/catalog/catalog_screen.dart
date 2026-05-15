import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/accessory.dart';
import '../../providers/accessory_provider.dart';
import '../try_on/try_on_screen.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final accessories = ref.watch(filteredAccessoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ─── Category Filter Chips ───
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All',
                  emoji: '✨',
                  isSelected: selectedCategory == null,
                  onTap: () {
                    ref.read(selectedCategoryProvider.notifier).state = null;
                  },
                ),
                ...AccessoryCategory.values.map((cat) {
                  return _FilterChip(
                    label: cat.label,
                    emoji: cat.emoji,
                    isSelected: selectedCategory == cat,
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).state = cat;
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ─── Accessory Grid ───
          Expanded(
            child: accessories.isEmpty
                ? _buildEmptyState(context)
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: accessories.length,
                    itemBuilder: (context, index) {
                      return _AccessoryCard(
                        accessory: accessories[index],
                        onTap: () {
                          ref.read(selectedAccessoryProvider.notifier).state =
                              accessories[index];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TryOnScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: TryMaarTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No accessories found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: TryMaarTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? TryMaarTheme.primary.withValues(alpha: 0.2)
                : TryMaarTheme.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? TryMaarTheme.primary
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? TryMaarTheme.primary
                          : TryMaarTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessoryCard extends StatelessWidget {
  final Accessory accessory;
  final VoidCallback onTap;

  const _AccessoryCard({required this.accessory, required this.onTap});

  static const _categoryColors = {
    AccessoryCategory.glasses: Color(0xFF7C4DFF),
    AccessoryCategory.earrings: Color(0xFFE040FB),
    AccessoryCategory.hats: Color(0xFF00E5FF),
    AccessoryCategory.necklaces: Color(0xFFFFAB40),
  };

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[accessory.category] ?? TryMaarTheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TryMaarTheme.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            color: TryMaarTheme.surfaceLight,
            borderRadius: BorderRadius.circular(TryMaarTheme.radiusMd),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview area
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: TryMaarTheme.surfaceOverlay,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(TryMaarTheme.radiusMd),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getCategoryIcon(accessory.category),
                      size: 48,
                      color: color.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              // Info area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        accessory.name,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              accessory.category.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: TryMaarTheme.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(AccessoryCategory category) {
    switch (category) {
      case AccessoryCategory.glasses:
        return Icons.visibility_rounded;
      case AccessoryCategory.earrings:
        return Icons.diamond_rounded;
      case AccessoryCategory.hats:
        return Icons.school_rounded;
      case AccessoryCategory.necklaces:
        return Icons.all_inclusive_rounded;
    }
  }
}
