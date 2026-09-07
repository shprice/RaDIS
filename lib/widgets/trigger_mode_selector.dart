import 'package:flutter/material.dart';
import '../models/trigger_mode.dart';
import '../theme.dart';

class TriggerModeSelector extends StatelessWidget {
  final TriggerMode mode;
  final ValueChanged<TriggerMode> onChanged;

  const TriggerModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SegmentedSwitch(selected: mode, onChanged: onChanged);
  }
}

class _SegmentedSwitch extends StatelessWidget {
  final TriggerMode selected;
  final ValueChanged<TriggerMode> onChanged;

  const _SegmentedSwitch({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: TriggerMode.values.map((mode) {
        final isSelected = mode == selected;
        final isFirst = mode == TriggerMode.values.first;
        final isLast = mode == TriggerMode.values.last;

        const selectedBorder = Color(0xFFFF5252);
        const selectedBg = Color(0xFF2A0A0A);
        const selectedText = Color(0xFFFF5252);
        const unselectedBorder = Color(0xFF444444);
        const unselectedBg = Color(0xFF1A1A1A);

        final borderColor = isSelected ? selectedBorder : unselectedBorder;
        final bgColor = isSelected ? selectedBg : unselectedBg;
        final textColor = isSelected ? selectedText : AppColors.textMuted;

        return GestureDetector(
          onTap: () => onChanged(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                top: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
                left: BorderSide(
                  color: borderColor,
                  width: isFirst ? 1 : 0.5,
                ),
                right: BorderSide(
                  color: borderColor,
                  width: isLast ? 1 : 0.5,
                ),
              ),
              borderRadius: BorderRadius.horizontal(
                left: isFirst ? const Radius.circular(3) : Radius.zero,
                right: isLast ? const Radius.circular(3) : Radius.zero,
              ),
            ),
            child: Text(
              mode.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

