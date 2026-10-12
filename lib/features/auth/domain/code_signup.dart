/// How a one-time sign-in code is sent; the API's `channel`.
enum CodeChannel {
  sms,
  email;

  static CodeChannel parse(Object? value) =>
      value == 'email' ? CodeChannel.email : CodeChannel.sms;
}

/// Someone new who proved a phone or email with a sign-in code. Registering
/// with [signupToken] marks that phone or email as verified.
class CodeSignup {
  const CodeSignup({
    required this.signupToken,
    required this.channel,
    required this.destination,
  });

  final String signupToken;
  final CodeChannel channel;

  /// The phone (normalised, e.g. `+94771234567`) or email the code went to.
  final String destination;

  factory CodeSignup.fromJson(Map<String, dynamic> json) => CodeSignup(
    signupToken: json['signup_token'] as String? ?? '',
    channel: CodeChannel.parse(json['channel']),
    destination: json['destination'] as String? ?? '',
  );
}

/// A code that was just sent: where to, and how long until another may go.
class CodeTarget {
  const CodeTarget({
    required this.channel,
    required this.destination,
    this.resendIn = 60,
  });

  final CodeChannel channel;

  /// The phone or email exactly as it was sent to the API.
  final String destination;

  /// Seconds before the server takes another send.
  final int resendIn;
}
