import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Flag for a language entry. Kurdish has no emoji flag, so the Kurdistan flag is drawn.
class LangFlag extends StatelessWidget {
  const LangFlag({super.key, required this.code, required this.flag, this.size = 20});
  final String code, flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (code != 'ku') return Text(flag, style: TextStyle(fontSize: size));
    return SizedBox(
      width: size * 1.25,
      height: size * 1.15,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.08),
          child: CustomPaint(size: Size(size * 1.2, size * 0.8), painter: _KurdistanFlag()),
        ),
      ),
    );
  }
}

class _KurdistanFlag extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final h = s.height / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, h), Paint()..color = const Color(0xFFED2024));
    canvas.drawRect(Rect.fromLTWH(0, h, s.width, h), Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawRect(Rect.fromLTWH(0, 2 * h, s.width, h), Paint()..color = const Color(0xFF278E43));
    // Sun with 21 rays.
    final c = Offset(s.width / 2, s.height / 2);
    final rOut = h * 1.05, rIn = h * 0.62;
    final path = Path();
    const n = 21;
    for (var i = 0; i < n * 2; i++) {
      final r = i.isEven ? rOut : rIn;
      final a = -math.pi / 2 + i * math.pi / n;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    final sun = Paint()..color = const Color(0xFFFEBD11);
    canvas.drawPath(path, sun);
    canvas.drawCircle(c, rIn * 0.95, sun);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
