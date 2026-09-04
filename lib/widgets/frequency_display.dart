import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

enum FreqUnit { khz, mhz, ghz }

extension _FreqUnitExt on FreqUnit {
  String get label {
    switch (this) {
      case FreqUnit.khz: return 'kHz';
      case FreqUnit.mhz: return 'MHz';
      case FreqUnit.ghz: return 'GHz';
    }
  }

  double get divisor {
    switch (this) {
      case FreqUnit.khz: return 1e3;
      case FreqUnit.mhz: return 1e6;
      case FreqUnit.ghz: return 1e9;
    }
  }

  // Tuning step for ▲/▼ and scroll wheel
  double get stepHz {
    switch (this) {
      case FreqUnit.khz: return 1000;    // 1 kHz
      case FreqUnit.mhz: return 25000;   // 25 kHz
      case FreqUnit.ghz: return 1000000; // 1 MHz
    }
  }
}

const _kGreen = Color(0xFF39FF14);
const _kGreenDim = Color(0x8039FF14);
const _kGreenVeryDim = Color(0xFF1A4A1A);
const _kBg = Color(0xFF050505);
const _kBorder = Color(0xFF1A3A1A);

class FrequencyDisplay extends StatefulWidget {
  final double frequency; // Hz
  final ValueChanged<double>? onChanged;

  const FrequencyDisplay({
    super.key,
    required this.frequency,
    this.onChanged,
  });

  @override
  State<FrequencyDisplay> createState() => _FrequencyDisplayState();
}

class _FrequencyDisplayState extends State<FrequencyDisplay> {
  FreqUnit _unit = FreqUnit.mhz;

  bool get _interactive => widget.onChanged != null;

  double get _displayValue => widget.frequency / _unit.divisor;

  String _format(double v) => v.toStringAsFixed(1);

  void _adjust(int direction) {
    final hz = (widget.frequency + direction * _unit.stepHz).clamp(0.0, 100e9);
    widget.onChanged?.call(hz);
  }

  Future<void> _openKeypad() async {
    final hz = await showDialog<double>(
      context: context,
      builder: (_) => _FrequencyKeypadDialog(
        initialHz: widget.frequency,
        initialUnit: _unit,
        onUnitChanged: (u) => setState(() => _unit = u),
      ),
    );
    if (hz != null) widget.onChanged?.call(hz);
  }

  @override
  Widget build(BuildContext context) {
    final display = _buildDisplay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_interactive)
              Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) {
                    _adjust(e.scrollDelta.dy < 0 ? 1 : -1);
                  }
                },
                child: display,
              )
            else
              display,
            if (_interactive) ...[
              const SizedBox(width: 4),
              _StepButtons(onUp: () => _adjust(1), onDown: () => _adjust(-1)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnitPills(
              selected: _unit,
              onSelected: (u) => setState(() => _unit = u),
            ),
            if (_interactive) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openKeypad,
                child: const Icon(Icons.dialpad, size: 14, color: _kGreenVeryDim),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDisplay() {
    Widget box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: _kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _format(_displayValue),
            style: const TextStyle(
              fontFamily: 'Courier New',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _kGreen,
              letterSpacing: 2,
              shadows: [Shadow(color: _kGreenDim, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _unit.label,
            style: const TextStyle(
              fontFamily: 'Courier New',
              fontSize: 11,
              color: _kGreen,
              shadows: [Shadow(color: _kGreenDim, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );

    if (!_interactive) return box;

    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _adjust(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _adjust(-1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _openKeypad,
        child: box,
      ),
    );
  }
}

class _StepButtons extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _StepButtons({required this.onUp, required this.onDown});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(icon: Icons.keyboard_arrow_up, onTap: onUp),
        _StepBtn(icon: Icons.keyboard_arrow_down, onTap: onDown),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _kBg,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, size: 16, color: _kGreen),
      ),
    );
  }
}

class _UnitPills extends StatelessWidget {
  final FreqUnit selected;
  final ValueChanged<FreqUnit> onSelected;

  const _UnitPills({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: FreqUnit.values.map((unit) {
        final active = unit == selected;
        return GestureDetector(
          onTap: () => onSelected(unit),
          child: Container(
            margin: const EdgeInsets.only(right: 3),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF0A1A0A) : Colors.transparent,
              border: Border.all(
                color: active ? _kGreen : _kGreenVeryDim,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              unit.label,
              style: TextStyle(
                fontFamily: 'Courier New',
                fontSize: 9,
                color: active ? _kGreen : _kGreenVeryDim,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------

class _FrequencyKeypadDialog extends StatefulWidget {
  final double initialHz;
  final FreqUnit initialUnit;
  final ValueChanged<FreqUnit> onUnitChanged;

  const _FrequencyKeypadDialog({
    required this.initialHz,
    required this.initialUnit,
    required this.onUnitChanged,
  });

  @override
  State<_FrequencyKeypadDialog> createState() => _FrequencyKeypadDialogState();
}

class _FrequencyKeypadDialogState extends State<_FrequencyKeypadDialog> {
  late FreqUnit _unit;
  late String _input;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _input = (widget.initialHz / _unit.divisor).toStringAsFixed(1);
  }

  double? get _parsedHz {
    final v = double.tryParse(_input);
    if (v == null || v < 0) return null;
    return (v * _unit.divisor).clamp(0.0, 100e9);
  }

  void _press(String d) {
    setState(() {
      if (d == '.' && _input.contains('.')) return;
      if ((_input == '0' || _input.isEmpty) && d != '.') {
        _input = d;
      } else {
        _input += d;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_input.length > 1) {
        _input = _input.substring(0, _input.length - 1);
      } else {
        _input = '0';
      }
    });
  }

  void _setUnit(FreqUnit unit) {
    final hz = _parsedHz;
    setState(() {
      _unit = unit;
      if (hz != null) _input = (hz / unit.divisor).toStringAsFixed(1);
    });
    widget.onUnitChanged(unit);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _parsedHz != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      title: const Text(
        'TUNE FREQUENCY',
        style: TextStyle(
          color: _kGreen,
          fontSize: 13,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kBg,
                border: Border.all(
                  color: valid ? _kBorder : Colors.red.shade900,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _input.isEmpty ? '0' : _input,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _kGreen,
                  letterSpacing: 2,
                  shadows: [Shadow(color: _kGreenDim, blurRadius: 6)],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: FreqUnit.values.map((unit) {
                final active = _unit == unit;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _setUnit(unit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF0A1A0A) : Colors.transparent,
                        border: Border.all(
                          color: active ? _kGreen : _kGreenVeryDim,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        unit.label,
                        style: TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 12,
                          color: active ? _kGreen : _kGreenVeryDim,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _buildNumpad(),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: valid ? () => Navigator.pop(context, _parsedHz) : null,
          child: const Text('TUNE'),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    const rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Row(
          children: row.map((label) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AspectRatio(
                  aspectRatio: 1.8,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: _kGreenVeryDim),
                      foregroundColor: _kGreen,
                      backgroundColor: _kBg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed:
                        label == '⌫' ? _backspace : () => _press(label),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
