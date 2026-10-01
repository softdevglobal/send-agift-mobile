import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/reel_social_repository.dart';
import '../../data/reels_providers.dart';
import '../../domain/reel.dart';
import '../../domain/reel_social.dart';

/// Opens a reel's comments over the feed. Anyone can read them; posting,
/// editing and deleting need a signed-in customer.
Future<void> showReelComments(BuildContext context, String reelId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Over the bottom nav too, so the composer is never hidden behind it.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => ReelCommentsSheet(reelId: reelId),
  );
}

/// A reel's comments. Opens on the comments the feed already carried, then
/// swaps in the API's newest page so the list is current.
class ReelCommentsSheet extends ConsumerStatefulWidget {
  const ReelCommentsSheet({super.key, required this.reelId});

  final String reelId;

  @override
  ConsumerState<ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends ConsumerState<ReelCommentsSheet> {
  /// Mirrors the API: longer bodies are rejected.
  static const int _maxBody = 1000;

  /// Mirrors the API, which trims longer nicknames to 40.
  static const int _maxNickname = 40;

  final TextEditingController _input = TextEditingController();
  final TextEditingController _nickname = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  List<ReelComment> _items = const [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;

  /// Off after a failed page, so scrolling does not hammer a failing API; the
  /// footer's button turns it back on.
  bool _autoLoadMore = true;
  String? _listError;
  String? _sendError;

  Set<String> _ownIds = const {};
  bool _sending = false;
  bool _anonymous = false;
  ReelComment? _editing;
  String? _customerId;

  ReelSocialRepository get _social => ref.read(reelSocialRepositoryProvider);
  ReelFeedController get _feed => ref.read(reelFeedProvider.notifier);
  String get _reelId => widget.reelId;

  @override
  void initState() {
    super.initState();
    _items = _feed.reelById(_reelId)?.comments ?? const [];
    _customerId = ref.read(authProvider).customer?['id'] as String?;
    _scroll.addListener(_onScroll);
    _loadFirstPage();
    _loadOwnIds();
  }

  @override
  void dispose() {
    _input.dispose();
    _nickname.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadOwnIds() async {
    try {
      final ids = await _social.ownCommentIds(_customerId);
      if (mounted) setState(() => _ownIds = ids);
    } catch (_) {
      // Without the list there are simply no edit controls.
    }
  }

  Future<void> _loadFirstPage() async {
    try {
      final page = await _social.listComments(_reelId);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _cursor = page.nextCursor;
        _listError = null;
      });
    } catch (_) {
      // The feed's copy is still showing; say it may be behind.
      if (mounted) setState(() => _listError = 'Could not refresh comments.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_autoLoadMore && _scroll.position.extentAfter < 240) _loadMore();
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || cursor.isEmpty || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _autoLoadMore = true;
    });
    try {
      final page = await _social.listComments(_reelId, cursor: cursor);
      if (!mounted) return;
      final seen = {for (final comment in _items) comment.id};
      setState(() {
        _items = [
          ..._items,
          ...page.items.where((comment) => !seen.contains(comment.id)),
        ];
        _cursor = page.nextCursor;
        _listError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _autoLoadMore = false;
          _listError = 'Could not load more comments.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _submit() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    final editing = _editing;

    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      if (editing != null) {
        final updated = await _social.updateComment(_reelId, editing.id, body);
        _feed.patchReel(
          _reelId,
          (reel) => reel.copyWith(comments: _replaced(reel.comments, updated)),
        );
        if (!mounted) return;
        setState(() {
          _items = _replaced(_items, updated);
          _editing = null;
        });
      } else {
        final created = await _social.createComment(
          _reelId,
          body: body,
          anonymous: _anonymous,
          nickname: _nickname.text,
        );
        _social.rememberOwnComment(_customerId, created.id).ignore();
        _feed.patchReel(
          _reelId,
          (reel) => reel.copyWith(
            commentCount: reel.commentCount + 1,
            comments: [
              created,
              ...reel.comments.where((comment) => comment.id != created.id),
            ],
          ),
        );
        if (!mounted) return;
        setState(() {
          _items = [created, ..._items];
          _ownIds = {..._ownIds, created.id};
        });
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
      _input.clear();
    } on AppException catch (error) {
      if (editing != null && error.statusCode == 404) {
        _lostOwnership(editing.id, 'edited');
      } else if (mounted) {
        setState(() => _sendError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sendError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ReelComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('It will be removed from this reel for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _social.deleteComment(_reelId, comment.id);
      _social.forgetOwnComment(_customerId, comment.id).ignore();
      _feed.patchReel(
        _reelId,
        (reel) => reel.copyWith(
          commentCount: math.max(0, reel.commentCount - 1),
          comments: reel.comments
              .where((item) => item.id != comment.id)
              .toList(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _items = _items.where((item) => item.id != comment.id).toList();
        _ownIds = {..._ownIds}..remove(comment.id);
        if (_editing?.id == comment.id) {
          _editing = null;
          _input.clear();
        }
      });
    } on AppException catch (error) {
      if (error.statusCode == 404) {
        _lostOwnership(comment.id, 'deleted');
      } else if (mounted) {
        setState(() => _sendError = error.message);
      }
    }
  }

  /// A 404 on an edit or delete means the API does not see this customer as
  /// the author, so the controls come off that comment.
  void _lostOwnership(String commentId, String verb) {
    _social.forgetOwnComment(_customerId, commentId).ignore();
    if (!mounted) return;
    setState(() {
      _ownIds = {..._ownIds}..remove(commentId);
      if (_editing?.id == commentId) {
        _editing = null;
        _input.clear();
      }
      _sendError = 'This comment can no longer be $verb.';
    });
  }

  void _startEdit(ReelComment comment) {
    setState(() {
      _editing = comment;
      _sendError = null;
      _input.text = comment.body;
      _input.selection = TextSelection.collapsed(offset: comment.body.length);
    });
    _focus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _sendError = null;
    });
    _input.clear();
  }

  static List<ReelComment> _replaced(
    List<ReelComment> comments,
    ReelComment updated,
  ) => [for (final item in comments) item.id == updated.id ? updated : item];

  @override
  Widget build(BuildContext context) {
    final reel = ref.watch(
      reelFeedProvider.select((feed) {
        for (final reel in feed.valueOrNull?.reels ?? const <Reel>[]) {
          if (reel.id == widget.reelId) return reel;
        }
        return null;
      }),
    );
    final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));

    final media = MediaQuery.of(context);
    // Shrinks to what the keyboard leaves, so the composer stays in view.
    final height = math.min(
      media.size.height * 0.72,
      media.size.height - media.viewInsets.bottom - media.padding.top - 56,
    );
    final count = math.max(reel?.commentCount ?? 0, _items.length);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: math.max(height, 220),
        child: Column(
          children: [
            _SheetHeader(count: count, likers: reel?.likersLine),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _buildList(signedIn)),
            const Divider(height: 1, color: AppColors.border),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: signedIn ? _buildComposer() : const _SignInRow(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(bool signedIn) {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
      }
      return _EmptyComments(error: _listError);
    }

    final hasMore = _cursor != null && _cursor!.isNotEmpty;
    return Column(
      children: [
        if (_listError != null) _Banner(message: _listError!),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
            itemCount: _items.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return _LoadMoreRow(loading: _loadingMore, onTap: _loadMore);
              }
              final comment = _items[index];
              return _CommentTile(
                comment: comment,
                own: signedIn && _ownIds.contains(comment.id),
                onEdit: () => _startEdit(comment),
                onDelete: () => _delete(comment),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    final editing = _editing;
    final canSend = _input.text.trim().isNotEmpty && !_sending;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editing != null)
          Row(
            children: [
              const Icon(
                Icons.edit_rounded,
                size: 15,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Editing your comment', style: _metaStyle),
              ),
              TextButton(
                onPressed: _sending ? null : _cancelEdit,
                child: const Text('Cancel'),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                maxLength: _maxBody,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  counterText: '',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: canSend ? _submit : null,
              tooltip: editing != null ? 'Save' : 'Post',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
              ),
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryForeground,
                      ),
                    )
                  : Icon(
                      editing != null
                          ? Icons.check_rounded
                          : Icons.send_rounded,
                      size: 20,
                    ),
            ),
          ],
        ),
        // Anonymity is chosen when posting; an edit keeps whatever it was.
        if (editing == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _sending
                      ? null
                      : () => setState(() => _anonymous = !_anonymous),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _anonymous
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 20,
                          color: _anonymous
                              ? AppColors.purple
                              : AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 6),
                        const Text('Post anonymously', style: _metaStyle),
                      ],
                    ),
                  ),
                ),
                if (_anonymous) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nickname,
                      maxLength: _maxNickname,
                      enabled: !_sending,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Nickname (optional)',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (_sendError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _sendError!,
              style: _metaStyle.copyWith(color: AppColors.destructive),
            ),
          ),
      ],
    );
  }
}

const TextStyle _metaStyle = TextStyle(
  fontFamily: AppTypography.sansFamily,
  fontSize: 12.5,
  color: AppColors.mutedForeground,
);

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.count, required this.likers});

  final int count;
  final String? likers;

  @override
  Widget build(BuildContext context) {
    final summary = count == 0
        ? 'No comments yet'
        : '${compactCount(count)} ${count == 1 ? 'comment' : 'comments'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comments',
                  style: AppTypography.display(20, color: AppColors.foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  likers == null ? summary : '$summary · $likers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SheetCloseButton(),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.own,
    required this.onEdit,
    required this.onDelete,
  });

  final ReelComment comment;
  final bool own;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: comment.isCustomer
              ? AppColors.primary
              : AppColors.mist,
          child: comment.isCustomer
              ? Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    color: AppColors.primaryForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.sansFamily,
                        color: AppColors.foreground,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_timeAgo(comment.createdAt)}'
                    '${comment.isEdited ? ' · edited' : ''}',
                    style: _metaStyle,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                comment.body,
                style: const TextStyle(
                  fontFamily: AppTypography.sansFamily,
                  color: AppColors.foreground,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (own)
          PopupMenuButton<String>(
            tooltip: 'Comment options',
            iconSize: 18,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.mutedForeground,
            ),
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : TextButton(
              onPressed: onTap,
              child: const Text('Load more comments'),
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: _metaStyle),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mode_comment_outlined,
              size: 32,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              error ?? 'Start the conversation',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.sansFamily,
                color: AppColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (error == null) ...[
              const SizedBox(height: 4),
              const Text(
                'Be the first to say something about this reel.',
                textAlign: TextAlign.center,
                style: _metaStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stands in for the composer when nobody is signed in — comments are still
/// readable above it.
class _SignInRow extends StatelessWidget {
  const _SignInRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Sign in to like and comment.',
            style: TextStyle(
              fontFamily: AppTypography.sansFamily,
              color: AppColors.foreground,
              fontSize: 14,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // The sheet sits on the root navigator; close it before the
            // login page opens, so signing in lands back on the feed.
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push(AppRoutes.login);
          },
          child: const Text('Sign in'),
        ),
      ],
    );
  }
}

/// "now", "5m", "3h", "2d", then a date.
String _timeAgo(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return DateFormat.MMMd().format(at.toLocal());
}
