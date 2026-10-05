import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/reviews_repository.dart';
import '../../domain/product_review.dart';
import '../widgets/review_card.dart';
import '../widgets/review_summary_panel.dart';

/// Every review for one gift, paged as the customer scrolls.
class ProductReviewsScreen extends ConsumerStatefulWidget {
  const ProductReviewsScreen({
    super.key,
    required this.productId,
    this.productName,
  });

  final String productId;
  final String? productName;

  @override
  ConsumerState<ProductReviewsScreen> createState() =>
      _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends ConsumerState<ProductReviewsScreen> {
  final _scrollController = ScrollController();

  final List<ProductReview> _reviews = [];
  ReviewSummary _summary = ReviewSummary.empty;
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final repository = ref.read(reviewsRepositoryProvider);
    try {
      final results = await Future.wait([
        repository.summaryForProduct(widget.productId),
        repository.listForProduct(widget.productId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as ReviewSummary;
        final page = results[1] as ReviewPage;
        _reviews
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _exhausted = page.nextCursor == null;
        _loading = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(reviewsRepositoryProvider)
          .listForProduct(widget.productId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.items);
        _cursor = page.nextCursor;
        _exhausted = page.nextCursor == null;
      });
    } on AppException {
      // A failed page just stops paging; what has loaded stays readable.
      if (mounted) setState(() => _exhausted = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Votes are applied to the row first and rolled back if the call fails. A
  /// thumbs-up that waits for a round trip feels broken at this size.
  Future<void> _vote(ProductReview review) async {
    final signedIn = ref.read(authProvider).isSignedIn;
    if (!signedIn) return;

    final index = _reviews.indexWhere((row) => row.id == review.id);
    if (index < 0) return;
    final previous = _reviews[index];
    final nowVoted = !previous.hasVoted;

    setState(() {
      _reviews[index] = previous.withVote(
        voted: nowVoted,
        helpfulCount: previous.helpfulCount + (nowVoted ? 1 : -1),
      );
    });

    try {
      final repository = ref.read(reviewsRepositoryProvider);
      final count = nowVoted
          ? await repository.voteHelpful(review.id)
          : await repository.clearVote(review.id);
      if (!mounted) return;
      setState(() {
        _reviews[index] = _reviews[index].withVote(
          voted: nowVoted,
          helpfulCount: count,
        );
      });
    } on AppException {
      if (!mounted) return;
      setState(() => _reviews[index] = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      authProvider.select((auth) => auth.isSignedIn),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.productName ?? 'Reviews')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppTheme.gutter),
                  itemCount: _reviews.length + 2,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ReviewSummaryPanel(summary: _summary);
                    }
                    if (index == _reviews.length + 1) {
                      return _loadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox(height: 12);
                    }
                    final review = _reviews[index - 1];
                    return ReviewCard(
                      review: review,
                      onVote: signedIn ? (_) => _vote(review) : null,
                    );
                  },
                ),
              ),
      ),
    );
  }
}
