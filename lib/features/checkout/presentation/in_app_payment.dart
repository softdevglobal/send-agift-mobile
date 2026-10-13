import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/checkout_repository.dart';

/// The publishable key the Stripe SDK was last set up with.
String? _appliedKey;

/// How paying in the app ended.
enum InAppPaymentOutcome {
  /// Stripe took the card. The order turns paid on the server a moment later.
  paid,

  /// The customer closed the sheet. The order still waits for payment.
  cancelled,

  /// Card payments are not set up on the server.
  unavailable,
}

/// Takes an order's payment inside the app with Stripe's payment sheet, so the
/// customer never leaves for a web page. Throws [AppException] when Stripe
/// declines or the sheet cannot open.
Future<InAppPaymentOutcome> payOrderInApp(WidgetRef ref, String orderId) async {
  final repository = ref.read(checkoutRepositoryProvider);
  final sheet = await repository.startInAppPayment(orderId);
  if (sheet == null) return InAppPaymentOutcome.unavailable;

  try {
    // Stripe's own getter throws until a key is set, so remember it here.
    if (_appliedKey != sheet.publishableKey) {
      Stripe.publishableKey = sheet.publishableKey;
      await Stripe.instance.applySettings();
      _appliedKey = sheet.publishableKey;
    }
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: sheet.clientSecret,
        merchantDisplayName: 'SendAGift',
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: AppColors.primary),
          primaryButton: PaymentSheetPrimaryButtonAppearance(
            colors: PaymentSheetPrimaryButtonTheme(
              light: PaymentSheetPrimaryButtonThemeColors(
                background: AppColors.primary,
                text: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  } on StripeException catch (error) {
    debugPrint(
      'stripe payment sheet: ${error.error.code} ${error.error.message}',
    );
    if (error.error.code == FailureCode.Canceled) {
      return InAppPaymentOutcome.cancelled;
    }
    throw AppException(
      error.error.localizedMessage ??
          error.error.message ??
          'The payment did not go through.',
    );
  } on AppException {
    rethrow;
  } catch (error) {
    // Anything else from the Stripe SDK (its setup, the platform channel):
    // say so instead of leaving the screen stuck half way.
    debugPrint('stripe payment sheet failed: $error');
    throw const AppException('Could not open the payment. Please try again.');
  }

  // Stripe has the money. Its webhook marks the order paid; nudge the server
  // in case the webhook is slow, so the order page updates straight away.
  for (final seconds in const [0, 1, 2, 4]) {
    if (seconds > 0) await Future<void>.delayed(Duration(seconds: seconds));
    if (await repository.syncPayment(orderId)) break;
  }
  return InAppPaymentOutcome.paid;
}
