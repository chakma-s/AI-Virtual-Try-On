import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/accessory.dart';
import '../../models/landmark.dart';
import '../../providers/accessory_provider.dart';
import '../../services/face_mesh_service.dart';
import '../../services/transform_service.dart';
import '../../services/compositor_service.dart';
import '../../services/image_processor_service.dart';
import '../../core/utils/image_loader.dart';
import '../../core/constants.dart';

/// The main try-on screen where users see their photo with the accessory overlay.
class TryOnScreen extends ConsumerStatefulWidget {
  const TryOnScreen({super.key});

  @override
  ConsumerState<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends ConsumerState<TryOnScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  bool _isProcessing = false;
  bool _showLandmarks = false;
  bool _isDemoMode = false;
  
  FaceData? _detectedFace;
  ui.Image? _accessoryUiImage;
  String? _loadedAccessoryId;

  late AnimationController _pulseController;
  final FaceMeshService _faceMeshService = FaceMeshService();
  final TransformService _transformService = const TransformService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Initialize the FaceMeshService (loads JS scripts on web)
    _faceMeshService.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _isDemoMode = false;
        _isProcessing = true;
        _detectedFace = null;
      });
      
      // Pass the picked.path (blob URL on web, local path on mobile) to face detector
      final faceData = await _faceMeshService.detect(picked.path);
      
      if (mounted) {
        setState(() {
          _detectedFace = faceData;
          _isProcessing = false;
        });

        if (faceData == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No face detected. Please try another photo.'),
              backgroundColor: TryMaarTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _useDemoFace() async {
    setState(() {
      _selectedImage = null;
      _isDemoMode = true;
      _isProcessing = true;
      _detectedFace = null;
    });
    
    // Pass the asset path to the face detector
    // Load as base64 to avoid Flutter Web relative path routing issues in JS
    final ByteData data = await rootBundle.load('assets/demo/demo_face.png');
    final Uint8List bytes = data.buffer.asUint8List();
    final String base64String = base64Encode(bytes);
    final String dataUrl = 'data:image/png;base64,$base64String';
    
    final faceData = await _faceMeshService.detect(dataUrl);
    
    if (mounted) {
      setState(() {
        _detectedFace = faceData;
        _isProcessing = false;
      });

      if (faceData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to detect face on demo model.'),
            backgroundColor: TryMaarTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAccessoryImage(Accessory accessory) async {
    if (_loadedAccessoryId == accessory.id) return;
    try {
      ui.Image img;
      if (accessory.customImageBytes != null) {
        img = await ImageLoader.loadBytesImage(accessory.customImageBytes!);
      } else {
        img = await ImageLoader.loadAssetImage(accessory.imagePath);
      }
      
      if (mounted) {
        setState(() {
          _accessoryUiImage = img;
          _loadedAccessoryId = accessory.id;
        });
      }
    } catch (e) {
      print('Failed to load accessory image: $e');
    }
  }

  Future<void> _uploadCustomAccessory() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isProcessing = true);
      try {
        final bytes = await picked.readAsBytes();
        final processedBytes = await ImageProcessorService.removeWhiteBackground(bytes);
        
        if (processedBytes != null && mounted) {
          final customAccessory = Accessory(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            name: 'Custom Item',
            category: AccessoryCategory.glasses,
            imagePath: '', // Dynamic item has no path
            customImageBytes: processedBytes,
            scaleAdjust: 1.0,
          );
          
          ref.read(selectedAccessoryProvider.notifier).state = customAccessory;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Custom item uploaded and processed!'),
              backgroundColor: TryMaarTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to process image.'),
              backgroundColor: TryMaarTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        print('Upload custom error: $e');
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessory = ref.watch(selectedAccessoryProvider);
    final accessories = ref.watch(filteredAccessoriesProvider);

    // Load UI image if accessory changed
    if (accessory != null && _loadedAccessoryId != accessory.id) {
      _loadAccessoryImage(accessory);
    }

    return Scaffold(
      backgroundColor: TryMaarTheme.background,
      appBar: AppBar(
        title: Text(accessory?.name ?? 'Try On'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if ((_selectedImage != null || _isDemoMode) && _detectedFace != null)
            IconButton(
              icon: Icon(
                _showLandmarks ? Icons.visibility : Icons.visibility_off,
                color: _showLandmarks
                    ? TryMaarTheme.accent
                    : TryMaarTheme.textSecondary,
              ),
              tooltip: 'Toggle landmarks',
              onPressed: () {
                setState(() => _showLandmarks = !_showLandmarks);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Preview Area ───
          Expanded(
            child: (_selectedImage == null && !_isDemoMode)
                ? _buildPhotoPrompt(context)
                : _buildTryOnPreview(context, accessory),
          ),

          // ─── Bottom Controls ───
          _buildBottomBar(context, accessory, accessories),
        ],
      ),
    );
  }

  Widget _buildPhotoPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TryMaarTheme.primary.withValues(
                      alpha: 0.05 + (_pulseController.value * 0.1),
                    ),
                    border: Border.all(
                      color: TryMaarTheme.primary.withValues(
                        alpha: 0.2 + (_pulseController.value * 0.2),
                      ),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 48,
                    color: TryMaarTheme.primary.withValues(
                      alpha: 0.5 + (_pulseController.value * 0.5),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Add Your Photo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a selfie or upload a photo\nto see the accessory on you',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: TryMaarTheme.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: TryMaarTheme.primary,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: TryMaarTheme.accent,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.face_retouching_natural_rounded,
                  label: 'Demo Model',
                  color: TryMaarTheme.success,
                  onTap: _useDemoFace,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTryOnPreview(BuildContext context, Accessory? accessory) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // User photo inside a FittedBox to map canvas correctly
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TryMaarTheme.radiusLg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TryMaarTheme.radiusLg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _isDemoMode 
                    ? Image.asset('assets/demo/demo_face.png', fit: BoxFit.contain)
                    : Image.network(_selectedImage!.path, fit: BoxFit.contain),
                
                // Drawing overlay layer mapped to image dimensions
                if (_detectedFace != null && accessory != null && _accessoryUiImage != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // We need to scale the canvas drawing coordinates to match the BoxFit.contain sizing
                      final imageWidth = _detectedFace!.imageWidth.toDouble();
                      final imageHeight = _detectedFace!.imageHeight.toDouble();
                      final widgetWidth = constraints.maxWidth;
                      final widgetHeight = constraints.maxHeight;

                      final double imageAspectRatio = imageWidth / imageHeight;
                      final double widgetAspectRatio = widgetWidth / widgetHeight;
                      
                      double drawWidth, drawHeight;
                      if (imageAspectRatio > widgetAspectRatio) {
                        drawWidth = widgetWidth;
                        drawHeight = widgetWidth / imageAspectRatio;
                      } else {
                        drawHeight = widgetHeight;
                        drawWidth = widgetHeight * imageAspectRatio;
                      }

                      final scaleX = drawWidth / imageWidth;
                      final scaleY = drawHeight / imageHeight;
                      final offsetX = (widgetWidth - drawWidth) / 2;
                      final offsetY = (widgetHeight - drawHeight) / 2;

                      final accessoryRatio = _accessoryUiImage!.width / _accessoryUiImage!.height;
                      final transform = _transformService.computeTransform(
                        face: _detectedFace!,
                        accessory: accessory,
                        accessoryAspectRatio: accessoryRatio,
                      );

                      return Stack(
                        children: [
                          Positioned(
                            left: offsetX,
                            top: offsetY,
                            width: drawWidth,
                            height: drawHeight,
                            child: Transform.scale(
                              scaleX: scaleX,
                              scaleY: scaleY,
                              alignment: Alignment.topLeft,
                              child: CustomPaint(
                                painter: AccessoryOverlayPainter(
                                  accessoryImage: _accessoryUiImage!,
                                  transform: transform,
                                ),
                              ),
                            ),
                          ),
                          if (_showLandmarks)
                            Positioned(
                              left: offsetX,
                              top: offsetY,
                              width: drawWidth,
                              height: drawHeight,
                              child: Transform.scale(
                                scaleX: scaleX,
                                scaleY: scaleY,
                                alignment: Alignment.topLeft,
                                child: CustomPaint(
                                  painter: LandmarkDebugPainter(
                                    landmarks: _detectedFace!.landmarks.map((l) => Offset(l.x, l.y)).toList(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: TryMaarTheme.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detecting face landmarks...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ),

        // Accessory info badge
        if (accessory != null && !_isProcessing)
          Positioned(
            top: 28,
            right: 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    accessory.category.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    accessory.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),

        // Change photo button
        if (!_isProcessing)
          Positioned(
            bottom: 28,
            right: 28,
            child: FloatingActionButton.small(
              heroTag: 'change_photo',
              onPressed: () => _showPhotoOptions(context),
              backgroundColor: TryMaarTheme.surfaceLight,
              child: const Icon(Icons.refresh_rounded, size: 22),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    Accessory? selected,
    List<Accessory> accessories,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
      decoration: BoxDecoration(
        color: TryMaarTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accessory switcher carousel
          SizedBox(
            height: 72,
            child: Row(
              children: [
                // Custom Upload Button
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                  child: GestureDetector(
                    onTap: _uploadCustomAccessory,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: TryMaarTheme.surfaceOverlay,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: TryMaarTheme.accent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_photo_alternate_rounded, 
                          color: TryMaarTheme.accent, 
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: TryMaarTheme.divider,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                // Catalog List
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: accessories.length,
                    itemBuilder: (context, index) {
                final item = accessories[index];
                final isSelected = item.id == selected?.id;
                return GestureDetector(
                  onTap: () {
                    ref.read(selectedAccessoryProvider.notifier).state = item;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TryMaarTheme.primary.withValues(alpha: 0.2)
                          : TryMaarTheme.surfaceOverlay,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? TryMaarTheme.primary
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.category == AccessoryCategory.glasses 
                            ? (item.id.startsWith('custom') ? '✨' : item.category.emoji)
                            : item.category.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ), // end Expanded
        ],
      ),
    ), // end SizedBox
    const SizedBox(height: 12),
    // Action buttons
          if (_selectedImage != null || _isDemoMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Compare view coming soon!'),
                            backgroundColor: TryMaarTheme.surfaceLight,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.compare_rounded, size: 18),
                      label: const Text('Compare'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('✅ Saved to gallery!'),
                            backgroundColor: TryMaarTheme.surfaceLight,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_alt_rounded, size: 18),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: TryMaarTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TryMaarTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TryMaarTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Change Photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TryMaarTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: TryMaarTheme.primary,
                    ),
                  ),
                  title: const Text('Take a selfie'),
                  subtitle: Text(
                    'Use your camera',
                    style: TextStyle(color: TryMaarTheme.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TryMaarTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: TryMaarTheme.accent,
                    ),
                  ),
                  title: const Text('Choose from gallery'),
                  subtitle: Text(
                    'Upload an existing photo',
                    style: TextStyle(color: TryMaarTheme.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TryMaarTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: TryMaarTheme.success,
                    ),
                  ),
                  title: const Text('Use Demo Model'),
                  subtitle: Text(
                    'Try accessories on an AI model',
                    style: TextStyle(color: TryMaarTheme.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _useDemoFace();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: TryMaarTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
