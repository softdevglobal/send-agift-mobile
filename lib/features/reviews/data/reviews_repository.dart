import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/product_review.dart';

/// Product reviews over the reviews API.
///
/// Photos never travel through the API itself: each file is presigned into the
/// `review-photo` / `review-video` folder, PUT straight to storage, and then
/// referenced by its key when the review is saved. The same path chat
/// attachments take.
class ReviewsRepository {
  ReviewsRepository(this._client);

  final ApiClient _client;

  /// Talks to the presigned storage URL directly. No base URL and no API
  /// token, because the signature in the URL is the permission.
  final Dio _storage = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static const int pageSize = 10;

  /// How many files one review may carry; the API rejects a tenth.
  static const int maxMedia = 9;

  // ── Public ──────────────────────────────────────────────────────────────

  Future<ReviewSummary> summaryForProduct(String productId) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/products/$productId/reviews/summary',
      );
      return ReviewSummary.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<ReviewPage> listForProduct(
    String productId, {
    String? cursor,
    int limit = pageSize,
  }) {
    return _page('/products/$productId/reviews', cursor: cursor, limit: limit);
  }

  // ── The signed-in customer's own reviews ────────────────────────────────

  Future<ReviewPage> listMine({String? cursor, int limit = 100}) {
    return _page('/customers/me/reviews', cursor: cursor, limit: limit);
  }

  /// Every review this customer has written, following the cursor to the end.
  ///
  /// An order screen needs to know, per line, whether it has been reviewed.
  /// Asking per line would be one request per item; this is one for the screen.
  Future<List<ProductReview>> listAllMine() async {
    final all = <ProductReview>[];
    String? cursor;
    // Bounded so a runaway cursor cannot page forever.
    for (var page = 0; page < 20; page++) {
      final result = await listMine(cursor: cursor);
      all.addAll(result.items);
      cursor = result.nextCursor;
      if (cursor == null) break;
    }
    return all;
  }

  Future<ProductReview> create(String orderItemId, ReviewDraft draft) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/customers/me/order-items/$orderItemId/reviews',
        data: draft.toJson(),
      );
      return ProductReview.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<ProductReview> update(String reviewId, ReviewDraft draft) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/customers/me/reviews/$reviewId',
        data: draft.toJson(),
      );
      return ProductReview.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<void> delete(String reviewId) async {
    try {
      await _client.dio.delete<void>('/customers/me/reviews/$reviewId');
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  // ── Votes ───────────────────────────────────────────────────────────────

  /// Marks the review helpful and returns the new count.
  Future<int> voteHelpful(String reviewId) async {
    try {
      final response = await _client.dio.put<Map<String, dynamic>>(
        '/reviews/$reviewId/vote',
        data: {'is_helpful': true},
      );
      return (response.data?['helpful_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  Future<int> clearVote(String reviewId) async {
    try {
      final response = await _client.dio.delete<Map<String, dynamic>>(
        '/reviews/$reviewId/vote',
      );
      return (response.data?['helpful_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  // ── Uploads ─────────────────────────────────────────────────────────────

  /// Presign → PUT → the media reference a review is saved with.
  Future<ReviewMediaUpload> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final isVideo = mimeType.startsWith('video/');
    final String uploadUrl;
    final String key;
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/media/presign-upload',
        data: {
          'filename': _safeFileName(fileName),
          'content_type': mimeType,
          'folder': isVideo ? 'review-video' : 'review-photo',
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
        data: Stream<List<int>>.value(bytes),
        options: Options(
          // Must match the content type the URL was signed for.
          contentType: mimeType,
          headers: {Headers.contentLengthHeader: bytes.length},
        ),
      );
    } on DioException {
      throw AppException('Could not upload $fileName. Please try again.');
    }

    return ReviewMediaUpload(
      objectPath: key,
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
  }

  Future<ReviewPage> _page(
    String path, {
    String? cursor,
    required int limit,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          'limit': limit,
          'cursor': ?cursor,
        },
      );
      return ReviewPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// Upload keys embed the file name; keep it to characters that need no escaping.
  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'review-photo.jpg' : cleaned;
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(apiClientProvider));
});

/// A product's rating summary. The headline above its reviews.
final productReviewSummaryProvider = FutureProvider.autoDispose
    .family<ReviewSummary, String>((ref, productId) {
      return ref.watch(reviewsRepositoryProvider).summaryForProduct(productId);
    });

/// The first page of a product's reviews.
final productReviewsProvider = FutureProvider.autoDispose
    .family<ReviewPage, String>((ref, productId) {
      return ref.watch(reviewsRepositoryProvider).listForProduct(productId);
    });

/// Every review the signed-in customer has written, newest first.
final myReviewsProvider = FutureProvider.autoDispose<List<ProductReview>>((
  ref,
) async {
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return const [];
  return ref.watch(reviewsRepositoryProvider).listAllMine();
});

/// The customer's reviews keyed by order item, so an order screen can tell
/// which of its lines have already been reviewed in one request.
final myReviewsByOrderItemProvider = FutureProvider.autoDispose
    .family<Map<String, ProductReview>, void>((ref, _) async {
      final reviews = await ref.watch(myReviewsProvider.future);
      return {for (final review in reviews) review.orderItemId: review};
    });
