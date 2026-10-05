import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dial_codes.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../data/auth_controller.dart';
import '../../data/countries_provider.dart';
import '../widgets/auth_header_parts.dart';
import '../widgets/auth_scaffold.dart';

/// Customer registration — just enough to start gifting. A photo and
/// delivery addresses are added later from the Account tab. Sellers and
/// admins register on the web app only.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

/// Who the customer is gifting as; sent as `customer_type`.
const _giftingAs = <({String value, String label, String hint, IconData icon})>[
  (
    value: 'individual',
    label: 'Just me',
    hint: 'Gifts for friends',
    icon: Icons.favorite_rounded,
  ),
  (
    value: 'family',
    label: 'Family',
    hint: 'One home',
    icon: Icons.people_alt_rounded,
  ),
  (
    value: 'business',
    label: 'Business',
    hint: 'Teams & clients',
    icon: Icons.work_rounded,
  ),
];

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _customerType = 'individual';
  String? _countryId;
  String _dialIso = 'LK';
  bool _submitting = false;
  String? _error;

  /// The email the server said already has an account.
  String? _takenEmail;

  @override
  void initState() {
    super.initState();
    // The strength meter and the match tick follow every keystroke.
    _passwordController.addListener(_refresh);
    _confirmController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_countryId == null) {
      setState(() => _error = 'Choose the country you are gifting from.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _takenEmail = null;
    });

    try {
      await ref
          .read(authProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
            countryId: _countryId!,
            phone: '$_dial ${_phoneController.text.trim()}',
            customerType: _customerType,
          );
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(AppRoutes.account);
    } on AppException catch (error) {
      if (!mounted) return;
      // 409: this email already has an account — offer sign-in, not an error.
      if (error.statusCode == 409) {
        setState(() => _takenEmail = _emailController.text.trim());
      } else {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not create your account. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _dial => dialCodes
      .firstWhere((d) => d.iso2 == _dialIso, orElse: () => dialCodes.first)
      .dial;

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(countriesProvider);
    final password = _passwordController.text;
    final matches =
        _confirmController.text.isNotEmpty &&
        _confirmController.text == password;

    return AuthScaffold(
      title: 'Start sending smiles',
      titleWidget: const AuthHeadline(lead: 'Start sending ', accent: 'smiles'),
      subtitle:
          'Create your account, then add a photo and delivery addresses '
          'whenever you like.',
      logoWidth: 84,
      header: const AuthPerkChips(),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              AuthAlert(message: _error!),
              const SizedBox(height: 18),
            ],
            if (_takenEmail != null) ...[
              _EmailTakenCard(
                email: _takenEmail!,
                onSignIn: () => context.pushReplacement(AppRoutes.login),
                onChange: () {
                  setState(() {
                    _takenEmail = null;
                    _emailController.clear();
                  });
                },
              ),
              const SizedBox(height: 18),
            ],
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "I'm gifting as",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final option in _giftingAs) ...[
                        Expanded(
                          child: _ChoiceCard(
                            key: Key('gifting-as-${option.value}'),
                            label: option.label,
                            hint: option.hint,
                            icon: option.icon,
                            selected: _customerType == option.value,
                            onTap: _submitting
                                ? null
                                : () => setState(
                                    () => _customerType = option.value,
                                  ),
                          ),
                        ),
                        if (option != _giftingAs.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: AuthField(
                label: 'Your name',
                prefixIcon: Icons.person_outline_rounded,
                controller: _nameController,
                hintText: 'How should we greet you?',
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 230),
              child: AuthField(
                label: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                controller: _emailController,
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value == null ||
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(value.trim()))
                    ? 'Enter a valid email address'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Country',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 7),
                  countries.when(
                    loading: () =>
                        const _CountryPlaceholder(label: 'Loading countries…'),
                    error: (error, stack) => const _CountryPlaceholder(
                      label: 'Countries unavailable — try again later',
                    ),
                    data: (list) => DropdownButtonFormField<String>(
                      initialValue: _countryId,
                      isExpanded: true,
                      hint: const Text('Where are you gifting from?'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.public_rounded),
                      ),
                      items: [
                        for (final country in list)
                          DropdownMenuItem(
                            value: country.id,
                            child: Text('${country.name} (${country.isoCode})'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _countryId = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 275),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phone number',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 108,
                        child: DropdownButtonFormField<String>(
                          key: const Key('register-dial'),
                          initialValue: _dialIso,
                          isExpanded: true,
                          selectedItemBuilder: (_) => [
                            for (final code in dialCodes) Text(code.dial),
                          ],
                          items: [
                            for (final code in dialCodes)
                              DropdownMenuItem(
                                value: code.iso2,
                                child: Text(
                                  '${code.dial}  ${code.name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _dialIso = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: const Key('register-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: '77 123 4567',
                          ),
                          validator: (value) =>
                              (value == null ||
                                  value.replaceAll(RegExp(r'\D'), '').length <
                                      7)
                              ? 'Enter your phone number'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 290),
              child: AuthField(
                label: 'Create a password',
                controller: _passwordController,
                hintText: 'At least 8 characters',
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.length < 8)
                    ? 'Use at least 8 characters'
                    : null,
              ),
            ),
            if (password.isNotEmpty) ...[
              const SizedBox(height: 8),
              _StrengthMeter(password: password),
            ],
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 320),
              child: Stack(
                children: [
                  AuthField(
                    label: 'Confirm password',
                    controller: _confirmController,
                    hintText: 'Type it once more',
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => value != _passwordController.text
                        ? "The passwords don't match"
                        : null,
                  ),
                  if (matches)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Matches',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: AuthPrimaryButton(
                key: const Key('register-submit'),
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
                label: 'Create my account',
              ),
            ),
          ],
        ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: () => context.pushReplacement(AppRoutes.login),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the email already has an account: a way forward, not an error.
class _EmailTakenCard extends StatelessWidget {
  const _EmailTakenCard({
    required this.email,
    required this.onSignIn,
    required this.onChange,
  });

  final String email;
  final VoidCallback onSignIn;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('email-taken'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cream, Color(0xFFFDEEF6)],
        ),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Text('👋', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back — you’re already in!',
                      style: AppTypography.display(18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$email already has a SendAGift account. Sign in to '
                      'pick up where you left off.',
                      style: const TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('email-taken-sign-in'),
                  onPressed: onSignIn,
                  child: const Text('Sign in instead'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onChange,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Different email'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.07)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: selected ? AppColors.purple : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.purple : AppColors.muted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: selected
                          ? Colors.white
                          : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four bars that fill as the password gets stronger.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.password});

  final String password;

  static const _levels = [
    ('Too short', AppColors.destructive),
    ('Okay', Color(0xFFF59E0B)),
    ('Good', Color(0xFF84CC16)),
    ('Strong', Color(0xFF10B981)),
    ('Excellent', Color(0xFF059669)),
  ];

  /// 0–4: length, mixed case, digits and symbols.
  static int score(String password) {
    if (password.length < 8) return 0;
    var score = 1.0;
    if (password.length >= 12) score += 1;
    final mixedCase =
        RegExp('[a-z]').hasMatch(password) &&
        RegExp('[A-Z]').hasMatch(password);
    if (mixedCase) score += 1;
    final digit = RegExp(r'\d').hasMatch(password);
    final symbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    if (digit && symbol) {
      score += 1;
    } else if (digit || symbol) {
      score += 0.5;
    }
    return score.floor().clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final s = score(password);
    final (label, color) = _levels[s];
    final filled = s == 0 ? 1 : s;
    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i <= filled ? color : AppColors.muted,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 6),
        SizedBox(
          width: 66,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryPlaceholder extends StatelessWidget {
  const _CountryPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
