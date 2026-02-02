import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:seeder_demo/tractor_3d_painter.dart';
import 'simulation_engine.dart';

class Seeder3dSimulation extends StatefulWidget {
  const Seeder3dSimulation({super.key});

  @override
  State<Seeder3dSimulation> createState() => _Seeder3dSimulationState();
}

class _Seeder3dSimulationState extends State<Seeder3dSimulation>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final SimulationEngine _engine = SimulationEngine();

  // Camera settings
  // 1.1 radians is roughly 60 degrees, a good angle to look down at a field
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
        title: const Text('3D Поле'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _engine.reset();
              });
            },
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _engine.initialize(Size(constraints.maxWidth, constraints.maxHeight));

          return GestureDetector(
            // Allow user to adjust camera angle
            onVerticalDragUpdate: (details) {
              setState(() {
                _tilt += details.delta.dy * 0.005;
                _tilt = _tilt.clamp(0.5, 1.5); // Limit tilt range
              });
            },
            child: Container(
              color: Colors.white,
              child: CustomPaint(
                size: Size.infinite,
                painter: Tractor3DPainter(
                  position: _engine.position,
                  angle: _engine.angle,
                  strips: _engine.strips,
                  tractorBase: _engine.tractorBase,
                  tractorHeight: _engine.tractorHeight,
                  tilt: _tilt,
                  fieldSize: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
