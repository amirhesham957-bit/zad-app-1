// Rows ask for a photo as they build: asked once, sent together.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/inventory/data/item_images.dart';

import '../../support/quiet_household.dart';

void main() {
  test(
    'a name that cannot be fetched is settled, and not asked again',
    () async {
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(quietSupabase)],
      );
      addTearDown(container.dispose);
      container.read(itemImagesProvider.notifier)
        ..want('زيت')
        ..want('زيت');
      expect(container.read(itemImagesProvider), isEmpty);

      await expectLater(
        Stream<void>.periodic(const Duration(milliseconds: 20))
            .firstWhere((_) => container.read(itemImagesProvider).isNotEmpty),
        completes,
      );
      expect(container.read(itemImagesProvider), <String, String?>{
        'زيت': null,
      });
    },
  );
}
