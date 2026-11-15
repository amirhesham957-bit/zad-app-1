// The consent sheet names the terms' version and month from the ARB, so it
// reads in the customer's own digits. These keep those lines equal to the
// terms themselves: a new version that forgets the sheet fails here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/auth/presentation/terms_content.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/core/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

String _western(String s) => s.replaceAllMapped(
  RegExp('[٠-٩٫]'),
  (m) => m[0] == '٫' ? '.' : '${m[0]!.codeUnitAt(0) - 0x0660}',
);

void main() {
  test('the sheet names the version the terms carry', () {
    expect(_arb('app_en.arb')['consentTermsVersion'], kTermsVersion);
    expect(
      _western(_arb('app_ar.arb')['consentTermsVersion'] as String),
      kTermsVersion,
    );
    expect(kTermsFullText, contains('Version $kTermsVersion'));
  });

  test('the sheet names the month the terms carry', () {
    expect(_arb('app_en.arb')['consentTermsUpdated'], kTermsLastUpdated);
    expect(kTermsFullText, contains('Last Updated: $kTermsLastUpdated'));
  });
}
