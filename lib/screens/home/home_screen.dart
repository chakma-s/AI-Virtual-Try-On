import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/accessory_provider.dart';
import '../catalog/catalog_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // ─── Logo + App Name ───
                _buildHeader(context),
                const SizedBox(height: 40),
                // ─── Hero Section ───
                _buildHeroCard(context),
                const SizedBox(height: 36),
                // ─── Category Grid ───
                Text(
                  'Choose Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildCategoryGrid(context, ref),
                const SizedBox(height: 36),
                // ─── How It Works ───
                _buildHowItWorks(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: TryMaarTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          'TryMaar',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            // TODO: Settings / About
          },
          icon: Icon(
            Icons.more_vert_rounded,
            color: TryMaarTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A4E), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(TryMaarTheme.radiusLg),
        border: Border.all(
          color: TryMaarTheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: TryMaarTheme.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TryMaarTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✨ AI-Powered',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: TryMaarTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Try Before\nYou Wear',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 36,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Virtually try on glasses, earrings, hats & more using just a selfie. Powered by on-device AI.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: TryMaarTheme.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CatalogScreen(),
                ),
              );
            },
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
            label: const Text('Start Try-On'),
            style: FilledButton.styleFrom(
              backgroundColor: TryMaarTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, WidgetRef ref) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.4,
      children: AccessoryCategory.values.map((category) {
        return _CategoryCard(
          category: category,
          onTap: () {
            ref.read(selectedCategoryProvider.notifier).state = category;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CatalogScreen(),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    final steps = [
      ('📸', 'Take a Selfie', 'Use your camera or upload a photo'),
      ('👓', 'Pick an Accessory', 'Browse our curated collection'),
      ('✨', 'See the Magic', 'AI places it perfectly on you'),
      ('💾', 'Save & Share', 'Download or share to socials'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final (emoji, title, subtitle) = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: TryMaarTheme.glassCard(),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TryMaarTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: TryMaarTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${entry.key + 1}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: TryMaarTheme.primary.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AccessoryCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  static const _categoryIcons = {
    AccessoryCategory.glasses: Icons.visibility_rounded,
    AccessoryCategory.earrings: Icons.diamond_rounded,
    AccessoryCategory.hats: Icons.school_rounded,
    AccessoryCategory.necklaces: Icons.all_inclusive_rounded,
  };

  static const _categoryColors = {
    AccessoryCategory.glasses: Color(0xFF7C4DFF),
    AccessoryCategory.earrings: Color(0xFFE040FB),
    AccessoryCategory.hats: Color(0xFF00E5FF),
    AccessoryCategory.necklaces: Color(0xFFFFAB40),
  };

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[category] ?? TryMaarTheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TryMaarTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TryMaarTheme.surfaceLight,
            borderRadius: BorderRadius.circular(TryMaarTheme.radiusMd),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcons[category],
                  color: color,
                  size: 22,
                ),
              ),
              Text(
                category.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
