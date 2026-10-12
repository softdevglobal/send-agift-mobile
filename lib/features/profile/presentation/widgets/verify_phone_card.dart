import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/account_repository.dart';
import 'address_form_sheet.dart' show errorMessage;

/// Proves the saved phone with a texted code, so the customer can sign in
/// with it. Hidden until a phone is saved.
class VerifyPhoneCard extends ConsumerStatefulWidget {
  const VerifyPhoneCard({super.key});

  @override
  ConsumerState<VerifyPhoneCard> createState() => _VerifyPhoneCardState();
}

class _VerifyPhoneCardState extends ConsumerState<VerifyPhoneCard> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send(String phone) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).requestPhoneCode(phone);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error, 'Could not send a code.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String phone) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .verifyPhone(phone: phone, code: _code.text.trim());
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Phone verified.')));
    } catch (error) {
      if (mounted) {
        setState(() => _error = errorMessage(error, 'That code did not work.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final phone = auth.phone;
    final theme = Theme.of(context);

    if (auth.phoneVerified) {
      return const Row(
        key: Key('phone-verified'),
        children: [
          Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Phone verified. You can sign in with it.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ],
      );
    }
    if (phone == null) return const SizedBox.shrink();

    return Container(
      key: const Key('verify-phone'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify $phone to sign in with a text code.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (_sent)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('verify-phone-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: '6-digit code'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  key: const Key('verify-phone-confirm'),
                  onPressed: _busy || _code.text.length != 6
                      ? null
                      : () => _confirm(phone),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            )
          else
            OutlinedButton(
              key: const Key('verify-phone-send'),
              onPressed: _busy ? null : () => _send(phone),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Text me a code'),
            ),
          if (_sent)
            TextButton(
              onPressed: _busy ? null : () => _send(phone),
              child: const Text('Send a new code'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
