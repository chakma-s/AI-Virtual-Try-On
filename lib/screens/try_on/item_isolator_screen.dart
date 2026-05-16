import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import '../../core/theme.dart';

/// The tool the user is currently using in the isolator.
enum IsolatorTool { erase, restore }

/// Data class to pass to the compute isolate for final export.
class _ExportPayload {
  final Uint8List originalBytes;
  final Uint8List alphaMask;
  final int width;
  final int height;
  final int featherRadius;

  _ExportPayload({
    required this.originalBytes,
    required this.alphaMask,
    required this.width,
    required this.height,
    required this.featherRadius,
  });
}

class ItemIsolatorScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ItemIsolatorScreen({super.key, required this.imageBytes});

  @override
  State<ItemIsolatorScreen> createState() => _ItemIsolatorScreenState();
}

class _ItemIsolatorScreenState extends State<ItemIsolatorScreen> {
  // Original image data
  ui.Image? _uiImage;
  img.Image? _decodedImage; // For pixel-level operations
  int _imageWidth = 0;
  int _imageHeight = 0;

  // Alpha mask buffer: 255 = opaque (keep), 0 = transparent (erased)
  late Uint8List _alphaMask;

  // Tool state
  IsolatorTool _currentTool = IsolatorTool.erase;
  double _brushSize = 30.0;
  bool _isProcessing = false;

  // Undo/Redo stacks (store mask snapshots)
  final List<Uint8List> _undoStack = [];
  final List<Uint8List> _redoStack = [];
  static const int _maxUndoSteps = 20;

  // Rendering
  ui.Image? _displayImage; // Composited image for display

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Decode for UI display
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frameInfo = await codec.getNextFrame();

    // Decode for pixel operations
    final decoded = img.decodeImage(widget.imageBytes);

    if (decoded != null) {
      setState(() {
        _uiImage = frameInfo.image;
        _decodedImage = decoded;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        // Initialize mask: all opaque (255 = keep everything)
        _alphaMask = Uint8List(_imageWidth * _imageHeight);
        for (int i = 0; i < _alphaMask.length; i++) {
          _alphaMask[i] = 255;
        }
      });
      _rebuildDisplay();
    }
  }

  /// Rebuild the composited display image from original + alpha mask.
  Future<void> _rebuildDisplay() async {
    if (_decodedImage == null) return;

    final composited = img.Image(
      width: _imageWidth,
      height: _imageHeight,
      numChannels: 4,
    );

    for (int y = 0; y < _imageHeight; y++) {
      for (int x = 0; x < _imageWidth; x++) {
        final pixel = _decodedImage!.getPixel(x, y);
        final alpha = _alphaMask[y * _imageWidth + x];
        composited.setPixelRgba(
          x, y,
          pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), alpha,
        );
      }
    }

    final pngBytes = img.encodePng(composited);
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
    final frame = await codec.getNextFrame();

    if (mounted) {
      setState(() {
        _displayImage = frame.image;
      });
    }
  }

  /// Save a snapshot to the undo stack before making changes.
  void _saveUndoSnapshot() {
    _undoStack.add(Uint8List.fromList(_alphaMask));
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear(); // New action invalidates redo history
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(Uint8List.fromList(_alphaMask));
    _alphaMask = _undoStack.removeLast();
    _rebuildDisplay();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(Uint8List.fromList(_alphaMask));
    _alphaMask = _redoStack.removeLast();
    _rebuildDisplay();
  }

  /// Apply brush stroke at a given position in image coordinates.
  void _applyBrush(Offset imagePos) {
    final cx = imagePos.dx.round();
    final cy = imagePos.dy.round();
    final radius = (_brushSize / 2).round();

    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > radius * radius) continue; // Circle shape
        final px = cx + dx;
        final py = cy + dy;
        if (px < 0 || px >= _imageWidth || py < 0 || py >= _imageHeight) continue;

        // Soft edge: distance-based falloff for more natural erasing
        final dist = (dx * dx + dy * dy).toDouble();
        final maxDist = (radius * radius).toDouble();
        final falloff = 1.0 - (dist / maxDist).clamp(0.0, 1.0);

        final idx = py * _imageWidth + px;
        if (_currentTool == IsolatorTool.erase) {
          // Erase: reduce alpha based on brush pressure (falloff)
          final newAlpha = (_alphaMask[idx] * (1.0 - falloff)).round().clamp(0, 255);
          _alphaMask[idx] = newAlpha;
        } else {
          // Restore: increase alpha based on brush pressure
          final newAlpha = (_alphaMask[idx] + (255 * falloff).round()).clamp(0, 255);
          _alphaMask[idx] = newAlpha;
        }
      }
    }
  }

  /// Convert widget-space coordinates to image-space coordinates.
  Offset _widgetToImage(Offset widgetPos, Size widgetSize) {
    if (_imageWidth == 0 || _imageHeight == 0) return Offset.zero;

    final imageAspect = _imageWidth / _imageHeight;
    final widgetAspect = widgetSize.width / widgetSize.height;

    double drawW, drawH, offsetX, offsetY;
    if (imageAspect > widgetAspect) {
      drawW = widgetSize.width;
      drawH = widgetSize.width / imageAspect;
      offsetX = 0;
      offsetY = (widgetSize.height - drawH) / 2;
    } else {
      drawH = widgetSize.height;
      drawW = widgetSize.height * imageAspect;
      offsetX = (widgetSize.width - drawW) / 2;
      offsetY = 0;
    }

    final x = ((widgetPos.dx - offsetX) / drawW * _imageWidth);
    final y = ((widgetPos.dy - offsetY) / drawH * _imageHeight);
    return Offset(x, y);
  }

  bool _isPanActive = false;

  void _onPanStart(DragStartDetails details, Size size) {
    _saveUndoSnapshot();
    _isPanActive = true;
    final imagePos = _widgetToImage(details.localPosition, size);
    _applyBrush(imagePos);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (!_isPanActive) return;
    final imagePos = _widgetToImage(details.localPosition, size);
    _applyBrush(imagePos);
    // Throttle rebuild to every few updates for performance
    _rebuildDisplay();
  }

  void _onPanEnd(DragEndDetails details) {
    _isPanActive = false;
    _rebuildDisplay();
  }

  /// Export the final isolated image with edge feathering.
  Future<void> _saveAndReturn() async {
    setState(() => _isProcessing = true);

    try {
      final payload = _ExportPayload(
        originalBytes: widget.imageBytes,
        alphaMask: Uint8List.fromList(_alphaMask),
        width: _imageWidth,
        height: _imageHeight,
        featherRadius: 3,
      );

      final result = await compute(_exportWithFeathering, payload);

      if (mounted && result != null) {
        Navigator.pop(context, result);
      } else if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export image.')),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Runs in an isolate: applies Gaussian feathering to the mask edges,
  /// then composites original image × feathered mask.
  static Uint8List? _exportWithFeathering(_ExportPayload payload) {
    try {
      final original = img.decodeImage(payload.originalBytes);
      if (original == null) return null;

      final w = payload.width;
      final h = payload.height;
      final mask = payload.alphaMask;
      final r = payload.featherRadius;

      // Gaussian blur on the alpha mask for edge feathering
      final feathered = Uint8List(w * h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          double sum = 0;
          double weight = 0;
          for (int ky = -r; ky <= r; ky++) {
            for (int kx = -r; kx <= r; kx++) {
              final nx = x + kx;
              final ny = y + ky;
              if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
              final d = (kx * kx + ky * ky).toDouble();
              final g = 1.0 / (1.0 + d); // Simple Gaussian-like weight
              sum += mask[ny * w + nx] * g;
              weight += g;
            }
          }
          feathered[y * w + x] = (sum / weight).round().clamp(0, 255);
        }
      }

      // Composite: original × feathered alpha
      final output = img.Image(width: w, height: h, numChannels: 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = original.getPixel(x, y);
          final alpha = feathered[y * w + x];
          output.setPixelRgba(x, y,
            pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), alpha,
          );
        }
      }

      return Uint8List.fromList(img.encodePng(output));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TryMaarTheme.background,
      appBar: AppBar(
        title: const Text('Isolate Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          TextButton(
            onPressed: _isProcessing || _displayImage == null ? null : _saveAndReturn,
            child: _isProcessing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: TryMaarTheme.primary),
                  )
                : const Text('Done',
                    style: TextStyle(
                      color: TryMaarTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
          ),
        ],
      ),
      body: _displayImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _currentTool == IsolatorTool.erase
                        ? 'Draw over the background to remove it. Pinch to zoom in for precision.'
                        : 'Draw over erased areas to restore them.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: TryMaarTheme.textSecondary, fontSize: 13),
                  ),
                ),

                // Canvas area
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize = _calculateCanvasSize(constraints);
                          return GestureDetector(
                            onPanStart: (d) => _onPanStart(d, canvasSize),
                            onPanUpdate: (d) => _onPanUpdate(d, canvasSize),
                            onPanEnd: _onPanEnd,
                            child: CustomPaint(
                              size: canvasSize,
                              painter: _IsolatorCanvasPainter(
                                displayImage: _displayImage!,
                                brushPosition: null, // Could add live cursor
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Tool bar
                _buildToolbar(context),
              ],
            ),
    );
  }

  Size _calculateCanvasSize(BoxConstraints constraints) {
    if (_imageWidth == 0 || _imageHeight == 0) return Size.zero;
    final imageAspect = _imageWidth / _imageHeight;
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;
    final widgetAspect = maxW / maxH;

    if (imageAspect > widgetAspect) {
      return Size(maxW, maxW / imageAspect);
    } else {
      return Size(maxH * imageAspect, maxH);
    }
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: TryMaarTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tool selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ToolButton(
                icon: Icons.auto_fix_high_rounded,
                label: 'Erase',
                isSelected: _currentTool == IsolatorTool.erase,
                color: Colors.redAccent,
                onTap: () => setState(() => _currentTool = IsolatorTool.erase),
              ),
              const SizedBox(width: 16),
              _ToolButton(
                icon: Icons.healing_rounded,
                label: 'Restore',
                isSelected: _currentTool == IsolatorTool.restore,
                color: Colors.greenAccent,
                onTap: () => setState(() => _currentTool = IsolatorTool.restore),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Brush size slider
          Row(
            children: [
              Icon(Icons.circle, size: 8,
                color: _currentTool == IsolatorTool.erase ? Colors.redAccent : Colors.greenAccent),
              Expanded(
                child: Slider(
                  value: _brushSize,
                  min: 5,
                  max: 80,
                  activeColor: _currentTool == IsolatorTool.erase
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  onChanged: (val) => setState(() => _brushSize = val),
                ),
              ),
              Icon(Icons.circle, size: 28,
                color: _currentTool == IsolatorTool.erase ? Colors.redAccent : Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tool Button Widget ───

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : TryMaarTheme.surfaceOverlay,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : TryMaarTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : TryMaarTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Canvas Painter with Checkerboard Background ───

class _IsolatorCanvasPainter extends CustomPainter {
  final ui.Image displayImage;
  final Offset? brushPosition;

  _IsolatorCanvasPainter({
    required this.displayImage,
    this.brushPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw checkerboard pattern (shows transparency)
    _drawCheckerboard(canvas, size);

    // 2. Draw the composited image on top
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: displayImage,
      fit: BoxFit.contain,
    );
  }

  void _drawCheckerboard(Canvas canvas, Size size) {
    const cellSize = 12.0;
    final lightPaint = Paint()..color = const Color(0xFF3A3A3A);
    final darkPaint = Paint()..color = const Color(0xFF2A2A2A);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isLight = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isLight ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsolatorCanvasPainter oldDelegate) {
    return oldDelegate.displayImage != displayImage;
  }
}
