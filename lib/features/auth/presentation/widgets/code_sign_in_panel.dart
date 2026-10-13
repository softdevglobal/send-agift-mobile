import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/dial_codes.dart';
import '../../data/auth_controller.dart';
import '../../domain/code_problem.dart';
import '../../domain/code_signup.dart';
import 'auth_header_parts.dart';
import 'auth_scaffold.dart';
import 'box_toggle.dart';

/// Sign in with a 6-digit code sent by text or email. This takes the phone
/// or email and sends the code; the code is entered on its own screen. A
/// phone or email no account uses yet comes back as a [CodeSignup] to finish
/// on the sign-up screen.
class CodeSignInPanel extends ConsumerStatefulWidget {
  const CodeSignInPanel({
    super.key,
    required this.onSignedIn,
    required this.onNeedsSignup,
  });

  final VoidCallback onSignedIn;
  final ValueChanged<CodeSignup> onNeedsSignup;

  @override
  ConsumerState<CodeSignInPanel> createState() => _CodeSignInPanelState();
}

class _CodeSignInPanelState extends ConsumerState<CodeSignInPanel> {
  static const _resendSeconds = 60;

  final _destination = TextEditingController();

  CodeChannel _channel = CodeChannel.sms;
  String _dialIso = defaultDialIso;
  bool _busy = false;
  String? _error;

  /// The last code sent, so coming back and tapping again within the
  /// server's one-minute wait reopens it instead of asking for another.
  ({CodeChannel channel, String destination, DateTime at})? _last;

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  String get _dial => dialCodes
      .firstWhere((d) => d.iso2 == _dialIso, orElse: () => dialCodes.first)
      .dial;

  /// What the code is sent to, as the API expects it.
  String get _target => _channel == CodeChannel.sms
      ? '$_dial ${_destination.text.trim()}'
      : _destination.text.trim();

  void _switchTo(CodeChannel channel) => setState(() {
    _channel = channel;
    _destination.clear();
    _error = null;
  });

  Future<void> _send() async {
    final value = _destination.text.trim();
    String? problem;
    if (_channel == CodeChannel.email &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      problem = 'Enter a valid email.';
    } else if (_channel == CodeChannel.sms &&
        value.replaceAll(RegExp(r'\D'), '').length < 7) {
      problem = 'Enter your phone number.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final target = _target;
    final last = _last;
    if (last != null &&
        last.channel == _channel &&
        last.destination == target) {
      final left =
          _resendSeconds - DateTime.now().difference(last.at).inSeconds;
      if (left > 0) return _openVerify(target, left);
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestLoginCode(channel: _channel, destination: target);
      if (!mounted) return;
      _last = (channel: _channel, destination: target, at: DateTime.now());
      setState(() => _busy = false);
      await _openVerify(target, _resendSeconds);
    } catch (error) {
      if (!mounted) return;
      final problem = CodeProblem.of(error, 'Could not send a code.');
      if (problem.isWait) {
        // One was sent a moment ago: go and enter it rather than refuse.
        setState(() => _busy = false);
        await _openVerify(target, _resendSeconds);
        return;
      }
      setState(() => _error = problem.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openVerify(String destination, int resendIn) async {
    final result = await context.push<Object>(
      AppRoutes.verifyCode,
      extra: CodeTarget(
        channel: _channel,
        destination: destination,
        resendIn: resendIn,
      ),
    );
    if (!mounted) return;
    if (result == true) widget.onSignedIn();
    if (result is CodeSignup) widget.onNeedsSignup(result);
  }

  @override
  Widget build(BuildContext context) {
    final sms = _channel == CodeChannel.sms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoxToggle(
          options: const [
            BoxToggleOption(
              'Phone',
              icon: Icons.smartphone_rounded,
              key: Key('code-channel-sms'),
            ),
            BoxToggleOption(
              'Email',
              icon: Icons.mail_outline_rounded,
              key: Key('code-channel-email'),
            ),
          ],
          selected: sms ? 0 : 1,
          onChanged: _busy
              ? null
              : (index) =>
                    _switchTo(index == 0 ? CodeChannel.sms : CodeChannel.email),
        ),
        const SizedBox(height: 18),
        Text(
          sms ? 'Phone number' : 'Email',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 7),
        if (sms)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                child: DropdownButtonFormField<String>(
                  key: const Key('code-dial'),
                  initialValue: _dialIso,
                  isExpanded: true,
                  selectedItemBuilder: (_) => [
                    for (final code in dialCodes) Text(code.dial),
                  ],
                  items: [
                    for (final code in dialCodes)
                      DropdownMenuItem(
                        value: code.iso2,
                        child: Text(
                          '${code.dial}  ${code.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _dialIso = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('code-destination'),
                  controller: _destination,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.send,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  decoration: const InputDecoration(hintText: '77 123 4567'),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ],
          )
        else
          TextField(
            key: const Key('code-destination'),
            controller: _destination,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            ),
            onSubmitted: (_) => _send(),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthAlert(message: _error!),
        ],
        const SizedBox(height: 22),
        AuthPrimaryButton(
          key: const Key('code-submit'),
          label: 'Send code',
          loading: _busy,
          onPressed: _busy ? null : _send,
        ),
      ],
    );
  }
}
