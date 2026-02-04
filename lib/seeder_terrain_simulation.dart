import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'simulation_engine.dart';

enum TerrainType {
  bowl,   
  hills,  
  valley, 
  hump,
}

class SeederTerrainSimulation extends StatefulWidget {
  const SeederTerrainSimulation({super.key});

  @override
  State<SeederTerrainSimulation> createState() => _SeederTerrainSimulationState();
}

class _SeederTerrainSimulationState extends State<SeederTerrainSimulation>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final SimulationEngine _engine = SimulationEngine();

  double _tilt = 1.1; 
  TerrainType _currentTerrain = TerrainType.bowl;

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

  void _setTerrain(TerrainType type) {
    setState(() {
      _currentTerrain = type;
      _engine.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Рельєф'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _engine.reset()),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _engine.initialize(Size(constraints.maxWidth, constraints.maxHeight));

                return GestureDetector(
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _tilt += details.delta.dy * 0.005;
                      _tilt = _tilt.clamp(0.5, 1.5);
                    });
                  },
                  child: Container(
                    color: Colors.white,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: TerrainPainter(
                        engine: _engine, 
                        tilt: _tilt,
                        terrainType: _currentTerrain,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Control Panel
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTerrainButton("Чаша", TerrainType.bowl, Icons.circle),
                  const SizedBox(width: 8),
                  _buildTerrainButton("Горб", TerrainType.hump, Icons.landscape), // <-- NEW
                  const SizedBox(width: 8),
                  _buildTerrainButton("Пагорби", TerrainType.hills, Icons.waves),
                  const SizedBox(width: 8),
                  _buildTerrainButton("Долина", TerrainType.valley, Icons.golf_course),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerrainButton(String label, TerrainType type, IconData icon) {
    bool isSelected = _currentTerrain == type;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: () => _setTerrain(type),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class TerrainPainter extends CustomPainter {
  final SimulationEngine engine; 
  final double tilt;
  final TerrainType terrainType;

  TerrainPainter({
    required this.engine,
    required this.tilt,
    required this.terrainType,
  });

  // --- 1. DYNAMIC TERRAIN FORMULA ---
  double getTerrainZ(double x, double y, Size size) {
    double cx = size.width / 2;
    double cy = size.height / 2;
    
    // Normalized coordinates (-1.0 to 1.0)
    double nx = (x - cx) / cx; 
    double ny = (y - cy) / cy;

    switch (terrainType) {
      case TerrainType.bowl:
        double distSq = nx*nx + ny*ny;
        return distSq * 150.0;

      case TerrainType.hills:
        return (sin(nx * 4.0) + cos(ny * 4.0)) * 40.0 + 40.0;

      case TerrainType.valley:
        return (nx * nx) * 180.0; 

      case TerrainType.hump:
        // Gaussian Bell Curve
        // Formula: Height * exp(-k * distance^2)
        // High in center (0,0), drops to near zero at edges
        double distSq = nx*nx + ny*ny;
        return 220.0 * exp(-distSq * 2.5); // 220.0 is the peak height
    }
  }

  // --- 2. PROJECTION LOGIC ---
  Offset project(v.Vector3 point, Size size) {
    double cx = point.x - size.width / 2;
    double cy = point.y - size.height / 2;
    
    double yRotated = cy * cos(tilt) - point.z * sin(tilt);
    double zRotated = cy * sin(tilt) + point.z * cos(tilt);

    double cameraDist = 1800.0;
    double depth = cameraDist - zRotated; 
    if (depth < 10) depth = 10;
    double scale = 1200.0 / depth;

    double screenX = cx * scale + size.width / 2;
    double screenY = yRotated * scale + size.height / 2 + (size.height * 0.1);

    return Offset(screenX, screenY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // --- DRAW TERRAIN MESH ---
    final Paint linePaint = Paint()
      ..color = Colors.brown.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double step = 30.0; 

    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        double z1 = getTerrainZ(x, y, size);
        double z2 = getTerrainZ(x + step, y, size);
        double z3 = getTerrainZ(x, y + step, size);
        
        Offset p1 = project(v.Vector3(x, y, z1), size);
        Offset p2 = project(v.Vector3(x + step, y, z2), size);
        Offset p3 = project(v.Vector3(x, y + step, z3), size);

        if (x + step <= size.width) canvas.drawLine(p1, p2, linePaint);
        if (y + step <= size.height) canvas.drawLine(p1, p3, linePaint);
      }
    }

    // --- DRAW STRIPS ---
    final Paint stripPaint = Paint()
      ..color = Colors.green.shade800.withOpacity(0.5) 
      ..style = PaintingStyle.fill;

    double halfWidth = (engine.tractorBase * 0.95) / 2; 

    for (var strip in engine.strips) {
      if (strip.length < 2) continue;
      
      for (int i = 0; i < strip.length - 1; i++) {
        Offset p1 = strip[i];
        Offset p2 = strip[i+1];

        double dx = p2.dx - p1.dx;
        double dy = p2.dy - p1.dy;
        double len = sqrt(dx*dx + dy*dy);
        if (len == 0) continue;
        double nx = -dy / len;
        double ny = dx / len;

        double p1Lx = p1.dx + nx * halfWidth;
        double p1Ly = p1.dy + ny * halfWidth;
        double p1Rx = p1.dx - nx * halfWidth;
        double p1Ry = p1.dy - ny * halfWidth;
        
        double p2Lx = p2.dx + nx * halfWidth;
        double p2Ly = p2.dy + ny * halfWidth;
        double p2Rx = p2.dx - nx * halfWidth;
        double p2Ry = p2.dy - ny * halfWidth;

        Offset s1L = project(v.Vector3(p1Lx, p1Ly, getTerrainZ(p1Lx, p1Ly, size)), size);
        Offset s1R = project(v.Vector3(p1Rx, p1Ry, getTerrainZ(p1Rx, p1Ry, size)), size);
        Offset s2R = project(v.Vector3(p2Rx, p2Ry, getTerrainZ(p2Rx, p2Ry, size)), size);
        Offset s2L = project(v.Vector3(p2Lx, p2Ly, getTerrainZ(p2Lx, p2Ly, size)), size);

        Path path = Path()
          ..moveTo(s1L.dx, s1L.dy)..lineTo(s1R.dx, s1R.dy)
          ..lineTo(s2R.dx, s2R.dy)..lineTo(s2L.dx, s2L.dy)..close();
        canvas.drawPath(path, stripPaint);
      }
    }

    // --- DRAW TRACTOR ---
    _drawTractorOnTerrain(canvas, size);
  }

  void _drawTractorOnTerrain(Canvas canvas, Size size) {
    double halfWidth = engine.tractorBase / 2;
    double height = 30.0; 

    Offset toWorld(Offset local) {
      double dx = local.dx * cos(engine.angle + pi/2) - local.dy * sin(engine.angle + pi/2);
      double dy = local.dx * sin(engine.angle + pi/2) + local.dy * cos(engine.angle + pi/2);
      return Offset(engine.position.dx + dx, engine.position.dy + dy);
    }

    Offset localTip = const Offset(0, -25);
    Offset localBR = Offset(halfWidth, 25);
    Offset localBL = Offset(-halfWidth, 25);

    Offset wTip2D = toWorld(localTip);
    Offset wBR2D = toWorld(localBR);
    Offset wBL2D = toWorld(localBL);

    v.Vector3 pTip = v.Vector3(wTip2D.dx, wTip2D.dy, getTerrainZ(wTip2D.dx, wTip2D.dy, size));
    v.Vector3 pBR = v.Vector3(wBR2D.dx, wBR2D.dy, getTerrainZ(wBR2D.dx, wBR2D.dy, size));
    v.Vector3 pBL = v.Vector3(wBL2D.dx, wBL2D.dy, getTerrainZ(wBL2D.dx, wBL2D.dy, size));

    // Calculate Surface Normal
    v.Vector3 vecA = pBL - pTip;
    v.Vector3 vecB = pBR - pTip;
    v.Vector3 normal = vecA.cross(vecB).normalized();
    if (normal.z < 0) normal.scale(-1.0);

    v.Vector3 pTipTop = pTip + (normal * height);
    v.Vector3 pBRTop = pBR + (normal * height);
    v.Vector3 pBLTop = pBL + (normal * height);

    Offset sTip_Base = project(pTip, size);
    Offset sBR_Base = project(pBR, size);
    Offset sBL_Base = project(pBL, size);

    Offset sTip_Top = project(pTipTop, size);
    Offset sBR_Top = project(pBRTop, size);
    Offset sBL_Top = project(pBLTop, size);

    Paint sideDark = Paint()..color = Colors.red.shade900;
    Paint sideMed = Paint()..color = Colors.red.shade800;
    Paint sideLight = Paint()..color = Colors.red.shade700;

    Path backFace = Path()..moveTo(sBL_Base.dx, sBL_Base.dy)..lineTo(sBR_Base.dx, sBR_Base.dy)..lineTo(sBR_Top.dx, sBR_Top.dy)..lineTo(sBL_Top.dx, sBL_Top.dy)..close();
    canvas.drawPath(backFace, sideDark);

    Path rightFace = Path()..moveTo(sBR_Base.dx, sBR_Base.dy)..lineTo(sTip_Base.dx, sTip_Base.dy)..lineTo(sTip_Top.dx, sTip_Top.dy)..lineTo(sBR_Top.dx, sBR_Top.dy)..close();
    canvas.drawPath(rightFace, sideMed);

    Path leftFace = Path()..moveTo(sTip_Base.dx, sTip_Base.dy)..lineTo(sBL_Base.dx, sBL_Base.dy)..lineTo(sBL_Top.dx, sBL_Top.dy)..lineTo(sTip_Top.dx, sTip_Top.dy)..close();
    canvas.drawPath(leftFace, sideLight);

    Path topPoly = Path()..moveTo(sTip_Top.dx, sTip_Top.dy)..lineTo(sBR_Top.dx, sBR_Top.dy)..lineTo(sBL_Top.dx, sBL_Top.dy)..close();
    canvas.drawPath(topPoly, Paint()..color = Colors.red);
    
    Offset centerTop = Offset((sTip_Top.dx + sBR_Top.dx + sBL_Top.dx) / 3, (sTip_Top.dy + sBR_Top.dy + sBL_Top.dy) / 3);
    canvas.drawCircle(centerTop, 6, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant TerrainPainter oldDelegate) => true;
}