import 'package:flutter/material.dart';
import '../theme.dart';

class RxTxIndicator extends StatefulWidget {
  final bool rxActive;
  final bool txActive;

  const RxTxIndicator({
    super.key,
    required this.rxActive,
    required this.txActive,
  });

  @override
  State<RxTxIndicator> createState() => _RxTxIndicatorState();
}

class _RxTxIndicatorState extends State<RxTxIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LedIndicator(
          label: 'RX',
          active: widget.rxActive,
          activeColor: AppColors.rxGreen,
          animation: _glowAnimation,
        ),
        const SizedBox(width: 8),
        _LedIndicator(
          label: 'TX',
          active: widget.txActive,
          activeColor: AppColors.txRed,
          animation: _glowAnimation,
        ),
      ],
    );
  }
}

class _LedIndicator extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Animation<double> animation;

  const _LedIndicator({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? activeColor : const Color(0xFF333333),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(animation.value * 0.8),
                          blurRadius: 8 * animation.value,
                          spreadRadius: 2 * animation.value,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontFamily: 'Courier New',
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
