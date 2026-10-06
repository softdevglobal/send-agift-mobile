import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/reviews_repository.dart';
import '../../domain/product_review.dart';
import '../widgets/star_rating.dart';

const _titleMax = 120;
const _bodyMax = 5000;

/// A photo chosen but not yet sent to storage.
class _PendingPhoto {
  const _PendingPhoto({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Writing or editing a review of a delivered gift.
///
/// The overall score is the only one a customer must give: the three
/// sub-scores follow it until one is set on its own, so leaving five stars is
/// a single tap while anyone with more to say can still pull them apart.
class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.orderItemId,
    this.existing,
    this.productName,
  });

  final String orderItemId;

  /// The review being edited, when there already is one for this line.
  final ProductReview? existing;
  final String? productName;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  late int _rating;
  late int _quality;
  late int _shipping;
  late int _service;
  late bool _anonymous;

  /// Photos already on the review, kept by reference so an edit that does not
  /// touch them re-sends the same keys rather than re-uploading.
  late List<ReviewMediaUpload> _keptMedia;
  final List<_PendingPhoto> _newPhotos = [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _rating = existing?.rating ?? 0;
    _quality = existing?.productQualityRating ?? 0;
    _shipping = existing?.shippingRating ?? 0;
    _service = existing?.sellerServiceRating ?? 0;
    _anonymous = existing?.isAnonymous ?? false;
    _titleController.text = existing?.title ?? '';
    _bodyController.text = existing?.body ?? '';
    _keptMedia = [
      for (final item in existing?.media ?? const <ReviewMedia>[])
        ReviewMediaUpload(
          objectPath: item.objectPath,
          mimeType: item.mimeType,
          sizeBytes: 0,
        ),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  int get _mediaCount => _keptMedia.length + _newPhotos.length;
  int get _room => ReviewsRepository.maxMedia - _mediaCount;

  /// Setting the overall score carries the untouched sub-scores with it. Once
  /// one has been set on its own it stops following, so an explicit
  /// "delivery was a 2" is never quietly overwritten.
  void _setOverall(int next) {
    setState(() {
      if (_quality == 0 || _quality == _rating) _quality = next;
      if (_shipping == 0 || _shipping == _rating) _shipping = next;
      if (_service == 0 || _service == _rating) _service = next;
      _rating = next;
    });
  }

  Future<void> _pickPhotos() async {
    if (_room <= 0) {
      setState(
        () => _error =
            'You can attach up to ${ReviewsRepository.maxMedia} photos.',
      );
      return;
    }
    try {
      final files = _room == 1
          ? [
              ?await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 2048,
              ),
            ]
          : await _picker.pickMultiImage(
              imageQuality: 85,
              maxWidth: 2048,
              limit: _room,
            );
      final picked = <_PendingPhoto>[];
      for (final file in files.take(_room)) {
        picked.add(
          _PendingPhoto(
            name: file.name,
            mimeType: file.mimeType ?? _imageMimeType(file.name),
            bytes: await file.readAsBytes(),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _newPhotos.addAll(picked);
        _error = null;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(
        () => _error = 'Allow photo access in Settings to add photos.',
      );
    }
  }

  Future<void> _submit() async {
    if (_rating < 1) {
      setState(() => _error = 'Choose an overall rating first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = ref.read(reviewsRepositoryProvider);
    try {
      // Upload anything new first: the review is saved with storage keys, so
      // a failed upload must not leave a half-written review behind.
      final uploaded = <ReviewMediaUpload>[];
      for (final photo in _newPhotos) {
        uploaded.add(
          await repository.upload(
            fileName: photo.name,
            mimeType: photo.mimeType,
            bytes: photo.bytes,
          ),
        );
      }

      final draft = ReviewDraft(
        rating: _rating,
        qualityRating: _quality,
        shippingRating: _shipping,
        serviceRating: _service,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        body: _bodyController.text.trim().isEmpty
            ? null
            : _bodyController.text.trim(),
        isAnonymous: _anonymous,
        media: [..._keptMedia, ...uploaded],
      );

      final existing = widget.existing;
      final saved = existing == null
          ? await repository.create(widget.orderItemId, draft)
          : await repository.update(existing.id, draft);

      // Every list that shows this customer's reviews is now stale.
      ref.invalidate(myReviewsProvider);
      ref.invalidate(productReviewsProvider(saved.productId));
      ref.invalidate(productReviewSummaryProvider(saved.productId));

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit review' : 'Write a review')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: [
            if (widget.productName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.productName!,
                  style: theme.textTheme.titleMedium,
                ),
              ),

            // The headline rating, given the room it deserves.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Column(
                children: [
                  Text('How was it overall?', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 16),
                  StarPicker(
                    value: _rating,
                    onChanged: _setOverall,
                    label: 'Overall rating',
                    starSize: 44,
                    showWord: true,
                    enabled: !_saving,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _SubRating(
              label: 'Gift quality',
              value: _quality,
              enabled: !_saving,
              onChanged: (value) => setState(() => _quality = value),
            ),
            _SubRating(
              label: 'Delivery',
              value: _shipping,
              enabled: !_saving,
              onChanged: (value) => setState(() => _shipping = value),
            ),
            _SubRating(
              label: 'Seller service',
              value: _service,
              enabled: !_saving,
              onChanged: (value) => setState(() => _service = value),
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              enabled: !_saving,
              maxLength: _titleMax,
              decoration: const InputDecoration(
                labelText: 'Headline',
                hintText: 'Arrived beautifully wrapped',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              enabled: !_saving,
              maxLength: _bodyMax,
              maxLines: 6,
              minLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your review',
                hintText:
                    'What did you and the recipient think? Anything the next buyer should know?',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 12),
            Text('Photos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _PhotoRow(
              kept: _keptMedia,
              pending: _newPhotos,
              enabled: !_saving,
              onAdd: _pickPhotos,
              onRemoveKept: (index) =>
                  setState(() => _keptMedia.removeAt(index)),
              onRemovePending: (index) =>
                  setState(() => _newPhotos.removeAt(index)),
            ),

            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _anonymous = value),
              title: const Text('Post as Anonymous'),
              subtitle: const Text('Your name is hidden on the gift page.'),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving || _rating < 1 ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(editing ? 'Save changes' : 'Post review'),
            ),
          ],
        ),
      ),
    );
  }

  static String _imageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _SubRating extends StatelessWidget {
  const _SubRating({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          StarPicker(
            value: value,
            onChanged: onChanged,
            label: label,
            starSize: 26,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.kept,
    required this.pending,
    required this.enabled,
    required this.onAdd,
    required this.onRemoveKept,
    required this.onRemovePending,
  });

  final List<ReviewMediaUpload> kept;
  final List<_PendingPhoto> pending;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveKept;
  final ValueChanged<int> onRemovePending;

  @override
  Widget build(BuildContext context) {
    final full = kept.length + pending.length >= ReviewsRepository.maxMedia;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < kept.length; index++)
          _Thumb(
            onRemove: enabled ? () => onRemoveKept(index) : null,
            // An already-saved photo has no local bytes to preview, so it
            // shows as a placeholder tile rather than a broken image.
            child: const ColoredBox(
              color: AppColors.muted,
              child: Center(child: Icon(Icons.image_rounded, size: 20)),
            ),
          ),
        for (var index = 0; index < pending.length; index++)
          _Thumb(
            onRemove: enabled ? () => onRemovePending(index) : null,
            child: Image.memory(pending[index].bytes, fit: BoxFit.cover),
          ),
        if (!full)
          GestureDetector(
            onTap: enabled ? onAdd : null,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.border),
                color: AppColors.muted,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.onRemove, required this.child});

  final VoidCallback? onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: child,
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
