import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/auth_controller.dart';
import '../../data/social_sign_in.dart';
import '../../domain/social_signup.dart';

/// "Continue with Google / Facebook". The provider's own sheet confirms who
/// the person is; the API then signs them in, or hands back a sign-up that
/// still needs a country and phone.
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({
    super.key,
    required this.onSignedIn,
    required this.onNeedsProfile,
    required this.onError,
    this.verb = 'Continue',
  });

  final VoidCallback onSignedIn;
  final ValueChanged<SocialSignup> onNeedsProfile;
  final ValueChanged<String> onError;
  final String verb;

  /// Whether any provider is configured; without one there's nothing to show.
  static bool get enabled =>
      SocialSignInClient.googleEnabled || SocialSignInClient.facebookEnabled;

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  final _client = SocialSignInClient();
  String? _busy;

  Future<void> _start(String provider) async {
    setState(() => _busy = provider);
    try {
      final token = provider == 'google'
          ? await _client.google()
          : await _client.facebook();
      if (token == null) return; // closed the provider's sheet
      final pending = await ref.read(authProvider.notifier).socialSignIn(token);
      if (!mounted) return;
      if (pending == null) {
        widget.onSignedIn();
      } else {
        widget.onNeedsProfile(pending);
      }
    } on AppException catch (error) {
      if (mounted) widget.onError(error.message);
    } catch (_) {
      if (mounted) widget.onError('Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SocialSignInButtons.enabled) return const SizedBox.shrink();
    return Column(
      children: [
        if (SocialSignInClient.googleEnabled)
          _ProviderButton(
            key: const Key('social-google'),
            label: '${widget.verb} with Google',
            background: AppColors.surface,
            foreground: AppColors.foreground,
            border: AppColors.border,
            mark: const _GoogleMark(),
            busy: _busy == 'google',
            onPressed: _busy == null ? () => _start('google') : null,
          ),
        if (SocialSignInClient.googleEnabled &&
            SocialSignInClient.facebookEnabled)
          const SizedBox(height: 10),
        if (SocialSignInClient.facebookEnabled)
          _ProviderButton(
            key: const Key('social-facebook'),
            label: '${widget.verb} with Facebook',
            background: const Color(0xFF1877F2),
            foreground: Colors.white,
            mark: const Icon(Icons.facebook, color: Colors.white, size: 22),
            busy: _busy == 'facebook',
            onPressed: _busy == null ? () => _start('facebook') : null,
          ),
      ],
    );
  }
}

/// "or use your email" between the social buttons and the form.
class SocialDivider extends StatelessWidget {
  const SocialDivider({super.key, this.label = 'or use your email'});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (!SocialSignInButtons.enabled) return const SizedBox.shrink();
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.mark,
    required this.busy,
    required this.onPressed,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final Widget mark;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: StadiumBorder(
        side: border == null ? BorderSide.none : BorderSide(color: border!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      )
                    : mark,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

/// Google's four-colour "G", drawn so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size.square(22), painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const pi = 3.1415926535;
    canvas.drawArc(rect, -pi / 4, -pi / 2, false, arc(const Color(0xFFEA4335)));
    canvas.drawArc(
      rect,
      -3 * pi / 4,
      -pi / 2,
      false,
      arc(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      3 * pi / 4,
      -pi / 2,
      false,
      arc(const Color(0xFF34A853)),
    );
    canvas.drawArc(rect, pi / 4, -pi / 4, false, arc(const Color(0xFF4285F4)));
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        size.height / 2 - stroke / 2,
        size.width / 2 - stroke / 4,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
