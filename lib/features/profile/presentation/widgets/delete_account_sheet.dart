import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/account_repository.dart';

/// How deleting ended, for the account screen to act on.
enum DeleteAccountResult {
  /// The account is gone and this device is signed out.
  deleted,

  /// A gift is still on its way; the customer chose to look at their orders.
  viewOrders,
}

/// Asks before deleting the account, says plainly what goes and what the law
/// makes us keep, and makes the customer type DELETE so it cannot happen by
/// a stray tap. Deleting happens inside the sheet.
Future<DeleteAccountResult?> showDeleteAccountSheet(
  BuildContext context, {
  required int? points,
}) {
  return showModalBottomSheet<DeleteAccountResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.radius2xl),
      ),
    ),
    builder: (_) => _DeleteAccountSheet(points: points),
  );
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet({required this.points});

  final int? points;

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  static const _word = 'DELETE';

  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  /// The server refused because a gift is still on its way.
  bool _activeOrders = false;

  bool get _typed => _confirm.text.trim().toUpperCase() == _word;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || !_typed) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = true;
      _error = null;
      _activeOrders = false;
    });
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      await ref.read(authProvider.notifier).forgetDeletedAccount();
      if (mounted) Navigator.of(context).pop(DeleteAccountResult.deleted);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _activeOrders = error.code == 'ACTIVE_ORDERS';
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.points ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        12,
        AppTheme.gutter,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.boxBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  size: 30,
                  color: AppColors.destructive,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete your account?',
              textAlign: TextAlign.center,
              style: AppTypography.display(24),
            ),
            const SizedBox(height: 6),
            Text(
              'This is permanent and cannot be undone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _Point(
              icon: Icons.delete_outline_rounded,
              color: AppColors.destructive,
              text:
                  'Your name, email, phone, photo, saved addresses, recipients '
                  'and saved gifts are deleted.',
            ),
            _Point(
              icon: Icons.stars_rounded,
              color: AppColors.purple,
              text: points > 0
                  ? 'Your $points points are lost. They cannot be moved or '
                        'paid out.'
                  : 'Any points you have are lost.',
            ),
            _Point(
              icon: Icons.receipt_long_rounded,
              color: AppColors.accentForeground,
              text:
                  'Order and payment records are kept as the law requires, '
                  'with nothing personal left in them.',
            ),
            _Point(
              icon: Icons.logout_rounded,
              color: AppColors.mutedForeground,
              text:
                  'You are signed out on every device. You can make a new '
                  'account later with the same email.',
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                text: 'Type ',
                children: [
                  TextSpan(
                    text: _word,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                  const TextSpan(text: ' to confirm'),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delete-account-confirm'),
              controller: _confirm,
              enabled: !_busy,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: _word),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  _activeOrders
                      ? 'A gift is still on its way. You can delete your '
                            'account once it is delivered or cancelled.'
                      : _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF451A03),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (_activeOrders)
              ElevatedButton.icon(
                key: const Key('delete-account-view-orders'),
                onPressed: () =>
                    Navigator.of(context).pop(DeleteAccountResult.viewOrders),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('View my orders'),
              )
            else
              ElevatedButton.icon(
                key: const Key('delete-account-submit'),
                onPressed: _busy || !_typed ? null : _delete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text('Delete my account'),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Keep my account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
