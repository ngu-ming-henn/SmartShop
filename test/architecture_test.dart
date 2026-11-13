import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The MVVM rules of this app, checked on every test run:
/// - Views (`screens/`, `widgets/`) talk only to ViewModels: no services,
///   no Firestore or Firebase Auth.
/// - ViewModels hold no UI: no BuildContext, no screens or widgets.
void main() {
  Iterable<File> dartFiles(String folder) =>
      Directory(folder)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

  String name(File f) => f.path.replaceAll('\\', '/');

  test('Views never use services or Firebase directly', () {
    final bad = <String>[];
    for (final folder in ['lib/screens', 'lib/widgets']) {
      for (final f in dartFiles(folder)) {
        final code = f.readAsStringSync();
        if (RegExp(
          r"import '[./]*services/|package:cloud_firestore|package:firebase_auth",
        ).hasMatch(code)) {
          bad.add(name(f));
        }
      }
    }
    expect(bad, isEmpty, reason: 'Go through a ViewModel instead');
  });

  test('ViewModels hold no UI', () {
    final bad = <String>[];
    for (final f in dartFiles('lib/viewmodels')) {
      final code = f.readAsStringSync();
      if (code.contains('BuildContext') ||
          RegExp(r"import '[./]*(screens|widgets)/").hasMatch(code)) {
        bad.add(name(f));
      }
    }
    expect(bad, isEmpty);
  });

  test('every ViewModel is a ViewModel or ChangeNotifier', () {
    for (final f in dartFiles('lib/viewmodels')) {
      final code = f.readAsStringSync();
      for (final m in RegExp(r'class (\w+ViewModel) ').allMatches(code)) {
        expect(
          RegExp('${m[1]}(<[^>]*>)? extends (ViewModel|ChangeNotifier)')
              .hasMatch(code),
          isTrue,
          reason: '${m[1]} in ${name(f)}',
        );
      }
    }
  });
}
