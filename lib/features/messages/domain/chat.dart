import 'dart:typed_data';

/// One person in a thread. `userId` is a customer, seller, or admin id
/// depending on [role]. The API has no single users table.
class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.userId,
    required this.role,
    this.lastReadAt,
  });

  final String id;
  final String userId;
  final String role;
  final DateTime? lastReadAt;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? '',
      lastReadAt: _parseDate(json['last_read_at']),
    );
  }
}

/// Ticket details on a support thread.
class ChatSupportCase {
  const ChatSupportCase({this.subject, required this.status});

  final String? subject;
  final String status;

  factory ChatSupportCase.fromJson(Map<String, dynamic> json) {
    return ChatSupportCase(
      subject: (json['subject'] as String?)?.trim(),
      status: json['status'] as String? ?? 'open',
    );
  }
}

/// A chat thread. About a gift (`product_inquiry`), an order item
/// (`order`), or a support ticket (`support`).
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.productId,
    this.shopId,
    this.orderItemId,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.participants = const [],
    this.supportCase,
  });

  final String id;
  final String type;
  final String status;
  final String? productId;
  final String? shopId;
  final String? orderItemId;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final List<ChatParticipant> participants;
  final ChatSupportCase? supportCase;

  bool get isOpen => status == 'open';
  bool get isSupport => type == 'support';
  bool get isOrder => type == 'order';

  /// When the thread last moved. Inbox order and the row timestamp.
  DateTime get activityAt => lastMessageAt ?? createdAt;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final participants =
        (json['participants'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(ChatParticipant.fromJson)
            .toList(growable: false) ??
        const <ChatParticipant>[];
    final supportCase = json['support_case'];

    return ChatConversation(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      productId: json['product_id'] as String?,
      shopId: json['shop_id'] as String?,
      orderItemId: json['order_item_id'] as String?,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      lastMessageAt: _parseDate(json['last_message_at']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      participants: participants,
      supportCase: supportCase is Map<String, dynamic>
          ? ChatSupportCase.fromJson(supportCase)
          : null,
    );
  }
}

/// A file on a message, already stored and linked by the API.
class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.assetType,
    required this.objectPath,
    required this.mimeType,
    required this.sizeBytes,
    this.cdnUrl,
  });

  final String id;
  final String assetType;
  final String objectPath;
  final String mimeType;
  final int sizeBytes;
  final String? cdnUrl;

  bool get isImage => assetType == 'image' || mimeType.startsWith('image/');

  static final _uploadPrefix = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-',
    caseSensitive: false,
  );

  /// Upload keys look like `public/chat/documents/<uuid>-invoice.pdf`.
  String get fileName {
    final last = objectPath.split('/').last;
    final trimmed = last.replaceFirst(_uploadPrefix, '');
    return trimmed.isEmpty ? last : trimmed;
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final url = (json['cdn_url'] as String?)?.trim();
    return ChatAttachment(
      id: json['id'] as String? ?? '',
      assetType: json['asset_type'] as String? ?? '',
      objectPath: json['object_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      cdnUrl: url == null || url.isEmpty ? null : url,
    );
  }
}

/// One chat bubble.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    required this.createdAtRaw,
    this.attachments = const [],
  });

  final String id;
  final String senderUserId;
  final String body;
  final DateTime createdAt;

  /// The timestamp exactly as the API sent it. Used as the `before` cursor
  /// so paging never skips a message over lost sub-second precision.
  final String createdAtRaw;
  final List<ChatAttachment> attachments;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['created_at'] as String? ?? '';
    return ChatMessage(
      id: json['id'] as String? ?? '',
      senderUserId: json['sender_user_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: _parseDate(raw)?.toLocal() ?? DateTime.now(),
      createdAtRaw: raw,
      // The API omits `attachments` entirely on text-only messages.
      attachments:
          (json['attachments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatAttachment.fromJson)
              .toList(growable: false) ??
          const <ChatAttachment>[],
    );
  }
}

/// A photo or PDF picked on the device, not yet uploaded.
class PendingAttachment {
  const PendingAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  bool get isImage => mimeType.startsWith('image/');
  int get sizeBytes => bytes.length;
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
