import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  final _controller = DiTreDiController(
    rotationX: 0,
    rotationY: 0,
    light: v.Vector3(-0.5, -0.5, 0.5),
    maxUserScale: 10,
    minUserScale: 0.5,
    userScale: 1,
  );
  final double _contactBias = 2e-4;
  double leftHandX = -15.0;
  double rightHandX = 15.0;
  double leftRotDeg = 0.0;
  double rightRotDeg = 0.0;

  final double handsSepZ = 22;
  final double handsY = 40;

  final double ballSpeed = 9;
  v.Vector3 ballPos = v.Vector3.zero();
  v.Vector3 ballDir = v.Vector3.zero();
  bool running = false;

  final double paddleRadius = 7.5;
  final double ballRadius = 4.0;
  final double _eps = 1e-3;

  late final Future<List<Mesh3D>> _meshes;

  late final Ticker _ticker;
  late double _lastTickT;

  @override
  void initState() {
    super.initState();
    _meshes = _loadMeshes();
    ballPos = v.Vector3((leftHandX + rightHandX) * 0.5, handsY, 0);
    _lastTickT = 0;
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      final dt = max(0.0, min(1 / 90, t - _lastTickT));
      _lastTickT = t;
      if (running) _integrateBall(dt);
      setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<List<Mesh3D>> _loadMeshes() async {
    return [
      Mesh3D(await ObjParser().loadFromResources("assets/hand/hand.obj")),
      Mesh3D(await ObjParser().loadFromResources("assets/hand/index.obj")),
      Mesh3D(await ObjParser().loadFromResources("assets/hand/middle.obj")),
      Mesh3D(await ObjParser().loadFromResources("assets/hand/ring.obj")),
      Mesh3D(await ObjParser().loadFromResources("assets/hand/pinky.obj")),
      Mesh3D(await ObjParser().loadFromResources("assets/hand/ball.obj")),
    ];
  }

  v.Vector3 _leftCenter()  => v.Vector3(leftHandX,  handsY, -handsSepZ);
  v.Vector3 _rightCenter() => v.Vector3(rightHandX, handsY,  handsSepZ);

  v.Vector3 _unit(v.Vector3 a) {
    final b = v.Vector3(a.x, a.y, a.z);
    final len = b.length;
    if (len > 0) b.scale(1.0 / len);
    return b;
  }

  v.Vector3 _rotX(v.Vector3 v0, double a) {
    final c = cos(a), s = sin(a);
    return v.Vector3(v0.x, v0.y * c - v0.z * s, v0.y * s + v0.z * c);
  }

  v.Vector3 _rotZ(v.Vector3 v0, double a) {
    final c = cos(a), s = sin(a);
    return v.Vector3(v0.x * c - v0.y * s, v0.x * s + v0.y * c, v0.z);
  }

  v.Vector3 _palmNormal(double rotDeg) {
    final rot = rotDeg * pi / 180.0;
    v.Vector3 n = v.Vector3(0, 0, 1);
    n = _rotX(n, -pi / 2);
    n = _rotZ(n, rot);
    return _unit(n);
  }

  bool _sweptPaddle({
    required v.Vector3 center,
    required v.Vector3 normal,
    required double dt,
  }) {
    final vel = (ballDir.clone()..scale(ballSpeed));
    final r0 = ballPos - center;
    final dist0 = r0.dot(normal);
    final vn = vel.dot(normal);

    if (dist0.abs() < ballRadius + _eps) {
      final lateral0 = r0 - (normal.clone()..scale(dist0));
      if (lateral0.length <= paddleRadius + _eps) {
        final sign = (dist0 >= 0) ? 1.0 : -1.0;
        final push = (ballRadius - dist0.abs()) + _contactBias;
        ballPos += (normal.clone()..scale(sign * push));

        final nEff = normal.clone()..scale(sign);
        final d = ballDir;
        final dot = d.dot(nEff);
        var refl = d - (nEff.clone()..scale(2.0 * dot));
        ballDir = _unit(refl);
        ballPos += (ballDir.clone()..scale(ballSpeed * dt));
        return true;
      }
    }

    if (vn.abs() < 1e-6) return false;

    final sign = (vn < 0) ? 1.0 : -1.0;
    final tHit = (sign * ballRadius - dist0) / (-vn);
    if (tHit < 0 || tHit > dt) return false;

    final rHit = r0 + (vel.clone()..scale(tHit));
    final distHit = rHit.dot(normal);
    final lateral = rHit - (normal.clone()..scale(distHit));
    if (lateral.length > paddleRadius + _eps) return false;

    ballPos += (vel.clone()..scale(tHit));

    final nEff = normal.clone()..scale(sign);
    final d = ballDir;
    final dot = d.dot(nEff);
    var refl = d - (nEff.clone()..scale(2.0 * dot));
    ballDir = _unit(refl);

    ballPos += (nEff.clone()..scale(_contactBias));


    final rem = dt - tHit;
    if (rem > 0) {
      ballPos += (ballDir.clone()..scale(ballSpeed * rem));
    }
    return true;
  }

  bool _sweptSphere({
    required v.Vector3 center,
    required double radius,
    required double dt,
  }) {
    final R = radius + ballRadius;
    final v3 = (ballDir.clone()..scale(ballSpeed));
    final m = ballPos - center;
    final a = v3.dot(v3);
    final b = 2.0 * m.dot(v3);
    final c = m.dot(m) - R * R;

    if (c <= 0) {
      final n = _unit(m);
      final push = (R - sqrt(max(0.0, m.dot(m)))) + _eps;
      ballPos += (n.clone()..scale(push));
      final d = ballDir;
      final dot = d.dot(n);
      var refl = d - (n.clone()..scale(2.0 * dot));
      ballDir = _unit(refl);
      ballPos += (ballDir.clone()..scale(ballSpeed * dt));
      return true;
    }

    final disc = b * b - 4 * a * c;
    if (disc < 0) return false;

    final sqrtDisc = sqrt(disc);
    final t1 = (-b - sqrtDisc) / (2 * a);
    final t2 = (-b + sqrtDisc) / (2 * a);
    double tHit = -1;
    if (t1 >= 0 && t1 <= dt) {
      tHit = t1;
    } else if (t2 >= 0 && t2 <= dt) {
      tHit = t2;
    } else {
      return false;
    }

    ballPos += (v3.clone()..scale(tHit));
    final n = _unit(ballPos - center);
    final d = ballDir;
    final dot = d.dot(n);
    var refl = d - (n.clone()..scale(2.0 * dot));
    ballDir = _unit(refl);

    const double sepEps = 1e-3;
    ballPos += (n.clone()..scale(sepEps + _eps));

    final rem = dt - tHit;
    if (rem > 0) {
      ballPos += (ballDir.clone()..scale(ballSpeed * rem));
    }
    return true;
  }

  void _integrateBall(double dt) {
    final nL = _palmNormal(leftRotDeg);
    final nR = _palmNormal(rightRotDeg);

    const double maxStep = 1.0 / 240.0;
    double remaining = dt;

    while (remaining > 1e-6) {
      final step = remaining > maxStep ? maxStep : remaining;

      if (_sweptPaddle(center: _leftCenter(), normal: nL, dt: step) ||
          _sweptPaddle(center: _rightCenter(), normal: nR, dt: step) ||
          _sweptSphere(center: _leftCenter(), radius: paddleRadius, dt: step) ||
          _sweptSphere(center: _rightCenter(), radius: paddleRadius, dt: step)) {
        remaining -= step;
        continue;
      }

      ballPos += (ballDir.clone()..scale(ballSpeed * step));
      remaining -= step;
    }
  }

  void _startBall() {
    ballPos = v.Vector3((leftHandX + rightHandX) * 0.5, handsY, 0);
    final goLeft = Random().nextBool();
    final target = goLeft ? _leftCenter() : _rightCenter();
    ballDir = _unit(target - ballPos);
    running = true;
  }

  void _stopBall() => running = false;

  List<TransformModifier3D> _handFigures(
    List<Mesh3D> m, {
    required bool isLeft,
    required double x,
    required double rotDeg,
  }) {
    final double z = isLeft ? -handsSepZ : handsSepZ;
    final double rotRad = rotDeg * pi / 180.0;

    final base = Matrix4.identity()
      ..translate(x, handsY, z)
      ..rotateX(-pi / 2)
      ..rotateY(0)
      ..rotateZ(rotRad);

    return [
      TransformModifier3D(m[0], base.clone()),
      TransformModifier3D(m[1], base.clone()..translate(3.05, 1.15, 8.75)),
      TransformModifier3D(m[2], base.clone()..translate(0.70, 0.00, 9.75)),
      TransformModifier3D(m[3], base.clone()..translate(-2.00, -0.56, 9.10)),
      TransformModifier3D(m[4], base.clone()..translate(-4.65, -1.00, 7.15)),
    ];
  }

  TransformModifier3D _ballFigure(Mesh3D mesh) {
    return TransformModifier3D(
      mesh,
      Matrix4.identity()
        ..translate(ballPos.x, ballPos.y, ballPos.z)
        ..scale(0.4, 0.4, 0.4)
        ..rotateX(-pi / 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      title: 'DiTreDi — Hands & Ball',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        body: SafeArea(
          child: FutureBuilder<List<Mesh3D>>(
            future: _meshes,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Text('Loading 3D models...'));
              }
              if (snap.hasError) {
                return Center(child: Text('Asset/parse error:\n${snap.error}', textAlign: TextAlign.center));
              }
              if (!snap.hasData) return const Center(child: Text('No meshes returned'));

              final meshes = snap.data!;
              final leftHand = _handFigures(meshes, isLeft: true, x: leftHandX, rotDeg: leftRotDeg);
              final rightHand = _handFigures(meshes, isLeft: false, x: rightHandX, rotDeg: rightRotDeg);
              final ball = _ballFigure(meshes[5]);

              return Column(
                children: [
                  Expanded(
                    child: DiTreDiDraggable(
                      controller: _controller,
                      child: DiTreDi(
                        controller: _controller,
                        figures: [
                          ...leftHand,
                          ...rightHand,
                          ball,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _startBall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                          child: const Text('START', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _stopBall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                          child: const Text('STOP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Left hand X'),
                            Text(leftHandX.toStringAsFixed(1)),
                          ],
                        ),
                        Slider(
                          value: leftHandX, min: -60, max: 60, divisions: 240,
                          label: leftHandX.toStringAsFixed(1),
                          onChanged: (v) => setState(() => leftHandX = v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Left hand rotation (deg)'),
                            Text(leftRotDeg.toStringAsFixed(0)),
                          ],
                        ),
                        Slider(
                          value: leftRotDeg, min: -180, max: 180, divisions: 360,
                          label: leftRotDeg.toStringAsFixed(0),
                          onChanged: (v) => setState(() => leftRotDeg = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Right hand X'),
                            Text(rightHandX.toStringAsFixed(1)),
                          ],
                        ),
                        Slider(
                          value: rightHandX, min: -60, max: 60, divisions: 240,
                          label: rightHandX.toStringAsFixed(1),
                          onChanged: (v) => setState(() => rightHandX = v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Right hand rotation (deg)'),
                            Text(rightRotDeg.toStringAsFixed(0)),
                          ],
                        ),
                        Slider(
                          value: rightRotDeg, min: -180, max: 180, divisions: 360,
                          label: rightRotDeg.toStringAsFixed(0),
                          onChanged: (v) => setState(() => rightRotDeg = v),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
