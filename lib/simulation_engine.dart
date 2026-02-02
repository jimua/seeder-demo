import 'dart:math';
import 'dart:ui'; // For Offset and Size

enum TractorState { 
  movingUp, 
  turningToSwitchRow, 
  shiftingRow, 
  turningToFaceRow, 
  movingDown, 
  finished 
}

class SimulationEngine {
  // --- Configuration ---
  final double speed = 5.0;
  final double turnSpeed = 0.08;
  final double tractorBase = 50.0;
  final double tractorHeight = 35.0;
  final double rowWidth = 45.0;
  final double margin = 30.0;

  // --- State ---
  Offset position = Offset.zero;
  double angle = -pi / 2; // -90 degrees (UP)
  List<List<Offset>> strips = [];
  TractorState state = TractorState.movingUp;
  
  // Internal tracking
  bool isInitialized = false;
  Size fieldSize = Size.zero;
  double _targetDistanceTraveled = 0.0;
  double _targetAngle = 0.0;

  void initialize(Size size) {
    if (isInitialized) return;
    fieldSize = size;
    // Start bottom left
    position = Offset(margin, fieldSize.height - margin);
    strips = [[]];
    isInitialized = true;
  }

  void reset() {
    isInitialized = false;
    strips.clear();
    state = TractorState.movingUp;
    angle = -pi / 2;
  }

  /// This is the "Game Loop" logic. Call this once per frame.
  void update() {
    if (!isInitialized || state == TractorState.finished) return;

    _updatePhysics();
    _updateTrace();
  }

  void _updateTrace() {
    double backOffset = tractorHeight / 2;
    Offset seederPos = position - Offset(cos(angle), sin(angle)) * backOffset;

    if (strips.isEmpty) strips.add([]);
    
    if (strips.last.isEmpty || (strips.last.last - seederPos).distance > 3.0) {
      strips.last.add(seederPos);
    }
  }

  void _updatePhysics() {
    switch (state) {
      case TractorState.movingUp:
        _moveForward();
        if (position.dy <= margin) {
          _targetAngle = 0.0;
          state = TractorState.turningToSwitchRow;
        }
        break;

      case TractorState.movingDown:
        _moveForward();
        if (position.dy >= fieldSize.height - margin) {
          _targetAngle = 0.0;
          state = TractorState.turningToSwitchRow;
        }
        break;

      case TractorState.turningToSwitchRow:
        if (_rotateTowards(_targetAngle)) {
          // Check Right Boundary
          if (position.dx + rowWidth >= fieldSize.width - 20) {
            state = TractorState.finished;
          } else {
            state = TractorState.shiftingRow;
            _targetDistanceTraveled = 0;
          }
        }
        break;

      case TractorState.shiftingRow:
        _moveForward();
        _targetDistanceTraveled += speed;

        if (_targetDistanceTraveled >= rowWidth) {
          strips.add([]); // Start new overlap layer
          bool isAtTop = position.dy < fieldSize.height / 2;
          _targetAngle = isAtTop ? pi / 2 : -pi / 2;
          state = TractorState.turningToFaceRow;
        }
        break;

      case TractorState.turningToFaceRow:
        if (_rotateTowards(_targetAngle)) {
          double normalized = angle;
          if (normalized > pi) normalized -= 2 * pi;

          if ((normalized - pi / 2).abs() < 0.1) {
            state = TractorState.movingDown;
          } else {
            state = TractorState.movingUp;
          }
        }
        break;

      case TractorState.finished:
        break;
    }
  }

  void _moveForward() {
    double dx = cos(angle) * speed;
    double dy = sin(angle) * speed;
    position += Offset(dx, dy);
  }

  bool _rotateTowards(double target) {
    double diff = target - angle;
    if (diff.abs() < turnSpeed) {
      angle = target;
      return true;
    }
    angle += diff.sign * turnSpeed;
    return false;
  }
}