import 'dart:math';
import 'package:flutter/material.dart';

class Tractor3DPainter extends CustomPainter {
  final Offset position;
  final double angle;
  final List<List<Offset>> strips;
  final double tractorBase;
  final double tractorHeight;
  final double tilt;
  final Size fieldSize;

  Tractor3DPainter({
    required this.position,
    required this.angle,
    required this.strips,
    required this.tractorBase,
    required this.tractorHeight,
    required this.tilt,
    required this.fieldSize,
  });

  // --- PROJECTION HELPER ---
  Offset project(double x, double y, double z, Size size) {
    // 1. Center the coordinates (0,0 is now center of field)
    double cx = x - size.width / 2;
    double cy = y - size.height / 2;
    
    // 2. Apply Rotation around X-axis (Tilt)
    // We strictly use standard 3D rotation matrix formulas here:
    // y' = y*cos(theta) - z*sin(theta)
    // z' = y*sin(theta) + z*cos(theta)
    double yRotated = cy * cos(tilt) - z * sin(tilt);
    double zRotated = cy * sin(tilt) + z * cos(tilt);

    // 3. Apply Perspective Depth
    // We move the camera BACK (z translation) so the field is in front of us.
    // The "Top" of the screen (negative cy) is rotated 'away' (positive z depth).
    double cameraDist = 1300.0; // Distance of camera from center of rotation
    double depth = cameraDist - zRotated; 

    // If depth is too close, clamp it to avoid division by zero glitches
    if (depth < 10) depth = 10;

    double focalLength = 1100.0;
    double scale = focalLength / depth;

    // 4. Map back to screen
    double screenX = cx * scale + size.width / 2;
    // We add a vertical offset (size.height / 4) to shift the horizon up
    // so the field stays centered visually despite the perspective shrink.
    double screenY = yRotated * scale + size.height / 2 + (size.height * 0.1);

    return Offset(screenX, screenY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Field (Ground Plane)
    Path fieldPath = Path();
    fieldPath.moveTo(project(0, 0, 0, size).dx, project(0, 0, 0, size).dy);
    fieldPath.lineTo(project(size.width, 0, 0, size).dx, project(size.width, 0, 0, size).dy);
    fieldPath.lineTo(project(size.width, size.height, 0, size).dx, project(size.width, size.height, 0, size).dy);
    fieldPath.lineTo(project(0, size.height, 0, size).dx, project(0, size.height, 0, size).dy);
    fieldPath.close();

    canvas.drawPath(fieldPath, Paint()..color = Colors.brown.shade200);

    // 2. Draw Trace Strips
    final Paint stripPaint = Paint()
      ..color = Colors.green.shade800.withOpacity(0.4) // Semi-transparent for overlap
      ..style = PaintingStyle.fill; // FILL, not Stroke

    double halfWidth = (tractorBase * 0.95) / 2; 

    for (var strip in strips) {
      if (strip.length < 2) continue;
      
      Path stripPath = Path();

      for (int i = 0; i < strip.length - 1; i++) {
        Offset p1 = strip[i];
        Offset p2 = strip[i+1];

        // A. Calculate direction of this segment
        double dx = p2.dx - p1.dx;
        double dy = p2.dy - p1.dy;
        double length = sqrt(dx*dx + dy*dy);
        if (length == 0) continue;

        // B. Calculate Normal Vector (Perpendicular) to find edges
        // Normalized (-dy, dx)
        double nx = -dy / length;
        double ny = dx / length;

        // C. Calculate the 4 Corners on the ground (Z=0)
        // Point 1 Left & Right
        double p1Lx = p1.dx + nx * halfWidth;
        double p1Ly = p1.dy + ny * halfWidth;
        double p1Rx = p1.dx - nx * halfWidth;
        double p1Ry = p1.dy - ny * halfWidth;

        // Point 2 Left & Right
        double p2Lx = p2.dx + nx * halfWidth;
        double p2Ly = p2.dy + ny * halfWidth;
        double p2Rx = p2.dx - nx * halfWidth;
        double p2Ry = p2.dy - ny * halfWidth;

        // D. Project all 4 corners to Screen Space
        Offset s1L = project(p1Lx, p1Ly, 0, size);
        Offset s1R = project(p1Rx, p1Ry, 0, size);
        Offset s2R = project(p2Rx, p2Ry, 0, size);
        Offset s2L = project(p2Lx, p2Ly, 0, size);

        // E. Add Quad to Path
        stripPath.moveTo(s1L.dx, s1L.dy);
        stripPath.lineTo(s1R.dx, s1R.dy);
        stripPath.lineTo(s2R.dx, s2R.dy);
        stripPath.lineTo(s2L.dx, s2L.dy);
      }
      // Draw the constructed ribbon
      canvas.drawPath(stripPath, stripPaint);
    }

    // 3. Draw Tractor
    _draw3DTractor(canvas, size);
  }

  void _draw3DTractor(Canvas canvas, Size size) {
    // Dimensions
    double halfWidth = tractorBase / 2;
    double height = 30.0; // Taller to make it pop

    // Local Coordinates (Triangle pointing UP in local space)
    Offset localTip = const Offset(0, -25);
    Offset localBR = Offset(halfWidth, 25);
    Offset localBL = Offset(-halfWidth, 25);

    // Rotation/Translation Helper
    Offset toWorld(Offset local) {
      double dx = local.dx * cos(angle + pi/2) - local.dy * sin(angle + pi/2);
      double dy = local.dx * sin(angle + pi/2) + local.dy * cos(angle + pi/2);
      return Offset(position.dx + dx, position.dy + dy);
    }

    // World Coords
    Offset wTip = toWorld(localTip);
    Offset wBR = toWorld(localBR);
    Offset wBL = toWorld(localBL);

    // PROJECT Vertices
    // Base (Z=0)
    Offset sTip_Base = project(wTip.dx, wTip.dy, 0, size);
    Offset sBR_Base = project(wBR.dx, wBR.dy, 0, size);
    Offset sBL_Base = project(wBL.dx, wBL.dy, 0, size);

    // If we want it to stick OUT of the screen towards the camera, we need Z to affect the scale.
    // Let's use Positive Z = Up (Height).
    Offset sTip_Top = project(wTip.dx, wTip.dy, height, size);
    Offset sBR_Top = project(wBR.dx, wBR.dy, height, size);
    Offset sBL_Top = project(wBL.dx, wBL.dy, height, size);

    // PAINTER'S ALGORITHM (Draw order)
    
    // 1. Draw Shadow (Offset slightly on ground)
    Path shadow = Path()
      ..moveTo(sTip_Base.dx + 10, sTip_Base.dy + 10)
      ..lineTo(sBR_Base.dx + 10, sBR_Base.dy + 10)
      ..lineTo(sBL_Base.dx + 10, sBL_Base.dy + 10)
      ..close();
    canvas.drawPath(shadow, Paint()..color = Colors.black.withOpacity(0.2));

    // 2. Draw Faces
    // We cheat and draw all side faces every time. For a perfect 3D engine we'd cull backfaces,
    // but for a simple convex shape, drawing Back -> Right -> Left -> Top works okay.
    
    Paint sideDark = Paint()..color = Colors.red.shade900;
    Paint sideMed = Paint()..color = Colors.red.shade800;
    Paint sideLight = Paint()..color = Colors.red.shade700;

    // Back Face (BL to BR)
    Path backFace = Path()
      ..moveTo(sBL_Base.dx, sBL_Base.dy)
      ..lineTo(sBR_Base.dx, sBR_Base.dy)
      ..lineTo(sBR_Top.dx, sBR_Top.dy)
      ..lineTo(sBL_Top.dx, sBL_Top.dy)
      ..close();
    canvas.drawPath(backFace, sideDark);

    // Right Face (BR to Tip)
    Path rightFace = Path()
      ..moveTo(sBR_Base.dx, sBR_Base.dy)
      ..lineTo(sTip_Base.dx, sTip_Base.dy)
      ..lineTo(sTip_Top.dx, sTip_Top.dy)
      ..lineTo(sBR_Top.dx, sBR_Top.dy)
      ..close();
    canvas.drawPath(rightFace, sideMed);

    // Left Face (Tip to BL)
    Path leftFace = Path()
      ..moveTo(sTip_Base.dx, sTip_Base.dy)
      ..lineTo(sBL_Base.dx, sBL_Base.dy)
      ..lineTo(sBL_Top.dx, sBL_Top.dy)
      ..lineTo(sTip_Top.dx, sTip_Top.dy)
      ..close();
    canvas.drawPath(leftFace, sideLight);

    // Top Face
    Path topPoly = Path()
      ..moveTo(sTip_Top.dx, sTip_Top.dy)
      ..lineTo(sBR_Top.dx, sBR_Top.dy)
      ..lineTo(sBL_Top.dx, sBL_Top.dy)
      ..close();
    canvas.drawPath(topPoly, Paint()..color = Colors.red);
    
    // Wireframe outline to make geometry distinct
    canvas.drawPath(topPoly, Paint()..color = Colors.black.withOpacity(0.2)..style=PaintingStyle.stroke..strokeWidth=1);
  }

  @override
  bool shouldRepaint(covariant Tractor3DPainter oldDelegate) => true;
}