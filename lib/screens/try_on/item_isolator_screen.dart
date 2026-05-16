import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme.dart';

class ItemIsolatorScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ItemIsolatorScreen({super.key, required this.imageBytes});

  @override
  State<ItemIsolatorScreen> createState() => _ItemIsolatorScreenState();
}

class _ItemIsolatorScreenState extends State<ItemIsolatorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _image;
  List<List<Offset>> _paths = [];
  List<Offset> _currentPath = [];
  double _strokeWidth = 30.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frameInfo = await codec.getNextFrame();
    setState(() {
      _image = frameInfo.image;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
      _paths.add(_currentPath);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _currentPath = [];
  }

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() {
        _paths.removeLast();
      });
    }
  }

  Future<void> _saveAndReturn() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // We must scale the capture to match original image resolution for better quality
      // Alternatively, capture at high pixel ratio.
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (mounted) {
        Navigator.pop(context, pngBytes);
      }
    } catch (e) {
      debugPrint('Error saving isolated item: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save the image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TryMaarTheme.background,
      appBar: AppBar(
        title: const Text('Erase Background'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
          ),
          TextButton(
            onPressed: _isProcessing || _image == null ? null : _saveAndReturn,
            child: const Text('Done', style: TextStyle(color: TryMaarTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _image == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Use your finger to erase the background around the item. This makes it transparent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TryMaarTheme.textSecondary),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          size: Size(
                            MediaQuery.of(context).size.width,
                            MediaQuery.of(context).size.width * (_image!.height / _image!.width),
                          ),
                          painter: _IsolatorPainter(
                            image: _image!,
                            paths: _paths,
                            strokeWidth: _strokeWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom controls for brush size
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: TryMaarTheme.surface,
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _strokeWidth,
                          min: 5,
                          max: 100,
                          activeColor: TryMaarTheme.primary,
                          onChanged: (val) => setState(() => _strokeWidth = val),
                        ),
                      ),
                      const Icon(Icons.circle, size: 30, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _IsolatorPainter extends CustomPainter {
  final ui.Image image;
  final List<List<Offset>> paths;
  final double strokeWidth;

  _IsolatorPainter({
    required this.image,
    required this.paths,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We need to use a saveLayer so BlendMode.clear works properly to make it transparent,
    // rather than just drawing the background color.
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Draw the image scaled to fit the size
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.contain,
    );

    // Draw the eraser paths
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..blendMode = BlendMode.clear;

    for (final path in paths) {
      if (path.isEmpty) continue;
      final p = Path()..moveTo(path.first.dx, path.first.dy);
      for (int i = 1; i < path.length; i++) {
        p.lineTo(path[i].dx, path[i].dy);
      }
      canvas.drawPath(p, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IsolatorPainter oldDelegate) {
    return true; // We repaint on every stroke update
  }
}
