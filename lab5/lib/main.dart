import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const IsoBoxApp());

class IsoBoxApp extends StatelessWidget {
  const IsoBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Параллелепипед',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const IsoBoxScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IsoBoxScreen extends StatefulWidget {
  const IsoBoxScreen({super.key});

  @override
  State<IsoBoxScreen> createState() => _IsoBoxScreenState();
}

class _IsoBoxScreenState extends State<IsoBoxScreen> {
  static const double minLen = 10;
  static const double maxLen = 200;

  double a = 120;
  double b = 80;
  double c = 100;
  bool showHidden = true;

  @override
  Widget build(BuildContext context) {
    final inputs = Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _lenSlider(
              label: 'a',
              value: a,
              onChanged: (v) => setState(() => a = v),
            ),
            _lenSlider(
              label: 'b',
              value: b,
              onChanged: (v) => setState(() => b = v),
            ),
            _lenSlider(
              label: 'c',
              value: c,
              onChanged: (v) => setState(() => c = v),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                FilterChip(
                  label: const Text('Показывать невидимые линии'),
                  selected: showHidden,
                  onSelected: (v) => setState(() => showHidden = v),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    a = 120; b = 80; c = 100; showHidden = true;
                  }),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Сброс'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Параллелепипед (изометрия)')),
      body: Column(
        children: [
          inputs,
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.2,
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CustomPaint(
                      painter: IsoParallelepipedPainter(
                        a,
                        b,
                        c,
                        showHidden: showHidden,
                      ),
                      willChange: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lenSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(value.toStringAsFixed(0)),
            const Spacer(),
            Text('${minLen.toStringAsFixed(0)} – ${maxLen.toStringAsFixed(0)}'),
          ],
        ),
        Slider.adaptive(
          value: value.clamp(minLen, maxLen),
          min: minLen,
          max: maxLen,
          divisions: (maxLen - minLen).toInt(),
          label: value.toStringAsFixed(0),
          onChanged: onChanged, // мгновенная перерисовка через setState
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Рисует прямоугольный параллелепипед (стороны a,b,c) в изометрии.
/// Оси X и Y под 120°, ось Z — вертикально вниз на экране.
/// Проекция:
///   sx = (x - y) * cos30
///   sy = (x + y) * sin30 - z
class IsoParallelepipedPainter extends CustomPainter {
  final double a, b, c;
  final bool showHidden;

  IsoParallelepipedPainter(this.a, this.b, this.c, {required this.showHidden});

  static const double _cos30 = 0.8660254037844386; // √3/2
  static const double _sin30 = 0.5;

  late final Map<String, Offset> _p2d = {};

  Offset _iso(double x, double y, double z) {
    final sx = (x - y) * _cos30;
    final sy = (x + y) * _sin30 - z;
    return Offset(sx, sy);
  }

  List<(String, String)> get _edges => const [
        ('000', '100'),
        ('010', '110'),
        ('001', '101'),
        ('011', '111'),
        ('000', '010'),
        ('100', '110'),
        ('001', '011'),
        ('101', '111'),
        ('000', '001'),
        ('100', '101'),
        ('010', '011'),
        ('110', '111'),
      ];

  Set<(String, String)> get _visibleEdges {
    final s = <(String, String)>{};

    void addFaceEdges(List<String> vs) {
      final e = <(String, String)>[
        (vs[0], vs[1]),
        (vs[1], vs[3]),
        (vs[3], vs[2]),
        (vs[2], vs[0]),
      ];
      for (final edge in e) {
        final sorted = _sortEdge(edge);
        s.add(sorted);
      }
    }

    addFaceEdges(['000', '100', '001', '101']); // y = 0
    addFaceEdges(['100', '110', '101', '111']); // x = a
    addFaceEdges(['001', '101', '011', '111']); // z = c

    return s;
  }

  (String, String) _sortEdge((String, String) e) {
    final a = e.$1;
    final b = e.$2;
    return (a.compareTo(b) <= 0) ? (a, b) : (b, a);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (a <= 0 || b <= 0 || c <= 0) {
      _drawCenteredText(canvas, size, 'Длины должны быть > 0');
      return;
    }

    const margin = 24.0;
    final w = size.width - 2 * margin;
    final h = size.height - 2 * margin;

    final pts = <Offset>[
      _iso(0, 0, 0),
      _iso(a, 0, 0),
      _iso(0, b, 0),
      _iso(a, b, 0),
      _iso(0, 0, c),
      _iso(a, 0, c),
      _iso(0, b, c),
      _iso(a, b, c),
    ];

    Rect bounds = _pointsBounds(pts);
    final sx = w / bounds.width;
    final sy = h / bounds.height;
    final scale = 0.9 * math.min(sx, sy);

    final center = Offset(size.width / 2, size.height / 2);
    final geoCenter = Offset(bounds.left + bounds.width / 2, bounds.top + bounds.height / 2);

    void put(String key, double x, double y, double z) {
      final p = _iso(x, y, z);
      final q = (p - geoCenter) * scale + center;
      _p2d[key] = q;
    }

    put('000', 0, 0, 0);
    put('100', a, 0, 0);
    put('010', 0, b, 0);
    put('110', a, b, 0);
    put('001', 0, 0, c);
    put('101', a, 0, c);
    put('011', 0, b, c);
    put('111', a, b, c);

    final paintSolid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black;

    final paintHidden = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.grey;

    final visible = _visibleEdges;
    final all = _edges.map(_sortEdge).toSet();
    final hidden = all.difference(visible);

    if (showHidden) {
      for (final e in hidden) {
        final p1 = _p2d[e.$1]!;
        final p2 = _p2d[e.$2]!;
        _drawDashedLine(canvas, p1, p2, paintHidden, dash: 8, gap: 6);
      }
    }

    for (final e in visible) {
      final p1 = _p2d[e.$1]!;
      final p2 = _p2d[e.$2]!;
      canvas.drawLine(p1, p2, paintSolid);
    }
  }

  @override
  bool shouldRepaint(covariant IsoParallelepipedPainter old) {
    return a != old.a || b != old.b || c != old.c || showHidden != old.showHidden;
  }

  Rect _pointsBounds(List<Offset> pts) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 6, double gap = 4}) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double t = 0;
    while (t < total) {
      final tNext = math.min(t + dash, total);
      final p1 = a + dir * t;
      final p2 = a + dir * tNext;
      canvas.drawLine(p1, p2, paint);
      t = tNext + gap;
    }
  }

  void _drawCenteredText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    final pos = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );
    tp.paint(canvas, pos);
  }
}
