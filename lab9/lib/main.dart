import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:math';
 
void main() {
  runApp(const MyApp());
}
 
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
 
  @override
  State<MyApp> createState() => _MyAppState();
}
 
class _MyAppState extends State<MyApp> {
  var indexAngle = 0.0;
  var middleAngle = 0.0;
  var ringAngle = 0.0;
  var pinkyAngle = 0.0;
 
  var handX = 0.0;
  var handY = 0.0;
  var handZ = 0.0;
 
  var earthX = 0.0;
  var earthY = 40.0;
  var earthZ = 0.0;
 
  final double grabRadius = 15.0;
  final double collisionRadius = 5.0;
  bool isGrabbed = false;
  double grabbedOffsetX = 0.0;
  double grabbedOffsetY = 0.0;
  double grabbedOffsetZ = 0.0;
 
  final Future<List<Mesh3D>> sphere = _generatePoints();
 
  bool canGrab() {
    final distance = sqrt(
      pow(handX - earthX, 2) + 
      pow(handY - earthY, 2) + 
      pow(handZ - earthZ, 2)
    );
    return distance <= grabRadius;
  }
 
  bool checkCollision(double newHandX, double newHandY, double newHandZ) {
    final distance = sqrt(
      pow(newHandX - earthX, 2) + 
      pow(newHandY - earthY, 2) + 
      pow(newHandZ - earthZ, 2)
    );
    if (!isGrabbed) {
      return distance < collisionRadius;
    }
    return false;
  }
 
  final _controller = DiTreDiController(
    rotationX: 0,
    rotationY: 0,
    light: vector.Vector3(-0.5, -0.5, 0.5),
    maxUserScale: 10,
    minUserScale: 0.5,
    userScale: 1,
  );
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      title: 'DiTreDi Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Flex(
            crossAxisAlignment: CrossAxisAlignment.start,
            direction: Axis.vertical,
            children: [
              FutureBuilder(
                  future: sphere,
                  builder: (BuildContext context, AsyncSnapshot<List<Mesh3D>> snapshot){
                    List<Widget> children;
                    if(snapshot.hasData) {
                      children = <Widget>[
                        Expanded(
                          child: DiTreDiDraggable(
                            controller: _controller,
                            child: DiTreDi(
                              figures: [
                                TransformModifier3D(
                                    snapshot.data![0],
                                    Matrix4.identity()
                                      ..translate(handX, handY, handZ)
                                      ..rotateX(-pi/2)
                                ),
                                TransformModifier3D(
                                    snapshot.data![1],
                                    Matrix4.identity()
                                      ..translate(handX, handY, handZ)
                                      ..rotateX(-pi/2)
                                      ..translate(3.05,1.15,8.75)
                                      ..translate(-0.2,-0.25, -2.2)
                                      ..rotateX(-(indexAngle * pi/18))
                                      ..translate(0.2,0.25, 2.2)
                                ),
                                TransformModifier3D(
                                    snapshot.data![2],
                                    Matrix4.identity()
                                      ..translate(handX, handY, handZ)
                                      ..rotateX(-pi/2)
                                      ..translate(0.7,0.0,9.75)
                                      ..translate(0.0,-0.5, -2.25)
                                      ..rotateX(-(middleAngle * pi/18))
                                      ..translate(0.0,0.5, 2.25)
                                ),
                                TransformModifier3D(
                                    snapshot.data![3],
                                    Matrix4.identity()
                                      ..translate(handX, handY, handZ)
                                      ..rotateX(-pi/2)
                                      ..translate(-2.0,-0.56,9.1)
                                      ..translate(0.0,-0.25, -2.2)
                                      ..rotateX(-(ringAngle * pi/18))
                                      ..translate(0.0, 0.25, 2.2)
                                      ..rotate
                                ),
                                TransformModifier3D(
                                    snapshot.data![4],
                                    Matrix4.identity()
                                      ..translate(handX, handY, handZ)
                                      ..rotateX(-pi/2)
                                      ..translate(-4.65,-1.0,7.15)
                                      ..translate(0.0,0.0, -1.25)
                                      ..rotateX(-(pinkyAngle * pi/18))
                                      ..translate(0.0,0.0, 1.25)
                                ),
                                TransformModifier3D(
                                    snapshot.data![5],
                                    Matrix4.identity()
                                      ..translate(earthX, earthY, earthZ)
                                      ..rotateX(-pi/2)
                                      ..rotateY(pi)
                                ),
                              ],
                              controller: _controller,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Drag to rotate. Scroll to zoom"),
                        ),
                        Expanded(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // ⬆️ СНАЧАЛА — управление позицией руки
      const SizedBox(height: 10),
      const Text("Управление позицией руки", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final newY = handY + 4.0;
                    if (!checkCollision(handX, newY, handZ)) {
                      handY = newY;
                      if (isGrabbed) earthY = handY + grabbedOffsetY;
                    }
                  });
                },
                child: const Icon(Icons.arrow_upward),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final newX = handX - 4.0;
                        if (!checkCollision(newX, handY, handZ)) {
                          handX = newX;
                          if (isGrabbed) earthX = handX + grabbedOffsetX;
                        }
                      });
                    },
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final newX = handX + 4.0;
                        if (!checkCollision(newX, handY, handZ)) {
                          handX = newX;
                          if (isGrabbed) earthX = handX + grabbedOffsetX;
                        }
                      });
                    },
                    child: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final newY = handY - 4.0;
                    if (!checkCollision(handX, newY, handZ)) {
                      handY = newY;
                      if (isGrabbed) earthY = handY + grabbedOffsetY;
                    }
                  });
                },
                child: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
          const SizedBox(width: 30),
          Column(
            children: [
              const Text("Z", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final newZ = handZ + 4.0;
                    if (!checkCollision(handX, handY, newZ)) {
                      handZ = newZ;
                      if (isGrabbed) earthZ = handZ + grabbedOffsetZ;
                    }
                  });
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                child: const Text("↑", style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final newZ = handZ - 4.0;
                    if (!checkCollision(handX, handY, newZ)) {
                      handZ = newZ;
                      if (isGrabbed) earthZ = handZ + grabbedOffsetZ;
                    }
                  });
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                child: const Text("↓", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),

      const SizedBox(height: 15),

      // Дальше — GRAB/RELEASE
      const Text("Управление кулаком", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                indexAngle = middleAngle = ringAngle = pinkyAngle = 12.0;
                if (canGrab() && !isGrabbed) {
                  isGrabbed = true;
                  grabbedOffsetX = earthX - handX;
                  grabbedOffsetY = earthY - handY;
                  grabbedOffsetZ = earthZ - handZ;
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text("GRAB", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                indexAngle = middleAngle = ringAngle = pinkyAngle = 0.0;
                isGrabbed = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text("RELEASE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),

      const SizedBox(height: 15),

      // И — слайдеры пальцев
      Slider(
        value: indexAngle, min: 0, max: 12, divisions: 13,
        label: (180 - 10 * indexAngle.round()).toString(),
        onChanged: (v) => setState(() => indexAngle = v),
      ),
      Slider(
        value: middleAngle, min: 0, max: 12, divisions: 13,
        label: (180 - 10 * middleAngle.round()).toString(),
        onChanged: (v) => setState(() => middleAngle = v),
      ),
      Slider(
        value: ringAngle, min: 0, max: 12, divisions: 13,
        label: (180 - 10 * ringAngle.round()).toString(),
        onChanged: (v) => setState(() => ringAngle = v),
      ),
      Slider(
        value: pinkyAngle, min: 0, max: 12, divisions: 13,
        label: (180 - 10 * pinkyAngle.round()).toString(),
        onChanged: (v) => setState(() => pinkyAngle = v),
      ),
    ],
  ),
)                        
                      ];
                    }else{
                      children = <Widget>[
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("Failed to load"),
                        )
                      ];
                    }
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: children,
                      ),
                    );
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
 
Future<List<Mesh3D>> _generatePoints() async{
  return [
    Mesh3D(await ObjParser().loadFromResources("assets/hand/hand.obj")),
    Mesh3D(await ObjParser().loadFromResources("assets/hand/index.obj"),),
    Mesh3D(await ObjParser().loadFromResources("assets/hand/middle.obj"),),
    Mesh3D(await ObjParser().loadFromResources("assets/hand/ring.obj"),),
    Mesh3D(await ObjParser().loadFromResources("assets/hand/pinky.obj"),),
    Mesh3D(await ObjParser().loadFromResources("assets/hand/skull.obj"),)
  ];
}