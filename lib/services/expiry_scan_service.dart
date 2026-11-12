import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// AI expiry-date scanner (design doc section 8). Google ML Kit runs on the
/// phone, is free and works without internet.
class ExpiryScanService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Opens the camera, reads the text on the pack, returns the expiry date
  /// (or null if the photo was cancelled or no date was found).
  Future<DateTime?> scanExpiryDate() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600, // smaller photo = faster OCR, still sharp enough
    );
    if (photo == null) return null; // staff cancelled
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(photo.path),
    );
    return parseExpiryDate(result.text);
  }

  Future<void> dispose() => _recognizer.close();
}

const _months = {
  'JAN': 1,
  'FEB': 2,
  'MAR': 3,
  'MAC': 3,
  'APR': 4,
  'MAY': 5,
  'MEI': 5,
  'JUN': 6,
  'JUL': 7,
  'AUG': 8,
  'OGO': 8,
  'SEP': 9,
  'OCT': 10,
  'OKT': 10,
  'NOV': 11,
  'DEC': 12,
  'DIS': 12,
};

final _dayFirst = RegExp(
  r'(?<!\d)(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})(?!\d)',
);
final _yearFirst = RegExp(
  r'(?<!\d)(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?!\d)',
);
final _monthName = RegExp(
  r'(?<!\d)(\d{1,2})[\s\-./]{0,2}(' +
      _months.keys.join('|') +
      r')[A-Z]*[\s\-./]{0,2}(\d{4}|\d{2})(?!\d)',
);
final _monthYear = RegExp(r'(?<![\d/.\-])(\d{1,2})[/\-.](\d{4})(?!\d)');
final _expiryWord = RegExp(
  r'\b(?:EXP[A-Z.]*|BEST\s*BEFORE|BB(?![A-Z])|USE\s*BY|LUPUT)',
);

/// Every date found in [text], in the order it appears.
List<DateTime> _findDates(String text) {
  final found = <(int, DateTime)>[];

  void add(int pos, int year, int month, int day) {
    if (year < 100) year += 2000; // 26 -> 2026
    if (month < 1 || month > 12 || day < 1 || day > 31) return;
    final date = DateTime(year, month, day);
    if (date.month == month) found.add((pos, date)); // rejects 31/02
  }

  for (final m in _dayFirst.allMatches(text)) {
    add(m.start, int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  for (final m in _yearFirst.allMatches(text)) {
    add(m.start, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  for (final m in _monthName.allMatches(text)) {
    add(m.start, int.parse(m[3]!), _months[m[2]!]!, int.parse(m[1]!));
  }
  for (final m in _monthYear.allMatches(text)) {
    final month = int.parse(m[1]!);
    final year = int.parse(m[2]!);
    // Day 0 of next month = last day of this month
    if (month >= 1 && month <= 12) {
      found.add((m.start, DateTime(year, month + 1, 0)));
    }
  }

  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final f in found) f.$2];
}

/// Picks the expiry date from OCR text:
/// 1) the first date after EXP / BEST BEFORE / BB / USE BY / LUPUT
/// 2) otherwise the latest date (the manufacture date is always earlier)
DateTime? parseExpiryDate(String text) {
  final upper = text.toUpperCase();
  final keyword = _expiryWord.firstMatch(upper);
  if (keyword != null) {
    final afterKeyword = _findDates(upper.substring(keyword.end));
    if (afterKeyword.isNotEmpty) return afterKeyword.first;
  }
  final all = _findDates(upper)..sort();
  return all.isEmpty ? null : all.last;
}
