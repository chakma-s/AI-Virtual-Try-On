import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import '../../core/theme.dart';

enum IsolatorTool { magicWand, erase, restore, zoom }

class ItemIsolatorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const ItemIsolatorScreen({super.key, required this.imageBytes});
  @override
  State<ItemIsolatorScreen> createState() => _ItemIsolatorScreenState();
}

class _ItemIsolatorScreenState extends State<ItemIsolatorScreen> {
  img.Image? _editImage;
  int _editW = 0, _editH = 0, _origW = 0, _origH = 0;
  late Uint8List _alphaMask;
  ui.Image? _displayImage;

  IsolatorTool _currentTool = IsolatorTool.magicWand;
  double _brushSize = 35.0;
  int _wandTolerance = 30;
  bool _isProcessing = false;
  bool _rebuildScheduled = false;

  final List<Uint8List> _undoStack = [];
  final List<Uint8List> _redoStack = [];

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) return;
    _origW = decoded.width;
    _origH = decoded.height;

    const maxEdit = 640; // Slightly larger for better precision
    final scale = (_origW > _origH ? _origW : _origH) > maxEdit
        ? maxEdit / (_origW > _origH ? _origW : _origH) : 1.0;
    
    _editImage = img.copyResize(decoded,
        width: (_origW * scale).round(), height: (_origH * scale).round(),
        interpolation: img.Interpolation.linear);
    _editW = _editImage!.width;
    _editH = _editImage!.height;

    _alphaMask = Uint8List(_editW * _editH);
    for (int i = 0; i < _alphaMask.length; i++) _alphaMask[i] = 255;
    
    await _rebuildDisplay();
  }

  Future<void> _rebuildDisplay() async {
    if (_editImage == null) return;
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
    Future.delayed(const Duration(milliseconds: 32), () { // ~30fps
      _rebuildScheduled = false;
      _rebuildDisplay();
    });
  }

  void _saveUndo() {
    _undoStack.add(Uint8List.fromList(_alphaMask));
    if (_undoStack.length > 20) _undoStack.removeAt(0);
    _redoStack.clear();
  }
  void _undo() { if (_undoStack.isEmpty) return; _redoStack.add(Uint8List.fromList(_alphaMask)); _alphaMask = _undoStack.removeLast(); _rebuildDisplay(); }
  void _redo() { if (_redoStack.isEmpty) return; _undoStack.add(Uint8List.fromList(_alphaMask)); _alphaMask = _redoStack.removeLast(); _rebuildDisplay(); }

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
        
        // Use a much harder falloff for better "feel"
        final distRatio = d2 / (r * r);
        final falloff = distRatio < 0.7 ? 1.0 : (1.0 - (distRatio - 0.7) / 0.3);
        
        final idx = py * _editW + px;
        if (isErase) {
          _alphaMask[idx] = (_alphaMask[idx] * (1.0 - falloff)).round().clamp(0, 255);
        } else {
          _alphaMask[idx] = (_alphaMask[idx] + (255 * falloff).round()).clamp(0, 255);
        }
      }
    }
  }

  void _applyMagicWand(Offset imgPos) {
    if (_editImage == null) return;
    final cx = imgPos.dx.round().clamp(0, _editW - 1);
    final cy = imgPos.dy.round().clamp(0, _editH - 1);
    final seedPixel = _editImage!.getPixel(cx, cy);
    final sr = seedPixel.r.toInt(), sg = seedPixel.g.toInt(), sb = seedPixel.b.toInt();
    final tol = _wandTolerance * _wandTolerance * 3; // Square distance

    final visited = List<bool>.filled(_editW * _editH, false);
    final stack = <int>[cy * _editW + cx];

    while (stack.isNotEmpty) {
      final idx = stack.removeLast();
      if (idx < 0 || idx >= _editW * _editH || visited[idx]) continue;
      visited[idx] = true;

      final x = idx % _editW, y = idx ~/ _editW;
      final p = _editImage!.getPixel(x, y);
      final dr = p.r.toInt() - sr, dg = p.g.toInt() - sg, db = p.b.toInt() - sb;
      if (dr * dr + dg * dg + db * db > tol) continue;

      _alphaMask[idx] = 0; // Magic Wand currently always erases

      if (x > 0) stack.add(idx - 1);
      if (x < _editW - 1) stack.add(idx + 1);
      if (y > 0) stack.add(idx - _editW);
      if (y < _editH - 1) stack.add(idx + _editW);
    }
  }

  Offset _toImageCoords(Offset wPos, Size wSize) {
    // Account for InteractiveViewer transformation
    final matrix = _transformationController.value;
    final inverted = Matrix4.inverted(matrix);
    final transformedPos = MatrixUtils.transformPoint(inverted, wPos);

    final imgAsp = _editW / _editH;
    final wAsp = wSize.width / wSize.height;
    double dw, dh, ox, oy;
    if (imgAsp > wAsp) { dw = wSize.width; dh = dw / imgAsp; ox = 0; oy = (wSize.height - dh) / 2; }
    else { dh = wSize.height; dw = dh * imgAsp; ox = (wSize.width - dw) / 2; oy = 0; }
    
    return Offset((transformedPos.dx - ox) / dw * _editW, (transformedPos.dy - oy) / dh * _editH);
  }

  void _handleGesture(Offset localPos, Size sz, bool isStart) {
    if (_currentTool == IsolatorTool.zoom) return;
    if (isStart) _saveUndo();
    final imgPos = _toImageCoords(localPos, sz);
    if (_currentTool == IsolatorTool.magicWand) {
      if (isStart) { _applyMagicWand(imgPos); _rebuildDisplay(); }
    } else {
      _applyBrush(imgPos);
      if (isStart) _rebuildDisplay(); else _scheduleRebuild();
    }
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isProcessing = true);
    try {
      final result = await compute(_exportIsolated, _ExportPayload(
        widget.imageBytes, Uint8List.fromList(_alphaMask), _editW, _editH, _origW, _origH,
      ));
      if (mounted && result != null) { Navigator.pop(context, result); return; }
    } catch (e) { debugPrint('Export error: $e'); }
    if (mounted) setState(() => _isProcessing = false);
  }

  static Uint8List? _exportIsolated(_ExportPayload p) {
    try {
      final orig = img.decodeImage(p.originalBytes);
      if (orig == null) return null;
      final out = img.Image(width: p.origW, height: p.origH, numChannels: 4);
      final sx = p.maskW / p.origW, sy = p.maskH / p.origH;
      final mask = Uint8List(p.origW * p.origH);
      for (int y = 0; y < p.origH; y++)
        for (int x = 0; x < p.origW; x++)
          mask[y * p.origW + x] = p.alphaMask[(y * sy).floor().clamp(0, p.maskH - 1) * p.maskW + (x * sx).floor().clamp(0, p.maskW - 1)];
      final feathered = _blur(mask, p.origW, p.origH, 4);
      for (int y = 0; y < p.origH; y++)
        for (int x = 0; x < p.origW; x++) {
          final px = orig.getPixel(x, y);
          out.setPixelRgba(x, y, px.r.toInt(), px.g.toInt(), px.b.toInt(), feathered[y * p.origW + x]);
        }
      return Uint8List.fromList(img.encodePng(out));
    } catch (e) { return null; }
  }

  static Uint8List _blur(Uint8List m, int w, int h, int r) {
    final out = Uint8List(w * h);
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++) {
        double s = 0, wt = 0;
        for (int ky = -r; ky <= r; ky++)
          for (int kx = -r; kx <= r; kx++) {
            final nx = x + kx, ny = y + ky;
            if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
            final d = (kx * kx + ky * ky).toDouble();
            final g = 1.0 / (1.0 + d * 0.4); s += m[ny * w + nx] * g; wt += g;
          }
        out[y * w + x] = (s / wt).round().clamp(0, 255);
      }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TryMaarTheme.background,
      appBar: AppBar(
        title: const Text('Refine Sticker'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.undo_rounded), onPressed: _undoStack.isNotEmpty ? _undo : null),
          IconButton(icon: const Icon(Icons.redo_rounded), onPressed: _redoStack.isNotEmpty ? _redo : null),
          const SizedBox(width: 8),
        ],
      ),
      body: _displayImage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildTopInstruction(),
              Expanded(child: LayoutBuilder(builder: (ctx, c) {
                final sz = _canvasSize(c);
                return InteractiveViewer(
                  transformationController: _transformationController,
                  panEnabled: _currentTool == IsolatorTool.zoom,
                  scaleEnabled: _currentTool == IsolatorTool.zoom,
                  minScale: 1.0, maxScale: 8.0,
                  child: Center(child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _handleGesture(d.localPosition, sz, true),
                    onPanUpdate: (d) => _handleGesture(d.localPosition, sz, false),
                    onPanEnd: (_) => _rebuildDisplay(),
                    child: CustomPaint(size: sz, painter: _Painter(displayImage: _displayImage!)),
                  )),
                );
              })),
              _buildBottomControls(),
            ]),
    );
  }

  Widget _buildTopInstruction() {
    String text = '';
    switch (_currentTool) {
      case IsolatorTool.magicWand: text = 'Tap background parts to remove them automatically.'; break;
      case IsolatorTool.erase: text = 'Draw to erase manually. Precise edges.'; break;
      case IsolatorTool.restore: text = 'Draw to bring back erased parts.'; break;
      case IsolatorTool.zoom: text = 'Pinch to zoom and pan around.'; break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: TryMaarTheme.textSecondary, fontSize: 13, height: 1.4)),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: TryMaarTheme.surface, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _ToolBtn(icon: Icons.auto_fix_high_rounded, label: 'Magic', sel: _currentTool == IsolatorTool.magicWand, color: Colors.cyanAccent, onTap: () => setState(() => _currentTool = IsolatorTool.magicWand)),
          _ToolBtn(icon: Icons.brush_rounded, label: 'Erase', sel: _currentTool == IsolatorTool.erase, color: Colors.redAccent, onTap: () => setState(() => _currentTool = IsolatorTool.erase)),
          _ToolBtn(icon: Icons.healing_rounded, label: 'Restore', sel: _currentTool == IsolatorTool.restore, color: Colors.greenAccent, onTap: () => setState(() => _currentTool = IsolatorTool.restore)),
          _ToolBtn(icon: Icons.zoom_in_rounded, label: 'Zoom', sel: _currentTool == IsolatorTool.zoom, color: TryMaarTheme.primary, onTap: () => setState(() => _currentTool = IsolatorTool.zoom)),
        ]),
        const SizedBox(height: 16),
        if (_currentTool == IsolatorTool.magicWand)
          _buildSlider('Sensitivity', _wandTolerance.toDouble(), 10, 80, Colors.cyanAccent, (v) => setState(() => _wandTolerance = v.round()))
        else if (_currentTool != IsolatorTool.zoom)
          _buildSlider('Size', _brushSize, 5, 100, _currentTool == IsolatorTool.erase ? Colors.redAccent : Colors.greenAccent, (v) => setState(() => _brushSize = v)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
          onPressed: _isProcessing || _displayImage == null ? null : _saveAndReturn,
          style: ElevatedButton.styleFrom(backgroundColor: TryMaarTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text('Extract Sticker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )),
      ]),
    );
  }

  Widget _buildSlider(String label, double val, double min, double max, Color color, ValueChanged<double> onChanged) {
    return Row(children: [
      Text(label, style: const TextStyle(color: TryMaarTheme.textSecondary, fontSize: 12)),
      Expanded(child: Slider(value: val, min: min, max: max, activeColor: color, inactiveColor: color.withValues(alpha: 0.1), onChanged: onChanged)),
      SizedBox(width: 25, child: Text('${val.round()}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
    ]);
  }

  Size _canvasSize(BoxConstraints c) {
    if (_editW == 0 || _editH == 0) return Size.zero;
    final a = _editW / _editH;
    return a > c.maxWidth / c.maxHeight ? Size(c.maxWidth, c.maxWidth / a) : Size(c.maxHeight * a, c.maxHeight);
  }
}

class _ExportPayload {
  final Uint8List originalBytes, alphaMask;
  final int maskW, maskH, origW, origH;
  _ExportPayload(this.originalBytes, this.alphaMask, this.maskW, this.maskH, this.origW, this.origH);
}

class _ToolBtn extends StatelessWidget {
  final IconData icon; final String label; final bool sel; final Color color; final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.label, required this.sel, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: sel ? color.withValues(alpha: 0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: sel ? color : Colors.transparent, width: 1.5),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: sel ? color : TryMaarTheme.textSecondary, size: 22),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: sel ? color : TryMaarTheme.textSecondary, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
    ]),
  ));
}

class _Painter extends CustomPainter {
  final ui.Image displayImage;
  _Painter({required this.displayImage});
  @override
  void paint(Canvas canvas, Size size) {
    const cs = 14.0;
    final l = Paint()..color = const Color(0xFF2A3540); // Matches theme charcoal light
    final d = Paint()..color = const Color(0xFF1D252A); // Matches theme charcoal deep
    for (double y = 0; y < size.height; y += cs)
      for (double x = 0; x < size.width; x += cs)
        canvas.drawRect(Rect.fromLTWH(x, y, cs, cs), ((x ~/ cs) + (y ~/ cs)) % 2 == 0 ? l : d);
    paintImage(canvas: canvas, rect: Rect.fromLTWH(0, 0, size.width, size.height), image: displayImage, filterQuality: FilterQuality.medium);
  }
  @override
  bool shouldRepaint(covariant _Painter old) => old.displayImage != displayImage;
}
