import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/chat.dart';
import 'messages_repository.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.watch(apiClientProvider));
});

/// The customer's conversations, newest activity first.
///
/// The API has no push channel, so the list is re-read on a timer for as long
/// as something is watching. The account tab's badge keeps it warm.
class InboxController
    extends StateNotifier<AsyncValue<List<ChatConversation>>> {
  InboxController(this._repository, {required bool enabled})
    : super(
        enabled
            ? const AsyncValue.loading()
            : const AsyncValue.data(<ChatConversation>[]),
      ) {
    if (!enabled) return;
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  final MessagesRepository _repository;
  Timer? _timer;

  Future<void> refresh() async {
    try {
      final conversations = await _repository.listConversations();
      if (mounted) state = AsyncValue.data(conversations);
    } catch (error, stack) {
      // Keep the last good list on screen; only show the error when there's none.
      if (mounted && !state.hasValue) state = AsyncValue.error(error, stack);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final inboxProvider =
    StateNotifierProvider.autoDispose<
      InboxController,
      AsyncValue<List<ChatConversation>>
    >((ref) {
      final signedIn = ref.watch(
        authProvider.select((auth) => auth.isSignedIn),
      );
      return InboxController(
        ref.watch(messagesRepositoryProvider),
        enabled: signedIn,
      );
    });

/// Unread messages across every thread, for badges.
final unreadMessagesProvider = Provider.autoDispose<int>((ref) {
  final conversations = ref.watch(inboxProvider).valueOrNull ?? const [];
  return conversations.fold<int>(0, (total, item) => total + item.unreadCount);
});

class ChatThreadState {
  const ChatThreadState({
    this.messages = const [],
    this.loaded = false,
    this.error,
    this.hasOlder = false,
    this.loadingOlder = false,
  });

  /// Oldest first.
  final List<ChatMessage> messages;
  final bool loaded;
  final String? error;
  final bool hasOlder;
  final bool loadingOlder;
}

/// Messages for one open thread, polled every few seconds.
///
/// Every read also marks the thread read server-side, so an open chat keeps
/// its unread count at zero without a separate call.
class ChatThreadController extends StateNotifier<ChatThreadState> {
  ChatThreadController(this._repository, this.conversationId)
    : super(const ChatThreadState()) {
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  final MessagesRepository _repository;
  final String conversationId;
  Timer? _timer;
  bool _polling = false;
  bool _firstPage = true;

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final page = await _repository.listMessages(conversationId);
      if (!mounted) return;
      final hasOlder = _firstPage
          ? page.length >= MessagesRepository.pageSize
          : state.hasOlder;
      _firstPage = false;
      state = ChatThreadState(
        messages: _merge(state.messages, page),
        loaded: true,
        hasOlder: hasOlder,
        loadingOlder: state.loadingOlder,
      );
    } catch (error) {
      if (!mounted) return;
      state = ChatThreadState(
        messages: state.messages,
        loaded: true,
        error: error.toString(),
        hasOlder: state.hasOlder,
        loadingOlder: state.loadingOlder,
      );
    } finally {
      _polling = false;
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || state.messages.isEmpty) return;
    state = ChatThreadState(
      messages: state.messages,
      loaded: state.loaded,
      hasOlder: state.hasOlder,
      loadingOlder: true,
    );
    try {
      final page = await _repository.listMessages(
        conversationId,
        before: state.messages.first.createdAtRaw,
      );
      if (!mounted) return;
      state = ChatThreadState(
        messages: _merge(state.messages, page),
        loaded: true,
        hasOlder: page.length >= MessagesRepository.pageSize,
      );
    } catch (error) {
      if (!mounted) return;
      state = ChatThreadState(
        messages: state.messages,
        loaded: true,
        error: error.toString(),
        hasOlder: state.hasOlder,
      );
    }
  }

  /// Uploads any files, sends, and shows the message straight away.
  Future<void> send(String body, List<PendingAttachment> attachments) async {
    final message = await _repository.sendMessage(
      conversationId,
      body: body,
      attachments: attachments,
    );
    if (!mounted) return;
    state = ChatThreadState(
      messages: _merge(state.messages, [message]),
      loaded: true,
      hasOlder: state.hasOlder,
      loadingOlder: state.loadingOlder,
    );
  }

  /// Polling returns the newest page repeatedly; merging by id keeps older
  /// pages the customer loaded and never doubles a message we just sent.
  static List<ChatMessage> _merge(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    if (incoming.isEmpty) return current;
    final byId = {for (final message in current) message.id: message};
    for (final message in incoming) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return merged;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final chatThreadProvider = StateNotifierProvider.autoDispose
    .family<ChatThreadController, ChatThreadState, String>((
      ref,
      conversationId,
    ) {
      return ChatThreadController(
        ref.watch(messagesRepositoryProvider),
        conversationId,
      );
    });
