// The chef-videos card: rows with title and channel, a tap hands back the
// video, and every empty/failed/loading state says something real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/recipes/domain/chef_video.dart';
import 'package:zad/features/recipes/presentation/chef_videos_card.dart';
import 'package:zad/shared/worlds/world_card.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ZadTheme.light(),
  localizationsDelegates: ZadL10n.localizationsDelegates,
  supportedLocales: ZadL10n.supportedLocales,
  locale: const Locale('ar'),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _video = ChefVideo(
  id: 'abc12345',
  title: 'كشري بالطريقة الأصلية',
  channel: 'قناة الشيف',
  url: 'https://www.youtube.com/watch?v=abc12345',
  isStore: false,
);

void main() {
  testWidgets('a video row shows title and channel and opens on tap', (
    tester,
  ) async {
    ChefVideo? opened;
    await tester.pumpWidget(
      _host(
        ChefVideosList(
          videos: const <ChefVideo>[_video],
          loading: false,
          failed: false,
          onRetry: () {},
          onOpen: (v) => opened = v,
        ),
      ),
    );
    expect(find.text('كشري بالطريقة الأصلية'), findsOneWidget);
    expect(find.text('قناة الشيف'), findsOneWidget);
    final row = find.text('كشري بالطريقة الأصلية');
    await tester.tap(row);
    expect(opened?.id, 'abc12345');
    // Tap target: the row is at least 44dp tall.
    expect(
      tester.getSize(find.byType(ZadWorldCard)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('no videos is a real empty state, not a blank gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChefVideosList(
          videos: const <ChefVideo>[],
          loading: false,
          failed: false,
          onRetry: () {},
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.text('مافيه فيديوهات جديدة'), findsOneWidget);
  });

  testWidgets('a failure offers a retry that fires', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _host(
        ChefVideosList(
          videos: null,
          loading: false,
          failed: true,
          onRetry: () => retried++,
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.text('ماقدرناش نجيب الفيديوهات دلوقتي'), findsOneWidget);
    await tester.tap(find.text('حاول تاني'));
    expect(retried, 1);
  });

  testWidgets('loading shows a spinner, no empty state', (tester) async {
    await tester.pumpWidget(
      _host(
        ChefVideosList(
          videos: null,
          loading: true,
          failed: false,
          onRetry: () {},
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('مافيه فيديوهات جديدة'), findsNothing);
  });

  test('tryParse keeps good rows and drops ones without a YouTube link', () {
    expect(
      ChefVideo.tryParse(<String, Object?>{
        'id': 'abc12345',
        'title': ' كشري ',
        'url': 'https://www.youtube.com/watch?v=abc12345',
        'kind': 'store',
        'thumbnail': 'https://i.ytimg.com/x.jpg',
      })?.isStore,
      isTrue,
    );
    expect(
      ChefVideo.tryParse(<String, Object?>{
        'id': 'abc12345',
        'title': 'x',
        'url': 'http://evil.example/watch?v=abc12345',
      }),
      isNull,
    );
    expect(
      ChefVideo.tryParse(<String, Object?>{'id': '', 'title': 'x'}),
      isNull,
    );
    expect(ChefVideo.tryParse('nope'), isNull);
  });
}
