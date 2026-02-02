import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'simulation_engine.dart'; // Import Logic
import 'tractor_2d_painter.dart';   // Import Visuals

class Seeder2dSimulation extends StatefulWidget {
  const Seeder2dSimulation({super.key});

  @override
  State<Seeder2dSimulation> createState() => _Seeder2dSimulationState();
}

class _Seeder2dSimulationState extends State<Seeder2dSimulation>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  
  final SimulationEngine _engine = SimulationEngine();

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
        title: const Text('2D Поле'),
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
          // Initialize engine with screen size if needed
          _engine.initialize(Size(constraints.maxWidth, constraints.maxHeight));

          return Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: TractorPainter(
                  position: _engine.position,
                  angle: _engine.angle,
                  strips: _engine.strips,
                  tractorBase: _engine.tractorBase,
                  tractorHeight: _engine.tractorHeight,
                ),
              ),
              if (_engine.state == TractorState.finished)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text(
                      "Поле Завершено",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
            ],
          );
        },
      ),
    );
  }
}