import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/account_repository.dart';
import '../widgets/account_visuals.dart';
import '../widgets/address_form_sheet.dart' show errorMessage;

/// Changing the password the customer signs in with. A gift recipient still
/// on the temporary password from their gift email lands here from the
/// prompt on the Account tab.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _current.text;
    final next = _next.text;
    String? problem;
    if (current.isEmpty) {
      problem = 'Enter your current password.';
    } else if (next.length < 8) {
      problem = 'Your new password needs at least 8 characters.';
    } else if (next != _confirm.text) {
      problem = "The new passwords don't match.";
    } else if (next == current) {
      problem = 'Choose a password different from the current one.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(currentPassword: current, newPassword: next);
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Password changed.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error, 'Could not change your password.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final temporary = ref.watch(
      authProvider.select((auth) => auth.passwordChangeRequired),
    );

    Widget field(
      TextEditingController controller,
      String label,
      String autofill,
      Key key,
    ) {
      return TextField(
        key: key,
        controller: controller,
        obscureText: _obscure,
        enabled: !_saving,
        autofillHints: [autofill],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              8,
              AppTheme.gutter,
              32,
            ),
            children: [
              BrandHero(
                icon: Icons.key_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temporary ? 'Make it yours' : 'Keep it safe',
                      style: AppTypography.display(24, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      temporary
                          ? "You're signed in with the temporary password from "
                                'your gift email. Choose your own so only you '
                                'can get in.'
                          : 'Use at least 8 characters you don’t use anywhere '
                                'else.',
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
              field(
                _current,
                temporary ? 'Temporary password' : 'Current password',
                AutofillHints.password,
                const Key('password-current'),
              ),
              const SizedBox(height: 12),
              field(
                _next,
                'New password',
                AutofillHints.newPassword,
                const Key('password-new'),
              ),
              const SizedBox(height: 12),
              field(
                _confirm,
                'Confirm new password',
                AutofillHints.newPassword,
                const Key('password-confirm'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('password-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
