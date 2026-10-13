import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/storefront_decor.dart';
import '../../data/reviews_repository.dart';
import '../../domain/product_review.dart';
import '../../domain/review_moods.dart';
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

  /// Quick-pick highlights write the headline until the person types their own.
  final List<String> _picked = [];
  bool _titleIsTheirs = false;

  /// Set once the review is saved: a thank-you moment, then the screen closes.
  ProductReview? _savedReview;
  Timer? _closeTimer;

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
    _titleIsTheirs = (existing?.title ?? '').trim().isNotEmpty;
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
    _closeTimer?.cancel();
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
      // Highlights suit a score's tone; drop the ones that no longer fit.
      final fits = reviewHighlights(next).toSet();
      final before = _picked.length;
      _picked.removeWhere((chip) => !fits.contains(chip));
      if (_picked.length != before && !_titleIsTheirs) {
        _titleController.text = _picked.take(3).join(' · ');
      }
      _rating = next;
    });
  }

  void _toggleHighlight(String chip) {
    setState(() {
      _picked.contains(chip) ? _picked.remove(chip) : _picked.add(chip);
      if (!_titleIsTheirs) {
        _titleController.text = _picked.take(3).join(' · ');
      }
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
      setState(() => _error = 'Allow photo access in Settings to add photos.');
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
      setState(() => _savedReview = saved);
      _closeTimer = Timer(const Duration(milliseconds: 2400), _close);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() {
    _closeTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop(_savedReview);
  }

  @override
  Widget build(BuildContext context) {
    if (_savedReview != null) {
      return _ThankYou(editing: widget.existing != null, onDone: _close);
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    final mood = reviewMood(_rating);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.foreground,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(editing ? 'Edit review' : 'Write a review'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // The banner: one question, and stars that answer back.
                Container(
                  color: AppColors.foreground,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.gutter,
                    4,
                    AppTheme.gutter,
                    26,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          editing ? 'EDIT YOUR REVIEW' : 'YOUR TURN',
                          style: AppTypography.tag(color: AppColors.foreground),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        runSpacing: 4,
                        children: [
                          Text(
                            'HOW DID THE GIFT ',
                            style: AppTypography.poster(
                              30,
                              color: Colors.white,
                            ),
                          ),
                          Marker('LAND?', style: AppTypography.poster(30)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.productName != null
                            ? 'Tell us about ${widget.productName}.'
                            : 'Tell us how it arrived.',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: StarPicker(
                          value: _rating,
                          onChanged: _setOverall,
                          label: 'Overall rating',
                          starSize: 46,
                          enabled: !_saving,
                          unlitColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.25),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Column(
                            key: ValueKey(_rating),
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _rating > 0
                                      ? AppColors.teal
                                      : Colors.white12,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mood.icon,
                                      size: 18,
                                      color: _rating > 0
                                          ? AppColors.tealForeground
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        mood.headline,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _rating > 0
                                              ? AppColors.tealForeground
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                mood.nudge,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.4,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppTheme.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('WHAT STOOD OUT?'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final chip in reviewHighlights(_rating))
                            _HighlightChip(
                              label: chip,
                              selected: _picked.contains(chip),
                              onTap: _saving
                                  ? null
                                  : () => _toggleHighlight(chip),
                            ),
                        ],
                      ),

                      const SizedBox(height: 26),
                      const _SectionLabel('RATE THE DETAILS', hint: 'Optional'),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(color: AppColors.boxBorder),
                        ),
                        child: Column(
                          children: [
                            _SubRating(
                              icon: Icons.card_giftcard_rounded,
                              label: 'The gift',
                              value: _quality,
                              enabled: !_saving,
                              onChanged: (v) => setState(() => _quality = v),
                            ),
                            _SubRating(
                              icon: Icons.local_shipping_outlined,
                              label: 'Delivery',
                              value: _shipping,
                              enabled: !_saving,
                              onChanged: (v) => setState(() => _shipping = v),
                            ),
                            _SubRating(
                              icon: Icons.handshake_outlined,
                              label: 'The seller',
                              value: _service,
                              enabled: !_saving,
                              onChanged: (v) => setState(() => _service = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),
                      const _SectionLabel('TELL THE STORY'),
                      TextField(
                        controller: _titleController,
                        enabled: !_saving,
                        maxLength: _titleMax,
                        onChanged: (value) =>
                            _titleIsTheirs = value.trim().isNotEmpty,
                        decoration: const InputDecoration(
                          labelText: 'Sum it up in a line',
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
                          labelText: 'What did you and the recipient think?',
                          hintText:
                              'The moment it arrived, the reaction, anything '
                              'the next buyer should know…',
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 18),
                      const _SectionLabel('SHOW US'),
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

                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(color: AppColors.boxBorder),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _anonymous,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _anonymous = value),
                          title: const Text(
                            'Post as Anonymous',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Your name will not be shown with this review.',
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.destructive,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Always in reach: the hint and the button.
          Container(
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              12,
              AppTheme.gutter,
              12 + MediaQuery.of(context).padding.bottom * 0.5,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _rating < 1
                      ? 'Pick a star rating to continue.'
                      : 'Looking good. Ready when you are.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('review-submit'),
                    onPressed: _saving || _rating < 1 ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(editing ? 'Save changes' : 'Share my review'),
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTypography.eyebrow)),
          if (hint != null)
            Text(hint!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.foreground : AppColors.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.foreground : AppColors.boxBorder,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubRating extends StatelessWidget {
  const _SubRating({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          StarPicker(
            value: value,
            onChanged: onChanged,
            label: label,
            starSize: 24,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

/// The moment after posting: a thank-you, then the screen closes itself.
class _ThankYou extends StatelessWidget {
  const _ThankYou({required this.editing, required this.onDone});

  final bool editing;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.foreground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gutter * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 38,
                      color: AppColors.tealForeground,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      editing ? 'ALL ' : 'THANK ',
                      style: AppTypography.poster(38, color: Colors.white),
                    ),
                    Marker(
                      editing ? 'UPDATED' : 'YOU',
                      style: AppTypography.poster(38),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  editing
                      ? 'Your changes are live on the gift.'
                      : 'Your review is live. It will help the next person '
                            'choosing a gift.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 26),
                OutlinedButton(
                  key: const Key('review-done'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
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
    final thumbs = Wrap(
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
      ],
    );
    final dropZone = full
        ? const SizedBox.shrink()
        : GestureDetector(
            onTap: enabled ? onAdd : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add photos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Photos of the gift as it arrived help other '
                          'buyers most.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kept.isNotEmpty || pending.isNotEmpty) ...[
          thumbs,
          const SizedBox(height: 10),
        ],
        dropZone,
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
