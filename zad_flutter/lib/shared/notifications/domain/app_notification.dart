/// One row of `app_notifications`: a message the app or a family member left
/// for this account.
library;

import 'package:flutter/foundation.dart';

/// A notification.
@immutable
class AppNotification {
  /// Creates a notification.
  const new({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  /// Reads a row.
  ///
  /// `is_read` is nullable on the server; null is unread, as the Kotlin model
  /// reads it and as the "mark all read" update treats it.
  factory fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    title: (json['title'] as String?) ?? '',
    message: (json['message'] as String?) ?? '',
    createdAt: switch (json['created_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    },
    isRead: json['is_read'] as bool? ?? false,
  );

  /// The row id.
  final String id;

  /// The headline.
  final String title;

  /// The body.
  final String message;

  /// When it was written.
  final DateTime createdAt;

  /// Whether the customer has read it.
  final bool isRead;

  /// The same notification, read.
  AppNotification markRead() => AppNotification(
    id: id,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: true,
  );

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'message': message,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead,
  };
}
