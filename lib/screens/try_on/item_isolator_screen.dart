import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import '../../core/theme.dart';

enum IsolatorTool { erase, restore }

class _ExportPayload {
  final Uint8List originalBytes;
  final Uint8List alphaMask;
  final int maskW, maskH, origW, origH;
  _ExportPayload(this.originalBytes, this.alphaMask, this.maskW, this.maskH, this.origW, this.origH);
}

class ItemIsolatorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const ItemIsolatorScreen({super.key, required this.imageBytes});
  @override
  State<ItemIsolatorScreen> createState() => _ItemIsolatorScreenState();
}

class _ItemIsolatorScreenState extends State<ItemIsolatorScreen> {
  ui.Image? _originalUiImage;
  img.Image? _originalDecoded;
  int _origW = 0, _origH = 0;

  // Downscaled editing versions (max 512px wide for performance)
  img.Image? _editImage;
  int _editW = 0, _editH = 0;
  late Uint8List _alphaMask;
  ui.Image? _displayImage;

  IsolatorTool _currentTool = IsolatorTool.erase;
  double _brushSize = 30.0;
  bool _isProcessing = false;

  final List<Uint8List> _undoStack = [];
  final List<Uint8List> _redoStack = [];

  // Throttle rebuilds
  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) return;

    _origW = decoded.width;
    _origH = decoded.height;
    _originalUiImage = frame.image;
    _originalDecoded = decoded;

    // Downscale for editing (max 512px on longest side)
    const maxEdit = 512;
    if (_origW > maxEdit || _origH > maxEdit) {
      final scale = maxEdit / (_origW > _origH ? _origW : _origH);
      _editImage = img.copyResize(decoded,
          width: (_origW * scale).round(),
          height: (_origH * scale).round(),
          interpolation: img.Interpolation.linear);
    } else {
      _editImage = img.copyResize(decoded, width: _origW, height: _origH);
    }
    _editW = _editImage!.width;
    _editH = _editImage!.height;

    _alphaMask = Uint8List(_editW * _editH);
    for (int i = 0; i < _alphaMask.length; i++) _alphaMask[i] = 255;

    await _rebuildDisplay();
  }

  Future<void> _rebuildDisplay() async {
    if (_editImage == null) return;

    // Build RGBA directly — skip PNG encode/decode
    final rgba = Uint8List(_editW * _editH * 4);
    for (int i = 0; i < _editW * _editH; i++) {
      final x = i % _editW, y = i ~/ _editW;
      final p = _editImage!.getPixel(x, y);
      final j = i * 4;
      rgba[j] = p.r.toInt();
      rgba[j + 1] = p.g.toInt();
      rgba[j + 2] = p.b.toInt();
      rgba[j + 3] = _alphaMask[i];
    }

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, _editW, _editH, ui.PixelFormat.rgba8888, c.complete);
    final image = await c.future;
    if (mounted) setState(() => _displayImage = image);
  }

  void _scheduleRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    Future.delayed(const Duration(milliseconds: 40), () {
      _rebuildScheduled = false;
      _rebuildDisplay();
    });
  }

  void _saveUndo() {
    _undoStack.add(Uint8List.fromList(_alphaMask));
    if (_undoStack.length > 20) _undoStack.removeAt(0);
    _redoStack.clear();
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

  void _applyBrush(Offset imgPos) {
    final cx = imgPos.dx.round(), cy = imgPos.dy.round();
    final r = (_brushSize / 2).round();
    final isErase = _currentTool == IsolatorTool.erase;

    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final d2 = dx * dx + dy * dy;
        if (d2 > r * r) continue;
        final px = cx + dx, py = cy + dy;
        if (px < 0 || px >= _editW || py < 0 || py >= _editH) continue;
        final falloff = 1.0 - (d2 / (r * r)).clamp(0.0, 1.0);
        final idx = py * _editW + px;
        if (isErase) {
          _alphaMask[idx] = (_alphaMask[idx] * (1.0 - falloff)).round().clamp(0, 255);
        } else {
          _alphaMask[idx] = (_alphaMask[idx] + (255 * falloff).round()).clamp(0, 255);
        }
      }
    }
  }

  Offset _toImageCoords(Offset widgetPos, Size widgetSize) {
    final imgAsp = _editW / _editH;
    final wAsp = widgetSize.width / widgetSize.height;
    double dw, dh, ox, oy;
    if (imgAsp > wAsp) {
      dw = widgetSize.width; dh = dw / imgAsp; ox = 0; oy = (widgetSize.height - dh) / 2;
    } else {
      dh = widgetSize.height; dw = dh * imgAsp; ox = (widgetSize.width - dw) / 2; oy = 0;
    }
    return Offset((widgetPos.dx - ox) / dw * _editW, (widgetPos.dy - oy) / dh * _editH);
  }

  void _onPanStart(DragStartDetails d, Size s) { _saveUndo(); _applyBrush(_toImageCoords(d.localPosition, s)); }
  void _onPanUpdate(DragUpdateDetails d, Size s) { _applyBrush(_toImageCoords(d.localPosition, s)); _scheduleRebuild(); }
  void _onPanEnd(DragEndDetails d) { _rebuildDisplay(); }

  Future<void> _saveAndReturn() async {
    setState(() => _isProcessing = true);
    try {
      final payload = _ExportPayload(widget.imageBytes, Uint8List.fromList(_alphaMask), _editW, _editH, _origW, _origH);
      final result = await compute(_exportIsolated, payload);
      if (mounted && result != null) { Navigator.pop(context, result); return; }
    } catch (e) { debugPrint('Export error: $e'); }
    if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed.'))); }
  }

  static Uint8List? _exportIsolated(_ExportPayload p) {
    try {
      final orig = img.decodeImage(p.originalBytes);
      if (orig == null) return null;
      // Upscale mask to original resolution
      final mask = Uint8List(p.origW * p.origH);
      final sx = p.maskW / p.origW, sy = p.maskH / p.origH;
      for (int y = 0; y < p.origH; y++) {
        for (int x = 0; x < p.origW; x++) {
          final mx = (x * sx).floor().clamp(0, p.maskW - 1);
          final my = (y * sy).floor().clamp(0, p.maskH - 1);
          mask[y * p.origW + x] = p.alphaMask[my * p.maskW + mx];
        }
      }
      // Feather edges (5px radius)
      final feathered = _blur(mask, p.origW, p.origH, 5);
      // Composite
      final out = img.Image(width: p.origW, height: p.origH, numChannels: 4);
      for (int y = 0; y < p.origH; y++) {
        for (int x = 0; x < p.origW; x++) {
          final px = orig.getPixel(x, y);
          out.setPixelRgba(x, y, px.r.toInt(), px.g.toInt(), px.b.toInt(), feathered[y * p.origW + x]);
        }
      }
      return Uint8List.fromList(img.encodePng(out));
    } catch (e) { return null; }
  }

  static Uint8List _blur(Uint8List m, int w, int h, int r) {
    final out = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double s = 0, wt = 0;
        for (int ky = -r; ky <= r; ky++) {
          for (int kx = -r; kx <= r; kx++) {
            final nx = x + kx, ny = y + ky;
            if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
            final d = (kx * kx + ky * ky).toDouble();
            final g = 1.0 / (1.0 + d * 0.5);
            s += m[ny * w + nx] * g; wt += g;
          }
        }
        out[y * w + x] = (s / wt).round().clamp(0, 255);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TryMaarTheme.background,
      appBar: AppBar(
        title: const Text('Isolate Item'),
        actions: [
          IconButton(icon: const Icon(Icons.undo_rounded), onPressed: _undoStack.isNotEmpty ? _undo : null),
          IconButton(icon: const Icon(Icons.redo_rounded), onPressed: _redoStack.isNotEmpty ? _redo : null),
          TextButton(
            onPressed: _isProcessing || _displayImage == null ? null : _saveAndReturn,
            child: _isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TryMaarTheme.primary))
                : const Text('Done', style: TextStyle(color: TryMaarTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _displayImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _currentTool == IsolatorTool.erase
                      ? 'Draw over the background to erase it. Pinch to zoom.'
                      : 'Draw to restore erased areas.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TryMaarTheme.textSecondary, fontSize: 13),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1.0, maxScale: 5.0,
                  child: Center(child: LayoutBuilder(builder: (ctx, c) {
                    final sz = _canvasSize(c);
                    return GestureDetector(
                      onPanStart: (d) => _onPanStart(d, sz),
                      onPanUpdate: (d) => _onPanUpdate(d, sz),
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(size: sz, painter: _Painter(displayImage: _displayImage!)),
                    );
                  })),
                ),
              ),
              _buildToolbar(),
            ]),
    );
  }

  Size _canvasSize(BoxConstraints c) {
    if (_editW == 0 || _editH == 0) return Size.zero;
    final a = _editW / _editH;
    return a > c.maxWidth / c.maxHeight
        ? Size(c.maxWidth, c.maxWidth / a)
        : Size(c.maxHeight * a, c.maxHeight);
  }

  Widget _buildToolbar() {
    final isErase = _currentTool == IsolatorTool.erase;
    final color = isErase ? Colors.redAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(color: TryMaarTheme.surface, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ToolBtn(icon: Icons.auto_fix_high_rounded, label: 'Erase', sel: isErase, color: Colors.redAccent, onTap: () => setState(() => _currentTool = IsolatorTool.erase)),
          const SizedBox(width: 16),
          _ToolBtn(icon: Icons.healing_rounded, label: 'Restore', sel: !isErase, color: Colors.greenAccent, onTap: () => setState(() => _currentTool = IsolatorTool.restore)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.circle, size: 8, color: color),
          Expanded(child: Slider(value: _brushSize, min: 5, max: 80, activeColor: color, onChanged: (v) => setState(() => _brushSize = v))),
          Icon(Icons.circle, size: 28, color: color),
        ]),
      ]),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon; final String label; final bool sel; final Color color; final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.label, required this.sel, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: sel ? color.withValues(alpha: 0.2) : TryMaarTheme.surfaceOverlay,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? color : Colors.white.withValues(alpha: 0.1), width: sel ? 2 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: sel ? color : TryMaarTheme.textSecondary, size: 20),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: sel ? color : TryMaarTheme.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ]),
    ));
  }
}

class _Painter extends CustomPainter {
  final ui.Image displayImage;
  _Painter({required this.displayImage});
  @override
  void paint(Canvas canvas, Size size) {
    // Checkerboard
    const cs = 12.0;
    final l = Paint()..color = const Color(0xFF3A3A3A);
    final d = Paint()..color = const Color(0xFF2A2A2A);
    for (double y = 0; y < size.height; y += cs) {
      for (double x = 0; x < size.width; x += cs) {
        canvas.drawRect(Rect.fromLTWH(x, y, cs, cs), ((x ~/ cs) + (y ~/ cs)) % 2 == 0 ? l : d);
      }
    }
    // Image
    paintImage(canvas: canvas, rect: Rect.fromLTWH(0, 0, size.width, size.height), image: displayImage, fit: BoxFit.contain);
  }
  @override
  bool shouldRepaint(covariant _Painter old) => old.displayImage != displayImage;
}
