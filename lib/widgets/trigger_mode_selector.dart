import 'package:flutter/material.dart';
import '../models/trigger_mode.dart';
import '../theme.dart';

class TriggerModeSelector extends StatelessWidget {
  final TriggerMode mode;
  final ValueChanged<TriggerMode> onChanged;
  final double voxThreshold;
  final ValueChanged<double>? onVoxThresholdChanged;

  const TriggerModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.voxThreshold = 0.05,
    this.onVoxThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SegmentedSwitch(
          selected: mode,
          onChanged: onChanged,
        ),
        if (mode == TriggerMode.vox && onVoxThresholdChanged != null) ...[
          const SizedBox(height: 4),
          _VoxSensitivityRow(
            threshold: voxThreshold,
            onChanged: onVoxThresholdChanged!,
          ),
        ],
      ],
    );
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

class _VoxSensitivityRow extends StatelessWidget {
  final double threshold;
  final ValueChanged<double> onChanged;

  const _VoxSensitivityRow({
    required this.threshold,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // threshold is 0.01..0.5 — invert for "sensitivity" display (high threshold = low sensitivity)
    final sensitivity = 1.0 - ((threshold - 0.01) / 0.49).clamp(0.0, 1.0);

    return Row(
      children: [
        const Text(
          'SENS',
          style: TextStyle(
            fontSize: 8,
            color: AppColors.primaryGreen,
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primaryGreen,
                inactiveTrackColor: const Color(0xFF1A2A1A),
                thumbColor: AppColors.primaryGreen,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                trackHeight: 2,
              ),
              child: Slider(
                value: sensitivity,
                onChanged: (v) {
                  final newThreshold = 0.01 + (1.0 - v) * 0.49;
                  onChanged(newThreshold);
                },
              ),
            ),
          ),
        ),
        Text(
          '${(sensitivity * 100).round()}%',
          style: const TextStyle(
            fontSize: 8,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }
}
