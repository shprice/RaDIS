import 'package:flutter/material.dart';
import '../theme.dart';

class PttButton extends StatefulWidget {
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final double size;

  const PttButton({
    super.key,
    required this.active,
    required this.onPressed,
    required this.onReleased,
    this.size = 72,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PttButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onPressed(),
      onTapUp: (_) => widget.onReleased(),
      onTapCancel: widget.onReleased,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.active ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.active ? AppColors.pttActive : AppColors.pttIdle,
                border: Border.all(
                  color: widget.active
                      ? const Color(0xFFFF5252)
                      : const Color(0xFF555555),
                  width: 2.5,
                ),
                boxShadow: widget.active
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
                  colors: widget.active
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
                      widget.active ? Icons.mic : Icons.mic_none,
                      color: widget.active ? Colors.white : const Color(0xFFBBBBBB),
                      size: widget.size * 0.35,
                    ),
                    Text(
                      'PTT',
                      style: TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: widget.size * 0.16,
                        fontWeight: FontWeight.bold,
                        color: widget.active
                            ? Colors.white
                            : const Color(0xFFBBBBBB),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
