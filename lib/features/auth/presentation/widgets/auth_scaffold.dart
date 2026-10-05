import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/fade_slide_in.dart';

/// Shared chrome for sign-in and registration: brand mark, title, and the
/// reminder that browsing never needed an account in the first place.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    this.logoWidth = 132,
    this.header,
    this.eyebrow,
    this.titleWidget,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  /// Width of the [BrandLockup]. Register passes something smaller than
  /// login's — its form runs longer, so a full-size lockup pushes the first
  /// field too far down.
  final double logoWidth;

  /// Optional extra content between the subtitle and the form — register
  /// uses this for its "why sign up" row.
  final Widget? header;

  /// Optional small label above the title (e.g. a pill).
  final Widget? eyebrow;

  /// Replaces the plain [title] text when the heading needs styling.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Two soft brand-colour blobs behind the header — quiet enough not
          // to fight the form, present enough that sign-in doesn't open on a
          // blank page.
          Positioned(
            top: -70,
            right: -50,
            child: _GlowBlob(size: 240, color: AppColors.purple),
          ),
          Positioned(
            top: 60,
            left: -70,
            child: _GlowBlob(size: 190, color: AppColors.teal),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                4,
                AppTheme.gutter,
                32,
              ),
              children: [
                // No app bar: the back arrow sits on the page itself, so
                // the header has no separate strip above it.
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: const Key('auth-back'),
                    tooltip: 'Back',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                ),
                FadeSlideIn(
                  // A ListView hands its children a tight, full-width
                  // constraint, which would otherwise force the image wider
                  // than `logoWidth` and stretch it back up regardless of
                  // what's asked for. Align relaxes that back to loose so
                  // the requested width actually takes effect — and centers
                  // it, since a lockup floating at the left edge reads as
                  // unfinished rather than deliberate.
                  child: Align(child: BrandLockup(width: logoWidth)),
                ),
                // Clear space between the logo and the heading below it.
                const SizedBox(height: 40),
                if (eyebrow != null) ...[
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 40),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: eyebrow!,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FadeSlideIn(
                  delay: const Duration(milliseconds: 60),
                  child:
                      titleWidget ??
                      Text(title, style: AppTypography.display(28)),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                if (header != null) ...[
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: header!,
                  ),
                ],
                const SizedBox(height: 28),
                // Not wrapped in FadeSlideIn: the screen that builds `form`
                // stages its own fields so each one visibly steps in, rather
                // than fading in as one block on top of a field-level cascade
                // no one would see happen underneath it.
                form,
                const SizedBox(height: 22),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 280),
                  child: footer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft, edge-faded colour wash used behind the auth header.
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Labelled text field matching the web forms.
///
/// A password field (`obscureText: true`) gets an eye toggle so it can be
/// checked before submitting; the visibility is local UI state, unrelated to
/// [obscureText] itself, which still just marks the field as sensitive.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.prefixIcon,
  });

  final IconData? prefixIcon;
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _hidden = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText && _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: AppColors.mutedForeground,
                    ),
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Inline error banner for failed sign-in/registration.
class AuthAlert extends StatelessWidget {
  const AuthAlert({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.destructive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.destructive,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
