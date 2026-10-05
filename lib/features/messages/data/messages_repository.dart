import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat.dart';

/// Customer ↔ shop chat over the messaging API.
///
/// Files never travel through the API itself: each one is presigned into the
/// `chat-image` / `chat-document` folder, PUT straight to storage, and then
/// referenced by its key when the message is sent.
class MessagesRepository {
  MessagesRepository(this._client);

  final ApiClient _client;

  /// Talks to the presigned storage URL directly. No base URL, and no API
  /// token (the signature in the URL is the permission).
  final Dio _storage = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static const int pageSize = 50;

  /// How recent a thread's last message must be to count as the one just
  /// sent. Short on purpose: clock skew past it only risks a duplicate, while
  /// a longer window could mistake a reused thread for new and drop a message.
  static const Duration _justSentSlack = Duration(seconds: 30);

  Future<List<ChatConversation>> listConversations() async {
    try {
      final response = await _client.dio.get<dynamic>('/conversations');
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ChatConversation.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<ChatConversation> getConversation(String id) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/conversations/$id',
      );
      return ChatConversation.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Asks a shop about a gift: `product_inquiry` with the gift's `product_id`
  /// and the first message, in one request.
  Future<ChatConversation> startProductInquiry(
    String productId, {
    required String body,
    List<PendingAttachment> attachments = const [],
  }) {
    return _startWithMessage(
      {'type': 'product_inquiry', 'product_id': productId},
      body: body,
      attachments: attachments,
      // An already-open question about this gift comes back without the message.
      alwaysStored: false,
    );
  }

  /// Messages the shop about one item of an order: `order` with its
  /// `order_item_id` and the first message (photos of a damaged gift, say).
  Future<ChatConversation> startOrderChat(
    String orderItemId, {
    required String body,
    List<PendingAttachment> attachments = const [],
  }) {
    return _startWithMessage(
      {'type': 'order', 'order_item_id': orderItemId},
      body: body,
      attachments: attachments,
      // The API stores the message for both new and existing order threads.
      alwaysStored: true,
    );
  }

  /// `POST /conversations` carrying the first message, as the API docs show.
  ///
  /// When the API hands back a thread that already existed (a product
  /// question that was still open), it doesn't store the message. So if the
  /// thread's last message predates this request, it's posted separately.
  Future<ChatConversation> _startWithMessage(
    Map<String, dynamic> target, {
    required String body,
    required List<PendingAttachment> attachments,
    required bool alwaysStored,
  }) async {
    final uploaded = await Future.wait(attachments.map(_upload));
    final startedAt = DateTime.now().toUtc();

    final ChatConversation conversation;
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/conversations',
        data: {
          ...target,
          'body': body,
          if (uploaded.isNotEmpty) 'attachments': uploaded,
        },
      );
      conversation = ChatConversation.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }

    if (!alwaysStored) {
      final last = conversation.lastMessageAt;
      final stored =
          last != null && !last.isBefore(startedAt.subtract(_justSentSlack));
      if (!stored) await _postMessage(conversation.id, body, uploaded);
    }
    return conversation;
  }

  /// Oldest → newest. Fetching also marks the thread read for the customer.
  Future<List<ChatMessage>> listMessages(String id, {String? before}) async {
    try {
      final response = await _client.dio.get<dynamic>(
        '/conversations/$id/messages',
        queryParameters: {
          'limit': pageSize,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<ChatMessage> sendMessage(
    String id, {
    required String body,
    List<PendingAttachment> attachments = const [],
  }) async {
    final uploaded = await Future.wait(attachments.map(_upload));
    return _postMessage(id, body, uploaded);
  }

  Future<ChatMessage> _postMessage(
    String id,
    String body,
    List<Map<String, dynamic>> uploaded,
  ) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/conversations/$id/messages',
        data: {'body': body, if (uploaded.isNotEmpty) 'attachments': uploaded},
      );
      return ChatMessage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<ChatConversation> reopen(String id) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/conversations/$id/reopen',
      );
      return ChatConversation.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Presign → PUT → the attachment reference the message endpoints expect.
  Future<Map<String, dynamic>> _upload(PendingAttachment file) async {
    final String uploadUrl;
    final String key;
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/media/presign-upload',
        data: {
          'filename': _safeFileName(file.name),
          'content_type': file.mimeType,
          'folder': file.isImage ? 'chat-image' : 'chat-document',
        },
      );
      uploadUrl = response.data?['upload_url'] as String? ?? '';
      key = response.data?['key'] as String? ?? '';
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
    if (uploadUrl.isEmpty || key.isEmpty) {
      throw const AppException('Could not prepare the upload.');
    }

    try {
      await _storage.put<void>(
        uploadUrl,
        data: Stream<List<int>>.value(file.bytes),
        options: Options(
          // Must match the content type the URL was signed for.
          contentType: file.mimeType,
          headers: {Headers.contentLengthHeader: file.sizeBytes},
        ),
      );
    } on DioException {
      throw AppException('Could not upload ${file.name}. Please try again.');
    }

    return {
      'object_path': key,
      'mime_type': file.mimeType,
      'size_bytes': file.sizeBytes,
    };
  }

  /// Upload keys embed the file name; keep it to characters that need no escaping.
  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'attachment' : cleaned;
  }
}
