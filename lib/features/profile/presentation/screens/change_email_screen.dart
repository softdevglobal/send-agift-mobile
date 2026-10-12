import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/account_repository.dart';
import '../widgets/account_visuals.dart';
import '../widgets/address_form_sheet.dart' show errorMessage;

enum _Step { form, code, done }

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// Changing the email the customer signs in with. The password is checked
/// first and a code goes to the NEW address, so the change only happens once
/// its owner has proved it. The old address gets a link that undoes it.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _newEmail = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  _Step _step = _Step.form;
  bool _sending = false;
  bool _saving = false;
  bool _obscure = true;
  String? _error;
  String? _notice;
  EmailChangeResult? _result;

  @override
  void initState() {
    super.initState();
    _newEmail.addListener(_refresh);
    _password.addListener(_refresh);
    _code.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _newEmail.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _formProblem() {
    final email = _newEmail.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid new email address.';
    }
    final current = ref.read(authProvider).email ?? '';
    if (email.toLowerCase() == current.trim().toLowerCase()) {
      return 'That is already your email.';
    }
    if (_password.text.isEmpty) return 'Enter your current password.';
    return null;
  }

  Future<void> _sendCode() async {
    final problem = _formProblem();
    if (problem != null) {
      setState(() {
        _error = problem;
        _notice = null;
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    final email = _newEmail.text.trim();
    try {
      await ref
          .read(accountRepositoryProvider)
          .requestEmailChange(newEmail: email, currentPassword: _password.text);
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _code.clear();
        // The server answers the same whether or not the address can be
        // used, so this cannot promise a code is coming.
        _notice =
            'If $email can be used, a 6-digit code is on its way. If '
            'nothing arrives in a few minutes it may already belong to '
            'another account.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error, 'Could not send a code.'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .confirmEmailChange(_code.text);
      // Every older token stopped working; this one keeps the app signed in.
      await ref.read(authProvider.notifier).replaceToken(result.token);
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.done;
        _password.clear();
        _code.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = errorMessage(error, 'Could not change your email.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startOver() => setState(() {
    _step = _Step.form;
    _code.clear();
    _error = null;
    _notice = null;
  });

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider.select((auth) => auth.email)) ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Change email')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            8,
            AppTheme.gutter,
            32,
          ),
          children: [
            BrandHero(
              icon: Icons.alternate_email_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign-in email',
                    style: AppTypography.display(24, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You sign in with $email. To change it we check your '
                    'password, then email a code to the new address.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...switch (_step) {
              _Step.form => _form(),
              _Step.code => _codeStep(),
              _Step.done => _done(),
            },
          ],
        ),
      ),
    );
  }

  Widget _messages() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          _error!,
          style: const TextStyle(color: AppColors.destructive),
        ),
      );
    }
    if (_notice != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          _notice!,
          style: const TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _spinner() => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  List<Widget> _form() => [
    TextField(
      key: const Key('email-new'),
      controller: _newEmail,
      enabled: !_sending,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'New email',
        prefixIcon: Icon(Icons.mail_outline_rounded),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const Key('email-password'),
      controller: _password,
      enabled: !_sending,
      obscureText: _obscure,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: 'Current password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'Changing your email signs you out of every other device and puts '
      'prizes and gift points on hold for a few days. You can change it '
      'twice every 30 days.',
      style: TextStyle(
        color: AppColors.mutedForeground,
        fontSize: 12,
        height: 1.4,
      ),
    ),
    _messages(),
    const SizedBox(height: 22),
    FilledButton(
      key: const Key('email-send-code'),
      onPressed: _sending || _newEmail.text.isEmpty || _password.text.isEmpty
          ? null
          : _sendCode,
      child: _sending ? _spinner() : const Text('Email me a code'),
    ),
  ];

  List<Widget> _codeStep() => [
    TextField(
      key: const Key('email-code'),
      controller: _code,
      enabled: !_saving,
      autofocus: true,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 22, letterSpacing: 10),
      decoration: const InputDecoration(
        labelText: '6-digit code',
        hintText: '000000',
      ),
    ),
    _messages(),
    const SizedBox(height: 22),
    FilledButton(
      key: const Key('email-confirm'),
      onPressed: _saving || _sending || _code.text.length != 6
          ? null
          : _confirm,
      child: _saving ? _spinner() : const Text('Confirm new email'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: _sending || _saving ? null : _sendCode,
      child: _sending ? _spinner() : const Text('Send a new code'),
    ),
    TextButton(
      onPressed: _sending || _saving ? null : _startOver,
      child: const Text('Use a different email'),
    ),
  ];

  List<Widget> _done() {
    final result = _result!;
    final until = result.redemptionLockedUntil;
    final hold = until == null
        ? 'for a few days'
        : 'until ${until.day} ${_months[until.month - 1]}';
    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.mutedForeground)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
    return [
      Row(
        key: const Key('email-changed'),
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Email changed to ${result.email}.',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      point('You are still signed in here. Every other device was signed out.'),
      point(
        'We emailed your old address a link that undoes this for 7 days, in '
        'case it wasn’t you.',
      ),
      point('Prizes and gift points are on hold $hold as a precaution.'),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Done'),
      ),
    ];
  }
}
