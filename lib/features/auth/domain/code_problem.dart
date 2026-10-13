import '../../../core/errors/app_exception.dart';

/// What went wrong with a one-time code, in words a person can act on. The
/// server's own text ("wait a minute before asking for another code") says
/// what, but not what to do next.
class CodeProblem {
  const CodeProblem(this.message, {this.isWait = false});

  final String message;

  /// A code was just sent: go to entering it, and start the resend timer.
  final bool isWait;

  static CodeProblem of(Object error, String fallback) {
    final text = error is AppException ? error.message : '';
    final m = text.toLowerCase();
    final status = error is AppException ? error.statusCode : null;

    if (RegExp(r'wait a minute|before asking for another').hasMatch(m)) {
      return const CodeProblem(
        'Hold on, a code is already on its way. Check your inbox and spam '
        'folder, or ask for a fresh one when the timer runs out.',
        isWait: true,
      );
    }
    if (m.contains('too many codes')) {
      return const CodeProblem(
        "That's all the codes for today. Try again tomorrow, or sign in with "
        'your password instead.',
      );
    }
    if (m.contains('too many wrong')) {
      return const CodeProblem(
        "Let's take a breather. A few codes didn't match, so this is paused to "
        'keep your account safe. Try again tomorrow or contact support.',
      );
    }
    if (m.contains('expired')) {
      return const CodeProblem(
        'That code has run out. Codes last 5 minutes, so send a fresh one and '
        'enter it straight away.',
      );
    }
    if (RegExp(r'not right|did not match|incorrect').hasMatch(m) ||
        status == 422) {
      return const CodeProblem(
        "That code didn't match. Double-check the 6 digits, or ask for a new "
        'one.',
      );
    }
    return CodeProblem(text.isEmpty ? fallback : text);
  }
}
