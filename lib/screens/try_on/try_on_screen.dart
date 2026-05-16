import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/accessory.dart';
import '../../models/landmark.dart';
import '../../models/draggable_item.dart';
import '../../services/face_mesh_service.dart';
import '../../services/image_processor_service.dart';
import '../../core/utils/image_loader.dart';
import '../../core/constants.dart';
import 'item_isolator_screen.dart';

class TryOnScreen extends ConsumerStatefulWidget {
  const TryOnScreen({super.key});

  @override
  ConsumerState<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends ConsumerState<TryOnScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  bool _isProcessing = false;
  
  FaceData? _detectedFace;
  
  // Multi-item support (up to 3)
  final List<DraggableItem> _activeItems = [];
  bool _isDraggingItem = false;
  bool _isOverDustbin = false;

  late AnimationController _pulseController;
  final FaceMeshService _faceMeshService = FaceMeshService();

  // Keys to locate the dustbin for drag collisions
  final GlobalKey _dustbinKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
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
        _isProcessing = true;
        _detectedFace = null;
        _activeItems.clear(); // Clear items on new photo
      });
      
      final faceData = await _faceMeshService.detect(picked.path);
      
      if (mounted) {
        setState(() {
          _detectedFace = faceData;
          _isProcessing = false;
        });

        if (faceData == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Face not clear. AI placement won\'t work, but you can still drag items.'),
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

  Future<void> _uploadCustomAccessory() async {
    if (_activeItems.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum of 3 items reached. Please delete one first.'),
          backgroundColor: TryMaarTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Ask what category they are uploading (for AI initial placement)
    final category = await showDialog<AccessoryCategory>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: TryMaarTheme.surface,
          title: const Text('Select Item Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AccessoryCategory.values.map((c) {
              return ListTile(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(c.label),
                onTap: () => Navigator.pop(context, c),
              );
            }).toList(),
          ),
        );
      },
    );

    if (category == null) return; 

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TryMaarTheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: TryMaarTheme.primary),
              title: const Text('Take a photo of the item'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: TryMaarTheme.accent),
              title: const Text('Upload item from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      
      Uint8List? isolatedBytes;
      
      if (category == AccessoryCategory.glasses) {
        setState(() => _isProcessing = true);
        isolatedBytes = await ImageProcessorService.automaticIsolate(bytes);
      } else {
        // Navigate to Isolator Screen for manual extraction
        if (mounted) {
          isolatedBytes = await Navigator.push<Uint8List?>(
            context,
            MaterialPageRoute(
              builder: (_) => ItemIsolatorScreen(imageBytes: bytes),
            ),
          );
        }
      }

      if (isolatedBytes != null && mounted) {
        setState(() => _isProcessing = true);
        try {
          final customAccessory = Accessory(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            name: 'My Custom ${category.label}',
            category: category,
            imagePath: '', 
            customImageBytes: isolatedBytes,
            scaleAdjust: 1.0,
          );

          // Load UI image
          final ui.Image img = await ImageLoader.loadBytesImage(isolatedBytes);
          
          Offset initialPos = Offset(
            MediaQuery.of(context).size.width / 2 - (img.width / 4), 
            MediaQuery.of(context).size.height / 2 - (img.height / 4)
          );
          double initialScale = 1.0;
          
          if (_detectedFace != null && category == AccessoryCategory.glasses) {
             // Basic estimation for auto-snapping to the eyes
             // Assuming the image roughly fills the screen width (portrait selfie)
             final face = _detectedFace!;
             final screenW = MediaQuery.of(context).size.width - 32; // 16 margin on each side
             final scaleFactor = screenW / face.imageWidth;
             
             // Get eyes
             final leftEye = face.landmarks[LandmarkIndices.leftEyeOuter];
             final rightEye = face.landmarks[LandmarkIndices.rightEyeOuter];
             
             final eyeCenterX = (leftEye.x + rightEye.x) / 2 * scaleFactor;
             final eyeCenterY = (leftEye.y + rightEye.y) / 2 * scaleFactor;
             
             final eyeDistance = (rightEye.x - leftEye.x).abs() * scaleFactor;
             
             // Assume glasses width should be roughly 2.0x to 2.5x the eye distance
             final targetWidth = eyeDistance * 2.2;
             
             // The CustomPaint in DraggableAccessory draws at img.width / 2.
             // We want (img.width / 2) * scale = targetWidth
             initialScale = targetWidth / (img.width / 2);
             
             // We need to set the top-left position of the draggable widget.
             // The widget draws at (img.width/2 * scale) size.
             final drawW = (img.width / 2) * initialScale;
             final drawH = (img.height / 2) * initialScale;
             
             // Vertically center the display space (BoxFit.contain roughly centers it)
             final screenH = MediaQuery.of(context).size.height;
             final displayH = face.imageHeight * scaleFactor;
             final yOffset = (screenH - displayH) / 2;
             
             initialPos = Offset(
               eyeCenterX - (drawW / 2) + 16, // +16 for margin
               (eyeCenterY + yOffset) - (drawH / 2) - 60 // -60 adjust for appbar/safearea
             );
          }

          setState(() {
            _activeItems.add(DraggableItem(
              accessory: customAccessory,
              image: img,
              position: initialPos,
              scale: initialScale,
              autoSnapToFace: category == AccessoryCategory.glasses,
            ));
            _isProcessing = false;
          });
        } catch (e) {
          setState(() => _isProcessing = false);
          debugPrint('Failed to load isolated image: $e');
        }
      } else {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _onItemDragUpdate(Offset globalPosition) {
    if (_dustbinKey.currentContext != null) {
      final RenderBox renderBox = _dustbinKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final dustbinRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

      final isOver = dustbinRect.contains(globalPosition);
      if (_isOverDustbin != isOver) {
        setState(() {
          _isOverDustbin = isOver;
        });
      }
    }
  }

  void _onItemDragEnd(DraggableItem item, Offset globalPosition) {
    setState(() {
      _isDraggingItem = false;
      if (_isOverDustbin) {
        _activeItems.removeWhere((element) => element.id == item.id);
        _isOverDustbin = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TryMaarTheme.background,
      appBar: AppBar(
        title: const Text('Try On'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedImage == null
                ? _buildPhotoPrompt(context)
                : _buildTryOnPreview(context),
          ),
          if (_selectedImage != null)
            _buildBottomBar(context),
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
              'Take a selfie or upload a photo\nto start adding items',
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTryOnPreview(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // User photo
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
                Image.network(_selectedImage!.path, fit: BoxFit.contain),
                
                // Draggable Items
                ..._activeItems.map((item) {
                  return DraggableAccessoryWidget(
                    key: ValueKey(item.id),
                    item: item,
                    onDragStart: () => setState(() => _isDraggingItem = true),
                    onDragUpdate: _onItemDragUpdate,
                    onDragEnd: (globalPos) => _onItemDragEnd(item, globalPos),
                  );
                }),
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
                    'Processing...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ),

        // Floating Dustbin (visible when dragging)
        if (_isDraggingItem)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                key: _dustbinKey,
                width: _isOverDustbin ? 80 : 60,
                height: _isOverDustbin ? 80 : 60,
                decoration: BoxDecoration(
                  color: _isOverDustbin ? TryMaarTheme.error : TryMaarTheme.surfaceOverlay,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isOverDustbin ? Colors.white : TryMaarTheme.error.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    if (_isOverDustbin)
                      BoxShadow(
                        color: TryMaarTheme.error.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                  ],
                ),
                child: Icon(
                  _isOverDustbin ? Icons.delete_forever_rounded : Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: _isOverDustbin ? 40 : 28,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: TryMaarTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _uploadCustomAccessory,
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                color: TryMaarTheme.surfaceOverlay,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: TryMaarTheme.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_rounded, 
                    color: TryMaarTheme.accent, 
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Upload Item to Try On (${_activeItems.length}/3)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: TryMaarTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DraggableAccessoryWidget extends StatefulWidget {
  final DraggableItem item;
  final VoidCallback onDragStart;
  final Function(Offset) onDragUpdate;
  final Function(Offset) onDragEnd;

  const DraggableAccessoryWidget({
    super.key,
    required this.item,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<DraggableAccessoryWidget> createState() => _DraggableAccessoryWidgetState();
}

class _DraggableAccessoryWidgetState extends State<DraggableAccessoryWidget> {
  late Offset _position;
  late double _scale;
  late double _rotation;
  bool _isActive = false; // Whether this item is currently selected/touched
  
  Offset _startingPosition = Offset.zero;
  double _startingScale = 1.0;
  double _startingRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _position = widget.item.position;
    _scale = widget.item.scale;
    _rotation = widget.item.rotation;
  }

  @override
  Widget build(BuildContext context) {
    final drawW = widget.item.image.width.toDouble() / 2;
    final drawH = widget.item.image.height.toDouble() / 2;
    // Add padding for the shadow and selection handles
    const padding = 8.0;

    return Positioned(
      left: _position.dx - padding,
      top: _position.dy - padding,
      child: GestureDetector(
        onScaleStart: (details) {
          setState(() => _isActive = true);
          widget.onDragStart();
          _startingPosition = _position;
          _startingScale = _scale;
          _startingRotation = _rotation;
        },
        onScaleUpdate: (details) {
          setState(() {
            _position = _startingPosition + details.focalPointDelta;
            _startingPosition = _position;
            _scale = (_startingScale * details.scale).clamp(0.2, 5.0);
            _rotation = _startingRotation + details.rotation;
          });
          widget.onDragUpdate(details.focalPoint);
        },
        onScaleEnd: (details) {
          widget.item.position = _position;
          widget.item.scale = _scale;
          widget.item.rotation = _rotation;
          setState(() => _isActive = false);
          widget.onDragEnd(Offset.zero);
        },
        child: Transform(
          transform: Matrix4.identity()
            ..scale(_scale, _scale, 1.0)
            ..rotateZ(_rotation),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(padding),
            decoration: _isActive
                ? BoxDecoration(
                    border: Border.all(
                      color: TryMaarTheme.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: CustomPaint(
              size: Size(drawW, drawH),
              painter: _RealisticItemPainter(widget.item.image),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the item image with a subtle drop shadow for realism.
class _RealisticItemPainter extends CustomPainter {
  final ui.Image image;
  _RealisticItemPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Draw subtle drop shadow beneath the item
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(rect.shift(const Offset(2, 3)), shadowPaint);

    // 2. Draw the item image with high-quality filtering
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RealisticItemPainter oldDelegate) =>
      oldDelegate.image != image;
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
