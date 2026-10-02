import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';

/// One entry in the customer's notification inbox, such as a new
/// competition they can play in.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AppNotification(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: data is Map
          ? data.map((k, v) => MapEntry('$k', '$v'))
          : const <String, String>{},
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? '')?.toLocal(),
    );
  }

  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, String> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  /// The competition this is about, when it is about one.
  String? get competitionId => data['competition_id'];
}

class NotificationInbox {
  const NotificationInbox({required this.items, required this.unread});

  factory NotificationInbox.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return NotificationInbox(
      items: items is List
          ? items
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .toList(growable: false)
          : const [],
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = NotificationInbox(items: [], unread: 0);

  final List<AppNotification> items;
  final int unread;
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final ApiClient _client;

  Future<NotificationInbox> inbox() async {
    try {
      final response = await _client.dio.get<dynamic>(
        '/customers/me/notifications',
        queryParameters: {'limit': 50},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AppException('Unexpected response from the server.');
      }
      return NotificationInbox.fromJson(data);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Marks everything read.
  Future<void> markAllRead() async {
    try {
      await _client.dio.post<void>('/customers/me/notifications/read');
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

/// The signed-in customer's inbox; empty for a guest. Refreshed when a push
/// notification arrives and whenever the inbox is opened.
final notificationInboxProvider = FutureProvider<NotificationInbox>((ref) {
  final signedIn = ref.watch(authProvider.select((a) => a.isSignedIn));
  if (!signedIn) return Future.value(NotificationInbox.empty);
  return ref.watch(notificationsRepositoryProvider).inbox();
});

/// How many notifications are unread, for the bell's badge.
final unreadNotificationsProvider = Provider<int>((ref) {
  return ref.watch(notificationInboxProvider).valueOrNull?.unread ?? 0;
});
