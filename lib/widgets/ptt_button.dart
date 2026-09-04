import 'package:flutter/material.dart';
import '../theme.dart';

class PttButton extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final double size;
  final IconData? activeIcon;
  final IconData? idleIcon;

  const PttButton({
    super.key,
    required this.active,
    required this.onPressed,
    required this.onReleased,
    this.size = 72,
    this.activeIcon,
    this.idleIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.pttActive : AppColors.pttIdle,
          border: Border.all(
            color: active ? const Color(0xFFFF5252) : const Color(0xFF555555),
            width: 2.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.txRed.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
          gradient: RadialGradient(
            colors: active
                ? [const Color(0xFFEF5350), AppColors.pttActive]
                : [const Color(0xFF555555), AppColors.pttIdle],
            center: const Alignment(-0.3, -0.3),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? (activeIcon ?? Icons.mic)
                    : (idleIcon ?? activeIcon ?? Icons.mic_none),
                color: active ? Colors.white : const Color(0xFFBBBBBB),
                size: size * 0.35,
              ),
              Text(
                'PTT',
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : const Color(0xFFBBBBBB),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
