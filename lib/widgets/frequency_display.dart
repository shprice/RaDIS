import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FrequencyDisplay extends StatelessWidget {
  final double frequency; // Hz
  final bool interactive;
  final ValueChanged<double>? onChanged;

  const FrequencyDisplay({
    super.key,
    required this.frequency,
    this.interactive = false,
    this.onChanged,
  });

  String _formatFrequency(double hz) {
    // Format as NNN.NNN.NN (MHz groups)
    final khz = hz / 1000;
    final mhz = (hz / 1000000).floor();
    final khzPart = ((hz % 1000000) / 1000).floor();
    final hzPart = (hz % 1000).floor();
    return '${mhz.toString().padLeft(3, '0')}.'
        '${khzPart.toString().padLeft(3, '0')}.'
        '${hzPart.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _formatFrequency(frequency);

    Widget display = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border.all(color: const Color(0xFF1A3A1A), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        formatted,
        style: const TextStyle(
          fontFamily: 'Courier New',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF39FF14), // phosphor green
          letterSpacing: 3,
          shadows: [
            Shadow(
              color: Color(0x8039FF14),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );

    if (interactive && onChanged != null) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              onChanged!(frequency + 25000);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              onChanged!((frequency - 25000).clamp(0, double.infinity));
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.delta.dy < 0) {
              onChanged!(frequency + 25000);
            } else {
              onChanged!((frequency - 25000).clamp(0, double.infinity));
            }
          },
          child: Listener(
            onPointerSignal: (event) {
              // Scroll wheel
            },
            child: display,
          ),
        ),
      );
    }

    return display;
  }
}
