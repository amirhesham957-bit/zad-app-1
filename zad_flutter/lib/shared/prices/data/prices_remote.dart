/// The server side of crowd prices. All three are database functions: a
/// client reads only its own rows of `price_index` and writes none directly
/// (`20260921160000_price_reports_through_the_server`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reports prices and reads what the community reported.
abstract interface class PricesRemote {
  /// Calls `zad_report_price`. Returns its answer; refusals are answers.
  Future<Map<String, dynamic>> report({
    required String reportId,
    required String item,
    required double price,
    String? currency,
    String? city,
    String? store,
    String? category,
  });

  /// Calls `zad_cheapest_prices`.
  Future<List<Object?>> cheapest({required String currency, String? city});

  /// Calls `zad_price_leaderboard`.
  Future<List<Object?>> leaderboard({required String currency});

  /// Calls `zad_area_trends` for [userId]: the market's items with at least
  /// the server's threshold of homes. The threshold is not the client's.
  Future<Object?> areaTrends({required String userId, int days = 14});
}

/// The real one.
class SupabasePricesRemote implements PricesRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> report({
    required String reportId,
    required String item,
    required double price,
    String? currency,
    String? city,
    String? store,
    String? category,
  }) async {
    final result = await _client.rpc<dynamic>(
      'zad_report_price',
      params: <String, dynamic>{
        'p_report': reportId,
        'p_item': item,
        'p_price': price,
        'p_currency': currency,
        'p_location': city,
        'p_store': store,
        'p_category': category,
      },
    );
    if (result is! Map) {
      throw StateError('zad_report_price answered ${result.runtimeType}');
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<List<Object?>> cheapest({
    required String currency,
    String? city,
  }) async {
    final result = await _client.rpc<dynamic>(
      'zad_cheapest_prices',
      params: <String, dynamic>{'p_currency': currency, 'p_location': city},
    );
    return result is List ? result.cast<Object?>() : const <Object?>[];
  }

  @override
  Future<List<Object?>> leaderboard({required String currency}) async {
    final result = await _client.rpc<dynamic>(
      'zad_price_leaderboard',
      params: <String, dynamic>{'p_currency': currency},
    );
    return result is List ? result.cast<Object?>() : const <Object?>[];
  }

  @override
  Future<Object?> areaTrends({required String userId, int days = 14}) =>
      _client.rpc<dynamic>(
        'zad_area_trends',
        params: <String, dynamic>{'p_user': userId, 'p_days': days},
      );
}
