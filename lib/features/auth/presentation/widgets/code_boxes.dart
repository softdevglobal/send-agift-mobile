import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// A one-time code as a row of boxes, one digit each. A single hidden field
/// takes the typing, so paste and the keyboard's code suggestion fill every
/// box at once.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.hasError = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String>? onCompleted;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final _focus = FocusNode();

  /// The full code last reported, so a focus change does not report it again.
  String? _reported;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    final code = widget.controller.text;
    if (code.length < widget.length) {
      _reported = null;
    } else if (code != _reported) {
      _reported = code;
      widget.onCompleted?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: widget.enabled ? _focus.requestFocus : null,
      child: Stack(
        children: [
          // Takes the input; kept on screen (but invisible) so autofill and
          // paste work.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const Key('code-input'),
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                enabled: widget.enabled,
                showCursor: false,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Box(
                      digit: i < code.length ? code[i] : null,
                      active:
                          _focus.hasFocus &&
                          (i == code.length ||
                              (i == widget.length - 1 &&
                                  code.length == widget.length)),
                      error: widget.hasError,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.error});

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    final border = error
        ? AppColors.destructive
        : active
        ? AppColors.foreground
        : filled
        ? AppColors.foreground.withValues(alpha: 0.45)
        : AppColors.boxBorder;
    return AspectRatio(
      aspectRatio: 0.82,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.boxTrack : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusBox),
          border: Border.all(color: border, width: active ? 2.5 : 1.5),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            digit ?? '',
            key: ValueKey(digit),
            style: AppTypography.display(26),
          ),
        ),
      ),
    );
  }
}
