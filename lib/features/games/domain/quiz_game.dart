import 'game_engine.dart';

/// One question as the device receives it: no answer.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.timeLimitMs,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    return QuizQuestion(
      prompt: json['prompt'] as String? ?? '',
      options: options is List
          ? options.whereType<String>().toList(growable: false)
          : const [],
      timeLimitMs: readConfigInt(json, 'time_limit_ms') > 0
          ? readConfigInt(json, 'time_limit_ms')
          : 20000,
    );
  }

  final String prompt;
  final List<String> options;
  final int timeLimitMs;
}

/// The quiz: answer each question before its timer runs out.
///
/// The device never learns which answers are right. The server keeps them
/// and scores the answers itself. So this engine only records what was
/// chosen and how long it took, as `question:option:ms` (option -1
/// when the time ran out). Its [score] is progress, not points.
class QuizGame implements UnscoredGame {
  QuizGame({required Map<String, dynamic> config})
    : questions = _questions(config);

  static List<QuizQuestion> _questions(Map<String, dynamic> config) {
    final raw = config['questions'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList(growable: false);
  }

  final List<QuizQuestion> questions;
  final List<String> _moves = [];

  /// The question on screen, or [questions.length] once done.
  int get index => _moves.length;

  QuizQuestion? get current => isOver ? null : questions[index];

  /// Records an answer to the current question. [option] -1 means the time
  /// ran out; [elapsedMs] is clamped to the question's limit.
  void answer(int option, int elapsedMs) {
    final q = current;
    if (q == null) return;
    final ms = elapsedMs.clamp(0, q.timeLimitMs);
    final chosen = option >= 0 && option < q.options.length ? option : -1;
    _moves.add('$index:$chosen:$ms');
  }

  int get answered => _moves.where((m) => !m.contains(':-1:')).length;

  @override
  int get score => answered;

  @override
  List<String> get moves => List.unmodifiable(_moves);

  @override
  bool get isOver => _moves.length >= questions.length;

  @override
  bool get hasProgress => _moves.isNotEmpty;
}
