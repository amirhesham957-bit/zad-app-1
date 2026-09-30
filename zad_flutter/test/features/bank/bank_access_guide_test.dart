import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/bank/presentation/bank_access_guide_screen.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

class _Access extends BankAccessController {
  new({required this.granted});

  final bool granted;

  @override
  BankAccessState build() => BankAccessState(granted: granted, pending: 0);

  @override
  Future<void> refresh() async {}
}

class _Listener extends ZadBankListener {
  new();

  int permissionOpened = 0;
  int detailsOpened = 0;

  @override
  Future<void> openPermissionSettings() async => permissionOpened++;

  @override
  Future<void> openAppDetails() async => detailsOpened++;
}

void main() {
  Future<_Listener> pump(
    WidgetTester tester, {
    required bool granted,
    required InstallInfo install,
  }) async {
    final listener = _Listener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bankAccessControllerProvider.overrideWith(
            () => _Access(granted: granted),
          ),
          installInfoProvider.overrideWith((ref) async => install),
          bankListenerProvider.overrideWithValue(listener),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: BankAccessGuideScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return listener;
  }

  testWidgets('a file install on Android 13+ is shown the restricted step', (
    tester,
  ) async {
    final listener = await pump(
      tester,
      granted: false,
      install: const InstallInfo(sdk: 34),
    );
    expect(find.text('اسمح بالإعدادات المقيدة'), findsOneWidget);
    Future<void> tap(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
    }

    await tap(find.text('افتح معلومات التطبيق').first);
    expect(listener.detailsOpened, 1);
    await tap(find.text('افتح الإذن').first);
    expect(listener.permissionOpened, 1);
  });

  testWidgets('a Play install, or Android 12, skips that step', (tester) async {
    await pump(
      tester,
      granted: false,
      install: const InstallInfo(sdk: 34, installer: 'com.android.vending'),
    );
    expect(find.text('اسمح بالإعدادات المقيدة'), findsNothing);
    expect(find.text('افتح الإذن'), findsOneWidget);
  });

  testWidgets('once granted, it says so instead of the steps', (tester) async {
    await pump(tester, granted: true, install: const InstallInfo(sdk: 34));
    expect(find.text('تمام، زاد بيقرا إشعارات البنك دلوقتي'), findsOneWidget);
    expect(find.text('افتح الإذن'), findsNothing);
  });

  test('which installs Android 13+ restricts', () {
    expect(const InstallInfo(sdk: 33).mayBeRestricted, isTrue);
    expect(const InstallInfo(sdk: 32).mayBeRestricted, isFalse);
    expect(
      const InstallInfo(
        sdk: 35,
        installer: 'com.android.vending',
      ).mayBeRestricted,
      isFalse,
    );
    expect(
      const InstallInfo(
        sdk: 35,
        installer: 'com.google.android.documentsui',
      ).mayBeRestricted,
      isTrue,
    );
  });
}
