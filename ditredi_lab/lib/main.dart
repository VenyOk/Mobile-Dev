import 'package:flutter/material.dart';
import 'package:ditredi/ditredi.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gradient Descent 3D',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        sliderTheme: const SliderThemeData(
          thumbColor: Colors.deepPurple,
          activeTrackColor: Colors.deepPurple,
          inactiveTrackColor: Colors.deepPurpleAccent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ),
      home: const GradientDescentApp(),
    );
  }
}

class GradientDescentApp extends StatefulWidget {
  const GradientDescentApp({super.key});

  @override
  State<GradientDescentApp> createState() => _GradientDescentAppState();
}

class _GradientDescentAppState extends State<GradientDescentApp> {
  final double a1 = -500.0, b1 = 500.0, a2 = -500.0, b2 = 500.0;
  double h = 20.0;
  List<Point3D> points = [];
  List<Point3D> path = [];
  List<Point3D> xyProjection = [];
  Vector3? startPoint;
  bool isDescending = false;
  final modelController = DiTreDiController();

  @override
  void initState() {
    super.initState();
    generateSurface();
  }

  double function(double x, double y) {
    return 418.9829 * 2 - (x * sin(sqrt(x.abs())) + y * sin(sqrt(y.abs())));
  }

  void generateSurface() {
    points.clear();
    for (double x = a1; x <= b1; x += h) {
      for (double y = a2; y <= b2; y += h) {
        points.add(Point3D(
          Vector3(x, y, function(x, y)),
          color: Colors.grey.shade400,
          width: 2.0,
        ));
      }
    }
  }

  void findMinimum(Vector3 start) {
    setState(() {
      path = [Point3D(Vector3(start.x, start.y, function(start.x, start.y)), color: Colors.blue, width: 8.0)];
      xyProjection = [Point3D(Vector3(start.x, start.y, 0), color: Colors.blue.withAlpha(128), width: 6.0)];
      isDescending = true;
    });

    Future<void> step() async {
      while (true) {
        final current = path.last.position;
        final neighbors = [
          Vector3(current.x + h, current.y, function(current.x + h, current.y)),
          Vector3(current.x - h, current.y, function(current.x - h, current.y)),
          Vector3(current.x, current.y + h, function(current.x, current.y + h)),
          Vector3(current.x, current.y - h, function(current.x, current.y - h)),
        ].where((p) => p.x >= a1 && p.x <= b1 && p.y >= a2 && p.y <= b2).toList();

        final currentValue = function(current.x, current.y);
        Vector3? nextPoint;
        double minValue = currentValue;

        for (var neighbor in neighbors) {
          final value = function(neighbor.x, neighbor.y);
          if (value < minValue) {
            minValue = value;
            nextPoint = neighbor;
          }
        }

        if (nextPoint == null) {
          setState(() {
            path.last = Point3D(Vector3(current.x, current.y, current.z), color: Colors.green, width: 8.0);
            xyProjection.last = Point3D(Vector3(current.x, current.y, 0), color: Colors.green.withAlpha(128), width: 6.0);
            isDescending = false;
          });
          break;
        }

        setState(() {
          path.add(Point3D(Vector3(nextPoint!.x, nextPoint.y, function(nextPoint.x, nextPoint.y)), color: Colors.red, width: 8.0));
          xyProjection.add(Point3D(Vector3(nextPoint.x, nextPoint.y, 0), color: Colors.red.withAlpha(128), width: 6.0));
        });

        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    step();
  }

  void updateStepSize(double newValue) {
    setState(() {
      h = newValue;
      generateSurface();
      path.clear();
      xyProjection.clear();
      isDescending = false;
    });
  }

  List<Line3D> get axes {
    return [
      Line3D(Vector3(a1, 0, 0), Vector3(b1, 0, 0), color: Colors.orange, width: 3),
      Line3D(Vector3(0, a2, 0), Vector3(0, b2, 0), color: Colors.teal, width: 3),
      Line3D(Vector3(0, 0, 0), Vector3(0, 0, function(b1, b2)), color: Colors.purpleAccent, width: 3),
    ];
  }

  List<Line3D> get grid {
    List<Line3D> gridLines = [];

    for (double y = a2; y <= b2; y += 0.5) {
      gridLines.add(Line3D(
        Vector3(a1, y, 0),
        Vector3(b1, y, 0),
        color: Colors.grey.withAlpha(60),
        width: 1,
      ));
    }

    for (double x = a1; x <= b1; x += 0.5) {
      gridLines.add(Line3D(
        Vector3(x, a2, 0),
        Vector3(x, b2, 0),
        color: Colors.grey.withAlpha(60),
        width: 1,
      ));
    }

    return gridLines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рк 1_2'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8F9FA), Color(0xFFEAEAEA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: DiTreDiDraggable(
                controller: modelController,
                child: DiTreDi(
                  figures: [
                    ...axes,
                    ...grid,
                    ...points,
                    ...path,
                    ...xyProjection,
                  ],
                  controller: modelController,
                  config: const DiTreDiConfig(supportZIndex: false),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Шаг (h):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: h,
                        min: 1.0,
                        max: 50.0,
                        divisions: 49,
                        label: h.toStringAsFixed(1),
                        onChanged: updateStepSize,
                      ),
                    ),
                    Text(h.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Координата X',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            final x = double.tryParse(value) ?? 0.0;
                            setState(() {
                              startPoint = Vector3(x, startPoint?.y ?? 0.0, function(x, startPoint?.y ?? 0.0));
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Координата Y',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            final y = double.tryParse(value) ?? 0.0;
                            setState(() {
                              startPoint = Vector3(startPoint?.x ?? 0.0, y, function(startPoint?.x ?? 0.0, y));
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: startPoint != null && !isDescending ? () => findMinimum(startPoint!) : null,
                      child: const Text('Старт'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
