import 'package:intl/intl.dart';

/// Currency helpers mirroring the web frontend's `lib/money.ts`.
///
/// The API stores prices in minor units (cents), so every display path has to
/// scale by the currency's fraction digits before formatting.
class Money {
  Money._();

  static const Set<String> _zeroDecimalCurrencies = {'JPY', 'KRW', 'VND'};

  static int fractionDigits(String currency) {
    return _zeroDecimalCurrencies.contains(currency.toUpperCase()) ? 0 : 2;
  }

  static double minorToMajor(int minor, String currency) {
    return minor / _pow10(fractionDigits(currency));
  }

  static int majorToMinor(double major, String currency) {
    return (major * _pow10(fractionDigits(currency))).round();
  }

  /// Currency symbols shared by several currencies. `$` alone covers USD, AUD,
  /// NZD, CAD and SGD, so rendering a bare `$25.00` tells a cross-border
  /// customer nothing about what they are actually being charged.
  static const Set<String> _ambiguousSymbols = {r'$', '¥', 'Rs', '₨', 'kr'};

  /// Formats a minor-unit amount, e.g. `2800` + `GBP` -> `£28.00`.
  ///
  /// Currencies whose symbol is unique keep it; ones sharing a symbol are
  /// rendered with the ISO code instead (`AUD 25.00`). The rule is generic
  /// rather than a symbol table because admins can add countries. And
  /// therefore currencies. At any time.
  static String format(int minorAmount, String currency) {
    final code = currency.isEmpty ? 'USD' : currency.toUpperCase();
    final digits = fractionDigits(code);
    final value = minorToMajor(minorAmount, code);

    try {
      final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
      if (_ambiguousSymbols.contains(symbol)) {
        return NumberFormat.currency(
          name: code,
          symbol: '$code ',
          decimalDigits: digits,
        ).format(value);
      }
      return NumberFormat.simpleCurrency(name: code, decimalDigits: digits)
          .format(value);
    } catch (_) {
      return '${value.toStringAsFixed(digits)} $code';
    }
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
