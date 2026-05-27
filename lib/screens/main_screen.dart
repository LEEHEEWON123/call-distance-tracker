import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    ContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf4f7fb),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF5aaa85),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: _CallTabIcon(active: _currentIndex == 0),
            label: '통화 중',
          ),
          BottomNavigationBarItem(
            icon: _ContactsTabIcon(active: _currentIndex == 1),
            label: '연락처',
          ),
        ],
      ),
    );
  }
}

class _CallTabIcon extends StatelessWidget {
  final bool active;
  const _CallTabIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 32,
      child: CustomPaint(painter: _CallIconPainter(active: active)),
    );
  }
}

class _CallIconPainter extends CustomPainter {
  final bool active;
  const _CallIconPainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final blobColor =
        active ? const Color(0xFF93b5e1) : const Color(0xFFc0c0c0);
    final phoneColor =
        active ? const Color(0xFF5aaa85) : const Color(0xFFa0a0a0);

    // 블롭 몸통
    final blobPaint = Paint()..color = blobColor;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width * 0.38, size.height * 0.72),
          width: size.width * 0.55,
          height: size.height * 0.52),
      blobPaint,
    );

    // 눈
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
        Offset(size.width * 0.28, size.height * 0.65), 2.0, eyePaint);
    canvas.drawCircle(
        Offset(size.width * 0.46, size.height * 0.65), 2.0, eyePaint);

    // 볼터치
    final cheekPaint = Paint()..color = const Color(0xFFf5a8b0);
    canvas.drawCircle(
        Offset(size.width * 0.22, size.height * 0.73), 1.4, cheekPaint);
    canvas.drawCircle(
        Offset(size.width * 0.52, size.height * 0.73), 1.4, cheekPaint);

    // 웃음
    final smilePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(size.width * 0.28, size.height * 0.8);
    smilePath.quadraticBezierTo(size.width * 0.38, size.height * 0.88,
        size.width * 0.48, size.height * 0.8);
    canvas.drawPath(smilePath, smilePaint);

    // 휴대폰 (비스듬히 우측 겹치게)
    canvas.save();
    final phoneCx = size.width * 0.72;
    final phoneCy = size.height * 0.55;
    canvas.translate(phoneCx, phoneCy);
    canvas.rotate(0.61); // ~35도
    canvas.translate(-phoneCx, -phoneCy);

    final phonePaint = Paint()..color = phoneColor;
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width * 0.72, size.height * 0.52),
          width: size.width * 0.32,
          height: size.height * 0.58),
      const Radius.circular(4),
    );
    canvas.drawRRect(phoneRect, phonePaint);

    final screenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55);
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width * 0.72, size.height * 0.48),
          width: size.width * 0.2,
          height: size.height * 0.34),
      const Radius.circular(2),
    );
    canvas.drawRRect(screenRect, screenPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CallIconPainter old) => old.active != active;
}

class _ContactsTabIcon extends StatelessWidget {
  final bool active;
  const _ContactsTabIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 32,
      child: CustomPaint(painter: _ContactsIconPainter(active: active)),
    );
  }
}

class _ContactsIconPainter extends CustomPainter {
  final bool active;
  const _ContactsIconPainter({required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final blueColor =
        active ? const Color(0xFF93b5e1) : const Color(0xFFc0c0c0);
    final orangeColor =
        active ? const Color(0xFFf5a878) : const Color(0xFFc0c0c0);
    final pinColor =
        active ? const Color(0xFF5aaa85) : const Color(0xFFa0a0a0);

    void drawBlob(Offset center, Color color) {
      final paint = Paint()..color = color;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 18, height: 17),
        paint,
      );
      final eyePaint = Paint()..color = Colors.white;
      canvas.drawCircle(center + const Offset(-3, -1), 1.5, eyePaint);
      canvas.drawCircle(center + const Offset(3, -1), 1.5, eyePaint);
      final cheekPaint = Paint()..color = const Color(0xFFf5a8b0);
      canvas.drawCircle(center + const Offset(-4, 2), 1.1, cheekPaint);
      canvas.drawCircle(center + const Offset(4, 2), 1.1, cheekPaint);
      final smilePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final smilePath = Path();
      smilePath.moveTo(center.dx - 3, center.dy + 3.5);
      smilePath.quadraticBezierTo(
          center.dx, center.dy + 5.5, center.dx + 3, center.dy + 3.5);
      canvas.drawPath(smilePath, smilePaint);
    }

    void drawPin(Offset tip) {
      final pinPaint = Paint()..color = pinColor;
      final path = Path();
      path.moveTo(tip.dx, tip.dy - 9);
      path.cubicTo(
          tip.dx - 4, tip.dy - 9, tip.dx - 4, tip.dy - 3, tip.dx, tip.dy - 3);
      path.cubicTo(
          tip.dx + 4, tip.dy - 3, tip.dx + 4, tip.dy - 9, tip.dx, tip.dy - 9);
      path.lineTo(tip.dx, tip.dy);
      path.close();
      canvas.drawPath(path, pinPaint);
      final holePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(tip.dx, tip.dy - 6.5), 1.5, holePaint);
    }

    // 파란 블롭 (좌)
    final blueCenter = Offset(size.width * 0.3, size.height * 0.7);
    drawBlob(blueCenter, blueColor);
    drawPin(Offset(blueCenter.dx, blueCenter.dy - 8));

    // 주황 블롭 (우)
    final orangeCenter = Offset(size.width * 0.7, size.height * 0.7);
    drawBlob(orangeCenter, orangeColor);
    drawPin(Offset(orangeCenter.dx, orangeCenter.dy - 8));

    // 점선 연결
    final dashPaint = Paint()
      ..color = pinColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final startX = blueCenter.dx + 9;
    final endX = orangeCenter.dx - 9;
    final y = size.height * 0.7;
    var x = startX;
    while (x < endX) {
      canvas.drawLine(Offset(x, y), Offset((x + 2.5).clamp(x, endX), y), dashPaint);
      x += 5;
    }
  }

  @override
  bool shouldRepaint(_ContactsIconPainter old) => old.active != active;
}
