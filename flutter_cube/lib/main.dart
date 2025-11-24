import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_cube/flutter_cube.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Кубы и камера',
      theme: ThemeData.dark(),
      home: const HomePage(title: 'Cubes and camera'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.title});
  final String? title;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  Scene? scene;
  Object? root;

  final List<Collider> colliders = <Collider>[];
  final double camRadius = 1.2;

  final TextEditingController countCtrl = TextEditingController(text: '150');
  final TextEditingController worldCtrl = TextEditingController(text: '60');
  int count = 150;
  double worldHalf = 60;
  int seed = 42;

  double yaw = 0;
  double pitch = 0;
  double fov = 60;

  late Vector3 camPos;
  Vector3 camTarget = Vector3(0, 0, 0);

  late AnimationController controller;

  Vector3? boundsMin;
  Vector3? boundsMax;
  double extraOut = 15.0;

  @override
  void initState() {
    super.initState();
    camPos = Vector3(0, 0, 120);
    controller = AnimationController(duration: const Duration(seconds: 20), vsync: this)
      ..addListener(() {
        final s = scene;
        if (s != null) s.update();
      })
      ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onSceneCreated(Scene s) {
    scene = s;
    s.camera.fov = fov;
    updateCamera();
    buildWorld();
  }

  void buildWorld() {
    final s = scene;
    if (s == null) return;

    if (root != null) {
      s.world.remove(root!);
      root = null;
    }
    colliders.clear();

    final rng = math.Random(seed);
    final r = Object(name: 'root');

    for (int i = 0; i < count; i++) {
      final x = (rng.nextDouble() * 2 - 1) * worldHalf;
      final y = (rng.nextDouble() * 2 - 1) * worldHalf;
      final z = (rng.nextDouble() * 2 - 1) * worldHalf;

      final size = 0.5 + rng.nextDouble() * 5.0;
      final pos = Vector3(x, y, z);
      const variantPath = "assets/cube/cube.obj";
      final cube = Object(
        position: pos.clone(),
        scale: Vector3.all(size),
        backfaceCulling: false,
        lighting: true,             
        fileName: variantPath,
      );

      cube.rotation.setValues(
        rng.nextDouble() * 360,
        rng.nextDouble() * 360,
        rng.nextDouble() * 360,
      );

      final radius = size * math.sqrt(3) * 0.5;
      colliders.add(Collider(center: pos.clone(), radius: radius));

      r.add(cube);
    }

    root = r;
    s.world.add(root!);
    s.update();

    computeBounds();
  }

  void computeBounds() {
    if (colliders.isEmpty) {
      boundsMin = Vector3(-worldHalf, -worldHalf, -worldHalf);
      boundsMax = Vector3(worldHalf, worldHalf, worldHalf);
      return;
    }
    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final c in colliders) {
      minX = math.min(minX, c.center.x - c.radius);
      minY = math.min(minY, c.center.y - c.radius);
      minZ = math.min(minZ, c.center.z - c.radius);
      maxX = math.max(maxX, c.center.x + c.radius);
      maxY = math.max(maxY, c.center.y + c.radius);
      maxZ = math.max(maxZ, c.center.z + c.radius);
    }
    boundsMin = Vector3(minX, minY, minZ);
    boundsMax = Vector3(maxX, maxY, maxZ);
  }

  void updateCamera() {
    final s = scene;
    if (s == null) return;
    s.camera.target.setFrom(camTarget);
    s.camera.position.setFrom(camPos);
    s.camera.fov = fov;
  }

  Vector3 forward() {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    return Vector3(-sy * cp, sp, -cy * cp)..normalize();
  }

  Vector3 right() {
    final f = forward();
    final up = Vector3(0, 1, 0);
    final r = up.cross(f)..normalize();
    return r;
  }

  Vector3 up() {
    final r = right();
    final f = forward();
    final u = f.cross(r)..normalize();
    return u;
  }

  void moveLocal({double dx = 0, double dy = 0, double dz = 0}) {
    final r = right();
    final u = up();
    final f = forward();
    final delta = r * dx + u * dy + f * dz;

    final proposed = camPos + delta;
    final resolved = resolveCollisions(proposed);

    camTarget += (resolved - camPos);
    camPos = resolved;

    updateCamera();
    setState(() {});
  }

  void rotateCamera(double dYaw, double dPitch) {
    const double limit = math.pi / 2 - 0.01;
    yaw += dYaw;
    pitch = (pitch + dPitch).clamp(-limit, limit);
    updateCamera();
    setState(() {});
  }

  Offset? lastDrag;
  double lastScale = 1.0;

  void onScaleStart(ScaleStartDetails d) {
    lastDrag = d.focalPoint;
    lastScale = 1.0;
  }

  void onScaleUpdate(ScaleUpdateDetails d) {
    final pos = d.focalPoint;
    if (lastDrag != null) {
      final delta = pos - lastDrag!;
      rotateCamera(delta.dx * 0.005, delta.dy * 0.005);
    }
    lastDrag = pos;

    final scaleDelta = d.scale - lastScale;
    if (scaleDelta.abs() > 0.01) {
      moveLocal(dz: scaleDelta * 25);
    }
    lastScale = d.scale;
  }

  void onScaleEnd(ScaleEndDetails d) {
    lastDrag = null;
    lastScale = 1.0;
  }

  void regenerate() {
    final parsedCount = int.tryParse(countCtrl.text.trim());
    final parsedWorld = double.tryParse(worldCtrl.text.trim());
    count = (parsedCount == null || parsedCount < 0) ? 0 : parsedCount.clamp(0, 5000);
    worldHalf = (parsedWorld == null || parsedWorld <= 0) ? 60 : parsedWorld;
    seed = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
    buildWorld();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? '3D Cubes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text('Количество кубов'),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, hintText: 'напр. 200'),
                    onSubmitted: (_) => regenerate(),
                  ),
                ),
                const Text('Разброс'),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: worldCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, hintText: 'напр. 60'),
                    onSubmitted: (_) => regenerate(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: regenerate,
                  icon: const Icon(Icons.casino),
                  label: const Text('Сгенерировать'),
                ),
                const SizedBox(width: 16),
                moveBtn('X-', () => moveLocal(dx: -5)),
                moveBtn('X+', () => moveLocal(dx: 5)),
                moveBtn('Y+', () => moveLocal(dy: 5)),
                moveBtn('Y-', () => moveLocal(dy: -5)),
                moveBtn('Z-', () => moveLocal(dz: -5)),
                moveBtn('Z+', () => moveLocal(dz: 5)),
              ],
            ),
          ),
          Expanded(
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  moveLocal(dz: -signal.scrollDelta.dy * 0.5);
                }
              },
              child: GestureDetector(
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                onScaleEnd: onScaleEnd,
                child: Cube(
                  onSceneCreated: onSceneCreated,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text('Cam: (${camPos.x.toStringAsFixed(1)}, ${camPos.y.toStringAsFixed(1)}, ${camPos.z.toStringAsFixed(1)})'),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Vector3 resolveCollisions(Vector3 proposed) {
    var corrected = proposed.clone();
    for (final c in colliders) {
      final toCenter = corrected - c.center;
      final dist = toCenter.length;
      final minDist = camRadius + c.radius + 0.1;
      if (dist < minDist) {
        if (dist == 0) {
          corrected.x = c.center.x + minDist;
        } else {
          final push = (minDist - dist);
          final n = toCenter / dist;
          corrected += n * push;
        }
      }
    }

    final minB = boundsMin;
    final maxB = boundsMax;
    if (minB != null && maxB != null) {
      corrected.x = corrected.x.clamp(minB.x - extraOut, maxB.x + extraOut);
      corrected.y = corrected.y.clamp(minB.y - extraOut, maxB.y + extraOut);
      corrected.z = corrected.z.clamp(minB.z - extraOut, maxB.z + extraOut);
    } else {
      corrected.x = corrected.x.clamp(-worldHalf * 1.5, worldHalf * 1.5);
      corrected.y = corrected.y.clamp(-worldHalf * 1.5, worldHalf * 1.5);
      corrected.z = corrected.z.clamp(-worldHalf * 1.5, worldHalf * 1.5);
    }
    return corrected;
  }

  Widget moveBtn(String label, VoidCallback onTap) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
  }
}

class Collider {
  Collider({required this.center, required this.radius});
  final Vector3 center;
  final double radius;
}
