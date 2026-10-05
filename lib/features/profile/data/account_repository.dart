import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../auth/data/auth_controller.dart';
import '../../checkout/data/checkout_repository.dart';
import '../../checkout/domain/checkout.dart';

/// An address as typed into a form, ready to send.
class AddressDraft {
  const AddressDraft({
    required this.countryId,
    required this.line1,
    required this.city,
    this.line2,
    this.region,
    this.postalCode,
    this.label,
    this.addressType = 'shipping',
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String countryId;
  final String line1;
  final String city;
  final String? line2;
  final String? region;
  final String? postalCode;
  final String? label;
  final String addressType;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    String? optional(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    return {
      'country_id': countryId,
      'label': optional(label),
      'address_type': optional(addressType) ?? 'shipping',
      'line1': line1.trim(),
      'line2': optional(line2),
      'city': city.trim(),
      'region': optional(region),
      'postal_code': optional(postalCode),
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }
}

/// The customer's own saved addresses, and everything about their
/// recipients beyond picking one at checkout.
class AccountRepository {
  AccountRepository(this._client);

  final ApiClient _client;

  /// Talks to the presigned storage URL directly. No base URL and no API
  /// auth header, which the storage service would reject.
  final Dio _storage = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Saves the editable parts of the profile. Email is not one of them: it
  /// is how the customer signs in. An empty phone clears it; a null photo
  /// leaves it alone and an empty one removes it.
  Future<void> updateProfile({
    required String displayName,
    required String phone,
    String? imageUrl,
  }) => _call(() async {
    await _client.dio.put<dynamic>(
      '/customers/me',
      data: {
        'display_name': displayName.trim(),
        'phone': phone.trim(),
        'image_url': ?imageUrl,
      },
    );
  });

  /// Replaces the customer's password after checking the current one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _call(() async {
    await _client.dio.put<dynamic>(
      '/customers/me/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  });

  /// Presign → PUT → the photo's public address.
  Future<String> uploadProfilePhoto({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final cleaned = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final Map<String, dynamic> presign;
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/media/presign-upload',
        data: {
          'filename': cleaned.isEmpty ? 'profile.jpg' : cleaned,
          'content_type': mimeType,
          'folder': 'customer-profile',
        },
      );
      presign = response.data ?? const {};
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
    final uploadUrl = presign['upload_url'] as String? ?? '';
    final publicUrl = presign['public_url'] as String? ?? '';
    if (uploadUrl.isEmpty || publicUrl.isEmpty) {
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
      throw const AppException('Could not upload the photo. Please try again.');
    }
    return publicUrl;
  }

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw _client.mapError(error);
    }
  }

  /// The customer's own addresses, read from their profile.
  Future<List<RecipientAddress>> myAddresses() => _call(() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/customers/me',
    );
    final raw = response.data?['addresses'];
    if (raw is! List) return const <RecipientAddress>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RecipientAddress.fromJson)
        .toList(growable: false);
  });

  Future<void> addMyAddress(AddressDraft draft) => _call(() async {
    await _client.dio.post<dynamic>(
      '/customers/me/addresses',
      data: draft.toJson(),
    );
  });

  Future<void> deleteMyAddress(String id) => _call(() async {
    await _client.dio.delete<dynamic>('/customers/me/addresses/$id');
  });

  /// Saves the recipient's details. The API replaces every field, so what is
  /// not being edited is sent back as it was.
  Future<Recipient> updateRecipient(
    Recipient current, {
    String? name,
    String? relationship,
    String? email,
    String? phone,
    String? defaultAddressId,
  }) => _call(() async {
    String? optional(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    final response = await _client.dio.put<Map<String, dynamic>>(
      '/customers/me/recipients/${current.id}',
      data: {
        'name': (name ?? current.name).trim(),
        'relationship': optional(relationship ?? current.relationship),
        'email': optional(email ?? current.email),
        'phone': optional(phone ?? current.phone),
        'image_url': current.imageUrl,
        'default_address_id': defaultAddressId ?? current.defaultAddressId,
        'preferences': current.preferences,
      },
    );
    return Recipient.fromJson(response.data ?? const {});
  });

  Future<void> deleteRecipient(String id) => _call(() async {
    await _client.dio.delete<dynamic>('/customers/me/recipients/$id');
  });

  Future<void> addRecipientAddress(String recipientId, AddressDraft draft) =>
      _call(() async {
        await _client.dio.post<dynamic>(
          '/customers/me/recipients/$recipientId/addresses',
          data: draft.toJson(),
        );
      });

  Future<void> updateRecipientAddress(
    String recipientId,
    String addressId,
    AddressDraft draft,
  ) => _call(() async {
    await _client.dio.put<dynamic>(
      '/customers/me/recipients/$recipientId/addresses/$addressId',
      data: draft.toJson(),
    );
  });

  Future<void> deleteRecipientAddress(String recipientId, String addressId) =>
      _call(() async {
        await _client.dio.delete<dynamic>(
          '/customers/me/recipients/$recipientId/addresses/$addressId',
        );
      });
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});

final myAddressesProvider = FutureProvider.autoDispose<List<RecipientAddress>>((
  ref,
) async {
  final signedIn = ref.watch(authProvider.select((auth) => auth.isSignedIn));
  if (!signedIn) return const [];
  return ref.watch(accountRepositoryProvider).myAddresses();
});

/// Refreshes every view of recipients after one changes.
void invalidateRecipients(WidgetRef ref, [String? id]) {
  ref.invalidate(recipientsProvider);
  if (id != null) ref.invalidate(recipientDetailsProvider(id));
}
