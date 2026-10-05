import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/messages_providers.dart';
import '../../domain/chat.dart';
import '../widgets/conversation_label.dart';

/// The API rejects more than this many files on one message.
const int _maxAttachments = 5;

/// Client-side cap so a huge file fails fast instead of timing out mid-upload.
const int _maxFileBytes = 15 * 1024 * 1024;

/// One conversation with a shop.
///
/// Opened with a [conversationId] from the inbox; with a [productId] from a
/// gift's "Ask" button; or with an [orderItemId] from an order. In the last
/// two cases the customer's existing thread is reused when there is one;
/// otherwise the thread is started by the first message. `POST
/// /conversations` carrying the `product_id` or `order_item_id` and the
/// message together. So shops never see empty threads.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.conversationId,
    this.productId,
    this.orderItemId,
  });

  final String? conversationId;

  /// The gift a new question is about (also used to label an order chat).
  final String? productId;

  /// The order item a new order chat is about.
  final String? orderItemId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String? _conversationId;
  ChatConversation? _conversation;
  bool _resolving = false;
  bool _reopening = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      _loadConversation(_conversationId!);
    } else if (widget.productId != null || widget.orderItemId != null) {
      _findExistingThread();
    }
  }

  Future<void> _loadConversation(String id) async {
    try {
      final conversation = await ref
          .read(messagesRepositoryProvider)
          .getConversation(id);
      if (mounted) setState(() => _conversation = conversation);
    } catch (_) {
      // The header falls back to generic copy; the messages still load.
    }
  }

  Future<void> _findExistingThread() async {
    final orderItemId = widget.orderItemId;
    final productId = widget.productId;
    setState(() => _resolving = true);
    try {
      final conversations = await ref
          .read(messagesRepositoryProvider)
          .listConversations();
      // An order item has at most one thread (open or closed); a gift question
      // is reused only while it's still open.
      final existing = conversations
          .where(
            (item) => orderItemId != null
                ? item.type == 'order' && item.orderItemId == orderItemId
                : item.type == 'product_inquiry' &&
                      item.productId == productId &&
                      item.isOpen,
          )
          .firstOrNull;
      if (mounted && existing != null) {
        setState(() {
          _conversation = existing;
          _conversationId = existing.id;
        });
      }
    } catch (_) {
      // Stay in draft: starting on send reuses an open thread server-side anyway.
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _send(String body, List<PendingAttachment> attachments) async {
    final id = _conversationId;
    if (id != null) {
      await ref.read(chatThreadProvider(id).notifier).send(body, attachments);
    } else {
      // A new thread goes out with its first message in the start request.
      final repository = ref.read(messagesRepositoryProvider);
      final orderItemId = widget.orderItemId;
      final productId = widget.productId;
      final ChatConversation started;
      if (orderItemId != null) {
        started = await repository.startOrderChat(
          orderItemId,
          body: body,
          attachments: attachments,
        );
      } else if (productId != null) {
        started = await repository.startProductInquiry(
          productId,
          body: body,
          attachments: attachments,
        );
      } else {
        throw const AppException('This conversation is not available.');
      }
      if (!mounted) return;
      setState(() {
        _conversation = started;
        _conversationId = started.id;
      });
    }
    ref.read(inboxProvider.notifier).refresh();
  }

  Future<void> _reopen() async {
    final id = _conversationId;
    if (id == null) return;
    setState(() => _reopening = true);
    try {
      final updated = await ref.read(messagesRepositoryProvider).reopen(id);
      if (mounted) setState(() => _conversation = updated);
      ref.read(inboxProvider.notifier).refresh();
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _reopening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _conversationId;
    // The inbox is polled, so it carries the freshest status (a shop may close
    // the thread while it's open here).
    final fromInbox = id == null
        ? null
        : ref
              .watch(inboxProvider)
              .valueOrNull
              ?.where((item) => item.id == id)
              .firstOrNull;
    final conversation = fromInbox ?? _conversation;
    final label = watchConversationLabel(
      ref,
      type:
          conversation?.type ??
          (widget.orderItemId != null ? 'order' : 'product_inquiry'),
      productId: conversation?.productId ?? widget.productId,
      supportCase: conversation?.supportCase,
    );
    final customerId = ref.watch(
      authProvider.select((auth) => auth.customer?['id'] as String?),
    );
    // Which senders are "me". The app is customer-only, so my messages are the
    // ones from the customer participant (or the signed-in id). The shop/admin
    // ids are the fallback when neither of those is known yet.
    final myIds = <String>{
      ?customerId,
      ...?conversation?.participants
          .where((participant) => participant.role == 'customer')
          .map((participant) => participant.userId),
    };
    final otherIds =
        conversation?.participants
            .where((participant) => participant.role != 'customer')
            .map((participant) => participant.userId)
            .toSet() ??
        const <String>{};
    final closed = conversation != null && !conversation.isOpen;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(label: label, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    label.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _resolving
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : id == null
                ? _ThreadHint(
                    text: widget.orderItemId != null
                        ? 'Message the shop about this item. Delivery, '
                              'changes, or a problem with the gift. You can '
                              'attach photos.'
                        : 'Ask about sizes, delivery dates, or personalising '
                              'this gift. The shop replies right here.',
                  )
                : _MessageList(
                    conversationId: id,
                    myIds: myIds,
                    otherIds: otherIds,
                  ),
          ),
          if (closed)
            _ClosedBar(reopening: _reopening, onReopen: _reopen)
          else
            _Composer(enabled: !_resolving, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.conversationId,
    required this.myIds,
    required this.otherIds,
  });

  final String conversationId;
  final Set<String> myIds;
  final Set<String> otherIds;

  bool _isOwn(String senderId) {
    if (myIds.contains(senderId)) return true;
    // Neither side identified yet: anyone who isn't the shop/admin is me.
    if (myIds.isEmpty && otherIds.isNotEmpty) {
      return !otherIds.contains(senderId);
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(chatThreadProvider(conversationId));
    final messages = thread.messages;

    if (!thread.loaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (messages.isEmpty) {
      return _ThreadHint(
        text: thread.error ?? 'No messages yet. Say hello.',
        isError: thread.error != null,
      );
    }

    // One trailing slot for the "load earlier" button or the start-of-thread
    // marker. Reversed, so the newest message sits at the bottom.
    const extra = 1;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        12,
        AppTheme.gutter,
        12,
      ),
      itemCount: messages.length + extra,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          // Reversed list, so this trailing slot draws at the very top.
          return thread.hasOlder
              ? Center(
                  child: TextButton(
                    onPressed: thread.loadingOlder
                        ? null
                        : () => ref
                              .read(chatThreadProvider(conversationId).notifier)
                              .loadOlder(),
                    child: Text(
                      thread.loadingOlder
                          ? 'Loading…'
                          : 'Load earlier messages',
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Center(
                    child: Text(
                      'The start of your conversation',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                );
        }
        final position = messages.length - 1 - index;
        final message = messages[position];
        final newDay =
            position == 0 ||
            !isSameDay(messages[position - 1].createdAt, message.createdAt);
        return Column(
          children: [
            if (newDay) _DaySeparator(date: message.createdAt),
            _MessageBubble(message: message, own: _isOwn(message.senderUserId)),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              formatDayLabel(date),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.own});

  final ChatMessage message;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final images = message.attachments.where((item) => item.isImage).toList();
    final documents = message.attachments
        .where((item) => !item.isImage)
        .toList();
    final body = message.body.trim();
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: own ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: own
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: own ? WrapAlignment.end : WrapAlignment.start,
                    children: [
                      for (final image in images)
                        _ImageAttachment(
                          attachment: image,
                          size: images.length == 1 ? 220 : 108,
                        ),
                    ],
                  ),
                ),
              for (final document in documents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _DocumentAttachment(attachment: document, own: own),
                ),
              if (body.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: own ? AppColors.purple : AppColors.surface,
                    border: own ? null : Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(own ? 18 : 6),
                      bottomRight: Radius.circular(own ? 6 : 18),
                    ),
                  ),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: own
                          ? AppColors.primaryForeground
                          : AppColors.foreground,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Text(
                  formatBubbleTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment, required this.size});

  final ChatAttachment attachment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = attachment.cdnUrl;
    return GestureDetector(
      onTap: url == null ? null : () => _openImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? Container(
                  color: AppColors.mist,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.mutedForeground,
                  ),
                )
              : AppNetworkImage(url: url),
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: AppNetworkImage(url: url, fit: BoxFit.contain),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Close',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentAttachment extends StatelessWidget {
  const _DocumentAttachment({required this.attachment, required this.own});

  final ChatAttachment attachment;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final foreground = own ? AppColors.primaryForeground : AppColors.foreground;
    final url = attachment.cdnUrl;

    return Material(
      color: own ? AppColors.purple : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: own ? BorderSide.none : const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url == null ? null : () => _open(context, url),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: own
                      ? AppColors.primaryForeground.withValues(alpha: 0.15)
                      : AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 19,
                  color: own
                      ? AppColors.primaryForeground
                      : AppColors.accentForeground,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                    Text(
                      formatFileSize(attachment.sizeBytes),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      _showSnack(context, "Couldn't open this file.");
    }
  }
}

class _ThreadHint extends StatelessWidget {
  const _ThreadHint({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError ? AppColors.destructive : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar({required this.reopening, required this.onReopen});

  final bool reopening;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 10, 12, 10),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This conversation is closed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: reopening ? null : onReopen,
                child: Text(reopening ? 'Reopening…' : 'Reopen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.enabled, required this.onSend});

  final bool enabled;

  /// Throwing keeps the draft and shows the error, so nothing typed is lost.
  final Future<void> Function(String body, List<PendingAttachment> attachments)
  onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<PendingAttachment> _pending = [];
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _room => _maxAttachments - _pending.length;

  bool get _canSend =>
      widget.enabled &&
      !_sending &&
      (_controller.text.trim().isNotEmpty || _pending.isNotEmpty);

  void _add(Iterable<PendingAttachment> files) {
    String? problem;
    final accepted = <PendingAttachment>[];
    for (final file in files) {
      if (file.sizeBytes > _maxFileBytes) {
        problem ??=
            '${file.name} is larger than ${formatFileSize(_maxFileBytes)}.';
        continue;
      }
      if (accepted.length >= _room) {
        problem ??= 'You can attach up to $_maxAttachments files per message.';
        break;
      }
      accepted.add(file);
    }
    setState(() {
      _pending.addAll(accepted);
      _error = problem;
    });
  }

  Future<void> _addImages(List<XFile> files) async {
    final pending = <PendingAttachment>[];
    for (final file in files) {
      pending.add(
        PendingAttachment(
          name: file.name,
          mimeType: file.mimeType ?? _imageMimeType(file.name),
          bytes: await file.readAsBytes(),
        ),
      );
    }
    if (mounted) _add(pending);
  }

  Future<void> _pickPhotos() async {
    try {
      if (_room <= 1) {
        final file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
        );
        if (file != null) await _addImages([file]);
        return;
      }
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2048,
        limit: _room,
      );
      await _addImages(files);
    } on PlatformException {
      _pickerFailed('Allow photo access in Settings to attach photos.');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (file != null) await _addImages([file]);
    } on PlatformException {
      _pickerFailed('Allow camera access in Settings to take a photo.');
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: true,
      );
      final files = result?.files ?? const <PlatformFile>[];
      _add([
        for (final file in files)
          if (file.bytes != null)
            PendingAttachment(
              name: file.name,
              mimeType: 'application/pdf',
              bytes: file.bytes!,
            ),
      ]);
    } on PlatformException {
      _pickerFailed("Couldn't open your files.");
    }
  }

  void _pickerFailed(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _chooseAttachment() async {
    if (_room <= 0) {
      setState(
        () =>
            _error = 'You can attach up to $_maxAttachments files per message.',
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: SheetHeader(
                title: 'Attach',
                titleStyle: Theme.of(context).textTheme.titleMedium,
                showHandle: false,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.of(context).pop('photos'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF document'),
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'photos':
        await _pickPhotos();
      case 'camera':
        await _takePhoto();
      case 'pdf':
        await _pickDocuments();
    }
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    final body = _controller.text.trim();
    final attachments = List<PendingAttachment>.of(_pending);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(body, attachments);
      if (!mounted) return;
      _controller.clear();
      setState(_pending.clear);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              if (_pending.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    itemCount: _pending.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => _PendingPreview(
                      file: _pending[index],
                      onRemove: _sending
                          ? null
                          : () => setState(() => _pending.removeAt(index)),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _sending || !widget.enabled
                        ? null
                        : _chooseAttachment,
                    icon: const Icon(Icons.attach_file_rounded),
                    color: AppColors.mutedForeground,
                    tooltip: 'Attach a photo or PDF',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled && !_sending,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _canSend ? _submit : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: AppColors.primaryForeground,
                      disabledBackgroundColor: AppColors.mist,
                    ),
                    tooltip: 'Send',
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryForeground,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _PendingPreview extends StatelessWidget {
  const _PendingPreview({required this.file, required this.onRemove});

  final PendingAttachment file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: file.isImage
              ? Image.memory(
                  file.bytes,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 150,
                  height: 60,
                  color: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              height: 20,
              width: 20,
              decoration: const BoxDecoration(
                color: AppColors.foreground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
