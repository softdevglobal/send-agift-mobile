import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dial_codes.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/sheet_header.dart';
import '../../../auth/data/auth_controller.dart';
import '../../data/account_repository.dart';
import '../widgets/account_visuals.dart';
import '../widgets/address_form_sheet.dart' show errorMessage;

const _defaultDialIso = 'LK';

/// Splits a saved "+94 77 123 4567" into its country code and the number.
/// The longest matching code wins, so "+1 868" is not read as "+1".
(String iso, String number) splitPhone(String? phone) {
  final value = phone?.trim() ?? '';
  if (value.isEmpty) return (_defaultDialIso, '');
  final codes = [...dialCodes]
    ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
  for (final code in codes) {
    if (value.startsWith(code.dial)) {
      return (code.iso2, value.substring(code.dial.length).trim());
    }
  }
  return (_defaultDialIso, value);
}

/// The customer's own details: photo, name and phone. Email is shown but
/// locked — it is what they sign in with.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// What the photo will be once saved.
enum _PhotoChange { none, replaced, removed }

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _picker = ImagePicker();
  late final AuthState _auth = ref.read(authProvider);
  late final _name = TextEditingController(
    text: _auth.customer?['display_name'] as String? ?? '',
  );
  late final (String, String) _savedPhone = splitPhone(_auth.phone);
  late String _dialIso = _savedPhone.$1;
  late final _phone = TextEditingController(text: _savedPhone.$2);
  late final _email = TextEditingController(text: _auth.email ?? '');

  _PhotoChange _photoChange = _PhotoChange.none;
  Uint8List? _newPhoto;
  XFile? _newPhotoFile;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _dial => dialCodes
      .firstWhere(
        (d) => d.iso2 == _dialIso,
        orElse: () => dialCodes.firstWhere((d) => d.iso2 == _defaultDialIso),
      )
      .dial;

  /// The photo as it would look after saving.
  String? get _currentUrl =>
      _photoChange == _PhotoChange.removed ? null : _auth.imageUrl;

  Future<void> _choosePhoto() async {
    final hasPhoto = _newPhoto != null || _currentUrl != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius2xl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(title: 'Profile photo'),
              const SizedBox(height: 8),
              ListTile(
                key: const Key('photo-library'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () => Navigator.of(sheetContext).pop('library'),
              ),
              ListTile(
                key: const Key('photo-camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop('camera'),
              ),
              if (hasPhoto)
                ListTile(
                  key: const Key('photo-remove'),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.destructive,
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      setState(() {
        _newPhoto = null;
        _newPhotoFile = null;
        _photoChange = _PhotoChange.removed;
      });
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newPhoto = bytes;
        _newPhotoFile = file;
        _photoChange = _PhotoChange.replaced;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open your photos. Check the app has permission.',
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(accountRepositoryProvider);
    try {
      String? imageUrl;
      if (_photoChange == _PhotoChange.replaced && _newPhotoFile != null) {
        final file = _newPhotoFile!;
        imageUrl = await repository.uploadProfilePhoto(
          fileName: file.name,
          mimeType: file.mimeType ?? _mimeFor(file.name),
          bytes: _newPhoto!,
        );
      } else if (_photoChange == _PhotoChange.removed) {
        imageUrl = '';
      }
      final number = _phone.text.trim();
      await repository.updateProfile(
        displayName: name,
        phone: number.isEmpty ? '' : '$_dial $number',
        imageUrl: imageUrl,
      );
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile saved.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(error, 'Could not save your profile.');
        });
      }
    }
  }

  static String _mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            8,
            AppTheme.gutter,
            32,
          ),
          children: [
            BrandHero(
              icon: Icons.person_rounded,
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                      key: const Key('profile-photo'),
                      onTap: _saving ? null : _choosePhoto,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _Avatar(
                            name: _name.text,
                            bytes: _newPhoto,
                            url: _currentUrl,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.purple,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_camera_rounded,
                                size: 18,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saving ? null : _choosePhoto,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _newPhoto != null || _currentUrl != null
                            ? 'Change photo'
                            : 'Add a photo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('YOUR DETAILS', style: AppTypography.eyebrow),
            const SizedBox(height: 12),
            TextField(
              key: const Key('profile-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('profile-dial-$_dialIso'),
                    initialValue: _dialIso,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Code'),
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
                      if (value != null) setState(() => _dialIso = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('profile-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '77 123 4567',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('profile-email'),
              controller: _email,
              readOnly: true,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
                suffixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Your email can't be changed — it's how you sign in.",
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
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
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                key: const Key('profile-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo just picked, else the saved one, else initials.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.bytes, this.url});

  final String name;
  final Uint8List? bytes;
  final String? url;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (bytes != null) {
      image = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null) {
      image = AppNetworkImage(url: url!);
    } else {
      return RingAvatar(
        name: name.trim().isEmpty ? '?' : name,
        size: _size,
        onDark: true,
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.teal, Colors.white]),
      ),
      child: ClipOval(
        child: SizedBox(height: _size, width: _size, child: image),
      ),
    );
  }
}
