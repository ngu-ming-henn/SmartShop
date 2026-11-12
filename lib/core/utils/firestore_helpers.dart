import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

int readInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

int? readIntOrNull(Object? value) => value is num ? value.toInt() : null;

DateTime? readDate(Object? value) => value is Timestamp ? value.toDate() : null;

Timestamp? toTimestamp(DateTime? date) =>
    date == null ? null : Timestamp.fromDate(date);

/// Waits for a write to reach the server. Firestore keeps offline writes in a
/// queue and the Future only completes once synced, so we stop waiting after
/// [timeout]. Returns true if synced, false if it is queued offline.
Future<bool> waitForSync(
  Future<void> write, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    await write.timeout(timeout);
    return true;
  } on TimeoutException {
    // The write stays queued and is sent when the connection returns.
    unawaited(write.catchError((_) {}));
    return false;
  }
}
