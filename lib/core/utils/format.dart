import 'package:intl/intl.dart';

import '../../l10n/strings.dart';

final _money = NumberFormat('#,##0.00', 'en_US');

/// Dates follow the app language (Malay month names in Bahasa Melayu).
DateFormat dateFormat(String pattern) => DateFormat(
  pattern,
  AppStrings.language == AppStrings.malay ? AppStrings.malay : null,
);

/// Money is stored in sen (integer). 1850 -> "RM 18.50".
String formatRM(int sen) => sen < 0
    ? '-RM ${_money.format(-sen / 100)}'
    : 'RM ${_money.format(sen / 100)}';

/// 1850 -> "18.50" (for pre-filling text fields).
String senToInput(int sen) => (sen / 100).toStringAsFixed(2);

/// Parses "18.5", "18.50" or "RM 18.50" into sen without floating-point
/// rounding. Returns null when the text is not a valid amount.
int? parseRMToSen(String input) {
  final text = input
      .trim()
      .replaceFirst(RegExp(r'^RM\s*', caseSensitive: false), '')
      .replaceAll(',', '');
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
  if (m == null) return null;
  final cents = (m[2] ?? '').padRight(2, '0');
  return int.parse(m[1]!) * 100 + int.parse(cents);
}

String formatDate(DateTime d) => dateFormat('d MMM yyyy').format(d);
String formatDateTime(DateTime d) => dateFormat('d MMM yyyy, h:mm a').format(d);
String formatTime(DateTime d) => dateFormat('h:mm a').format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] (default: today) until [date].
/// Negative when [date] is in the past.
int daysUntil(DateTime date, {DateTime? from}) {
  final start = from ?? DateTime.now();
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
}

/// "Expired 2 days ago", "Expires today", "Expires in 3 days".
String expiryLabel(DateTime date, {DateTime? from}) {
  final days = daysUntil(date, from: from);
  if (days < -1) {
    return AppStrings.tr('Expired {days} days ago', {'days': -days});
  }
  if (days == -1) return AppStrings.tr('Expired yesterday');
  if (days == 0) return AppStrings.tr('Expires today');
  if (days == 1) return AppStrings.tr('Expires tomorrow');
  return AppStrings.tr('Expires in {days} days', {'days': days});
}

/// Short receipt number from a Firestore ID, e.g. "A1B2C3D4".
String receiptNo(String orderId) => orderId.length <= 8
    ? orderId.toUpperCase()
    : orderId.substring(0, 8).toUpperCase();
