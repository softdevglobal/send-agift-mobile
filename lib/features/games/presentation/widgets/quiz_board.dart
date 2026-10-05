import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/quiz_game.dart';
import '../game_controls.dart';

/// The quiz board: one question at a time with a countdown. The answer is
/// locked in straight away. Right or wrong is only known to the server, and
/// shows in the score once the quiz is submitted.
class QuizBoard extends StatefulWidget {
  const QuizBoard({required this.game, required this.controls, super.key});

  final QuizGame game;
  final GameControls controls;

  @override
  State<QuizBoard> createState() => _QuizBoardState();
}

class _QuizBoardState extends State<QuizBoard> {
  static const _tick = 50;

  /// Time spent on the current question. It only counts up while the game
  /// is active, so the menu pauses it.
  int _elapsedMs = 0;
  Timer? _ticker;
  int? _locked;

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    _locked = null;
    _elapsedMs = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: _tick), (_) {
      final q = widget.game.current;
      if (q == null || !mounted || _locked != null) return;
      if (!widget.controls.active) return;
      _elapsedMs += _tick;
      if (_elapsedMs >= q.timeLimitMs) {
        _choose(-1);
      } else {
        setState(() {});
      }
    });
  }

  void _choose(int option) {
    if (_locked != null || !widget.controls.active) return;
    HapticFeedback.selectionClick();
    widget.game.answer(option, _elapsedMs);
    setState(() => _locked = option);
    // A beat to see the choice register, then the next question.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      widget.controls.onChanged();
      if (!widget.game.isOver) setState(_startQuestion);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    if (game.questions.isEmpty) {
      return const Center(
        child: Text(
          'This quiz has no questions.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    final q = game.current ?? game.questions.last;
    final shown = game.isOver ? game.questions.length - 1 : game.index;
    final left = game.isOver
        ? 0.0
        : (1 - _elapsedMs / q.timeLimitMs).clamp(0.0, 1.0);
    final seconds = (left * q.timeLimitMs / 1000).ceil();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'QUESTION ${shown + 1} OF ${game.questions.length}',
            style: AppTypography.eyebrow.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: left,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: left < 0.25 ? const Color(0xFFF87171) : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${seconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(q.prompt, style: AppTypography.display(24, color: Colors.white)),
          const SizedBox(height: 20),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _locked == i
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white54),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _locked == null ? () => _choose(i) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Text(
                        q.options[i],
                        style: TextStyle(
                          color: _locked == i ? Colors.black87 : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_locked == -1)
            const Text(
              "Time's up",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
