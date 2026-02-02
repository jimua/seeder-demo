import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart' hide Path; // Hide Path to avoid conflict
import 'simulation_engine.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class SeederMapSimulation extends StatefulWidget {
  const SeederMapSimulation({super.key});

  @override
  State<SeederMapSimulation> createState() => _SeederMapSimulationState();
}

class _SeederMapSimulationState extends State<SeederMapSimulation>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final SimulationEngine _engine = SimulationEngine();

  // Initial tilt (Radians). 
  double _tilt = 1.1; 

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_engine.state == TractorState.finished && _engine.isInitialized) return;
    setState(() {
      _engine.update();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Супутникова карта 3D'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _engine.reset()),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _engine.initialize(Size(constraints.maxWidth, constraints.maxHeight));

          // Perspective Logic
          Matrix4 transformMatrix = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Standard perspective depth
            ..rotateX(-_tilt)       // Tilt
            ..scale(0.85);          // Scale down to fit bottom corners

          return GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _tilt += details.delta.dy * 0.005;
                _tilt = _tilt.clamp(0.5, 1.4);
              });
            },
            child: Container(
              color: Colors.black, 
              child: Stack(
                children: [
                  // --- LAYER 1: TILTED WORLD (Map + Trace) ---
                  Center(
                    child: Transform(
                      transform: transformMatrix,
                      alignment: Alignment.center,
                      child: ClipRect(
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            children: [
                              // A. Real Map
                              FlutterMap(
                                options: MapOptions(
                                  initialCenter: const LatLng(50.68045075954323, 29.83711817113377),  
                                  initialZoom: 17.5, 
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.none, 
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                                    userAgentPackageName: 'com.example.seeder_demo',
                                  ),
                                ],
                              ),

                              // B. Flat Trace (Inside the tilt)
                              CustomPaint(
                                size: Size.infinite,
                                painter: TracePainter(engine: _engine),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- LAYER 2: 3D TRACTOR (Overlay) ---
                  // This sits on TOP of the transform, untilted.
                  // It manually calculates where to draw to look 3D.
                  CustomPaint(
                    size: Size.infinite,
                    painter: Tractor3DOverlayPainter(
                      engine: _engine,
                      matrix: transformMatrix,
                      screenSize: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- PAINTER 1: THE TRACE (Flat) ---
// This is simple because the Transform widget handles the 3D skew for us.
class TracePainter extends CustomPainter {
  final SimulationEngine engine;
  TracePainter({required this.engine});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stripPaint = Paint()
      ..color = Colors.lightGreenAccent.withOpacity(0.5) 
      ..style = PaintingStyle.fill;

    double halfWidth = (engine.tractorBase * 0.95) / 2;

    for (var strip in engine.strips) {
      if (strip.length < 2) continue;
      Path stripPath = Path();

      for (int i = 0; i < strip.length - 1; i++) {
        Offset p1 = strip[i];
        Offset p2 = strip[i + 1];

        double dx = p2.dx - p1.dx;
        double dy = p2.dy - p1.dy;
        double length = sqrt(dx * dx + dy * dy);
        if (length == 0) continue;

        double nx = -dy / length;
        double ny = dx / length;

        Offset s1L = Offset(p1.dx + nx * halfWidth, p1.dy + ny * halfWidth);
        Offset s1R = Offset(p1.dx - nx * halfWidth, p1.dy - ny * halfWidth);
        Offset s2R = Offset(p2.dx - nx * halfWidth, p2.dy - ny * halfWidth);
        Offset s2L = Offset(p2.dx + nx * halfWidth, p2.dy + ny * halfWidth);

        stripPath.moveTo(s1L.dx, s1L.dy);
        stripPath.lineTo(s1R.dx, s1R.dy);
        stripPath.lineTo(s2R.dx, s2R.dy);
        stripPath.lineTo(s2L.dx, s2L.dy);
      }
      canvas.drawPath(stripPath, stripPaint);
    }
  }
  @override
  bool shouldRepaint(covariant TracePainter oldDelegate) => true;
}

// --- PAINTER 2: THE TRACTOR (Real 3D) ---
// This manually projects points so the tractor can "stand up" vertically
class Tractor3DOverlayPainter extends CustomPainter {
  final SimulationEngine engine;
  final Matrix4 matrix;
  final Size screenSize;

  Tractor3DOverlayPainter({
    required this.engine,
    required this.matrix,
    required this.screenSize,
  });

  // Helper: Manually apply the UI's Transform Matrix to a point
  Offset project(Offset localPos, double zHeight) {
    // 1. Center the point (relative to screen center)
    double cx = localPos.dx - screenSize.width / 2;
    double cy = localPos.dy - screenSize.height / 2;

    // 2. Create a Vector3 (x, y, z)
    // Note: In Flutter's Transform coordinate system, Z moves towards viewer.
    // We treat zHeight as coming "out" of the map.
    v.Vector3 point = v.Vector3(cx, cy, zHeight);

    // 3. Apply the Matrix
    point = matrix.transformed3(point);

    // 4. Manual Perspective Division
    // The Matrix4.transformed3 doesn't automatically divide by w for perspective?
    // Actually, Flutter's Matrix4 handles projective transformations if we access the raw storage,
    // but transformed3 applies rotation/scale/translation.
    // For the perspective entry (3,2 = 0.001) to work, we need to handle 'w'.
    
    // Let's do a robust manual projection using the full Matrix4 multiplication
    final v.Vector4 vec4 = v.Vector4(cx, cy, zHeight, 1.0);
    final v.Vector4 result = matrix.transform(vec4);
    
    // Perspective division
    if (result.w != 0.0) {
      result.x /= result.w;
      result.y /= result.w;
      // result.z /= result.w;
    }

    // 5. Un-center (Map back to screen coordinates)
    return Offset(
      result.x + screenSize.width / 2, 
      result.y + screenSize.height / 2
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    double halfWidth = engine.tractorBase / 2;
    double height = 40.0; // Height of tractor in 3D units

    // 1. Calculate the 3 corners of the triangle in Local 2D space
    Offset localTip = const Offset(0, -25);
    Offset localBR = Offset(halfWidth, 25);
    Offset localBL = Offset(-halfWidth, 25);

    // 2. Rotate/Translate them to World 2D space (Where they are on the map)
    Offset toWorld(Offset local) {
      double dx = local.dx * cos(engine.angle + pi/2) - local.dy * sin(engine.angle + pi/2);
      double dy = local.dx * sin(engine.angle + pi/2) + local.dy * cos(engine.angle + pi/2);
      return Offset(engine.position.dx + dx, engine.position.dy + dy);
    }
    
    Offset wTip = toWorld(localTip);
    Offset wBR = toWorld(localBR);
    Offset wBL = toWorld(localBL);

    // 3. PROJECT vertices to Screen Space
    // Base (Z=0, touching the map)
    Offset sTip_Base = project(wTip, 0);
    Offset sBR_Base = project(wBR, 0);
    Offset sBL_Base = project(wBL, 0);

    // Top (Z=height, floating in air)
    Offset sTip_Top = project(wTip, -height);
    Offset sBR_Top = project(wBR, -height);
    Offset sBL_Top = project(wBL, -height);


    // 4. DRAW FACES
    // Shadows
    Path shadow = Path()
      ..moveTo(sTip_Base.dx + 5, sTip_Base.dy + 5)
      ..lineTo(sBR_Base.dx + 5, sBR_Base.dy + 5)
      ..lineTo(sBL_Base.dx + 5, sBL_Base.dy + 5)
      ..close();
    canvas.drawPath(shadow, Paint()..color = Colors.black.withOpacity(0.5));

    Paint sideDark = Paint()..color = Colors.red.shade900;
    Paint sideMed = Paint()..color = Colors.red.shade800;
    Paint sideLight = Paint()..color = Colors.red.shade700;

    // Back Face
    Path backFace = Path()
      ..moveTo(sBL_Base.dx, sBL_Base.dy)
      ..lineTo(sBR_Base.dx, sBR_Base.dy)
      ..lineTo(sBR_Top.dx, sBR_Top.dy)
      ..lineTo(sBL_Top.dx, sBL_Top.dy)..close();
    canvas.drawPath(backFace, sideDark);

    // Right Face
    Path rightFace = Path()
      ..moveTo(sBR_Base.dx, sBR_Base.dy)
      ..lineTo(sTip_Base.dx, sTip_Base.dy)
      ..lineTo(sTip_Top.dx, sTip_Top.dy)
      ..lineTo(sBR_Top.dx, sBR_Top.dy)..close();
    canvas.drawPath(rightFace, sideMed);

    // Left Face
    Path leftFace = Path()
      ..moveTo(sTip_Base.dx, sTip_Base.dy)
      ..lineTo(sBL_Base.dx, sBL_Base.dy)
      ..lineTo(sBL_Top.dx, sBL_Top.dy)
      ..lineTo(sTip_Top.dx, sTip_Top.dy)..close();
    canvas.drawPath(leftFace, sideLight);

    // Top Face
    Path topPoly = Path()
      ..moveTo(sTip_Top.dx, sTip_Top.dy)
      ..lineTo(sBR_Top.dx, sBR_Top.dy)
      ..lineTo(sBL_Top.dx, sBL_Top.dy)..close();
    canvas.drawPath(topPoly, Paint()..color = Colors.red);
    
    // Wireframe for definition
    canvas.drawPath(topPoly, Paint()..color = Colors.black.withOpacity(0.2)..style=PaintingStyle.stroke..strokeWidth=1);
    
    // Cab Dot
    Offset centerTop = Offset(
      (sTip_Top.dx + sBR_Top.dx + sBL_Top.dx) / 3,
      (sTip_Top.dy + sBR_Top.dy + sBL_Top.dy) / 3,
    );
    canvas.drawCircle(centerTop, 6, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant Tractor3DOverlayPainter oldDelegate) => true;
}