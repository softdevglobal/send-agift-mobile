import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../data/auth_controller.dart';
import '../../domain/code_signup.dart';
import '../widgets/auth_header_parts.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/code_boxes.dart';

/// Entering the one-time code sent from the sign-in screen. Pops with `true`
/// once signed in, a [CodeSignup] when nobody uses that phone or email yet,
/// or nothing when the customer goes back to change it.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.target});

  final CodeTarget target;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _code = TextEditingController();

  bool _busy = false;
  int _wait = 0;
  Timer? _timer;
  String? _error;
  String? _notice;

  CodeTarget get _target => widget.target;
  bool get _sms => _target.channel == CodeChannel.sms;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _countdown(_target.resendIn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    _wait = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestLoginCode(
            channel: _target.channel,
            destination: _target.destination,
          );
      if (!mounted) return;
      _code.clear();
      setState(() => _notice = 'A new code is on its way.');
      _countdown(60);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send a code.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _code.text;
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final signup = await ref
          .read(authProvider.notifier)
          .verifyLoginCode(
            channel: _target.channel,
            destination: _target.destination,
            code: code,
          );
      if (!mounted) return;
      context.pop<Object>(signup ?? true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That code did not work.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground);

    return AuthScaffold(
      title: 'Check your ${_sms ? 'phone' : 'email'}',
      titleWidget: AuthHeadline(
        lead: 'Check your ',
        accent: _sms ? 'phone' : 'email',
      ),
      subtitle:
          'We sent a 6-digit code to ${_target.destination}. It works for '
          '5 minutes.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: CodeBoxes(
              controller: _code,
              enabled: !_busy,
              hasError: _error != null,
              // The last digit signs in, no extra tap needed.
              onCompleted: (_) => _verify(),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Didn't get it?", style: muted),
                TextButton(
                  key: const Key('code-resend'),
                  onPressed: _wait > 0 || _busy ? null : _resend,
                  child: Text(
                    _wait > 0 ? 'Resend in ${_wait}s' : 'Resend code',
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            AuthAlert(message: _error!),
          ] else if (_notice != null) ...[
            const SizedBox(height: 8),
            Text(_notice!, style: muted),
          ],
          const SizedBox(height: 22),
          FadeSlideIn(
            delay: const Duration(milliseconds: 220),
            child: AuthPrimaryButton(
              key: const Key('code-verify'),
              label: 'Sign in',
              loading: _busy,
              onPressed: _busy || _code.text.length != 6 ? null : _verify,
            ),
          ),
        ],
      ),
      footer: Center(
        child: TextButton.icon(
          key: const Key('code-change'),
          onPressed: _busy ? null : () => context.pop(),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(_sms ? 'Change number' : 'Change email'),
        ),
      ),
    );
  }
}
