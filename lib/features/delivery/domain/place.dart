/// One row of the address dropdown.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    this.mainText = '',
    this.secondaryText = '',
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mainText: json['main_text'] as String? ?? '',
      secondaryText: json['secondary_text'] as String? ?? '',
    );
  }
}

/// A picked place, split into the fields an address form needs.
class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    this.line1 = '',
    this.line2,
    this.city = '',
    this.region,
    this.postalCode,
    this.countryCode,
    this.countryName,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String formattedAddress;
  final String line1;
  final String? line2;
  final String city;
  final String? region;
  final String? postalCode;
  final String? countryCode;
  final String? countryName;
  final double? latitude;
  final double? longitude;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    String? optional(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    return PlaceDetails(
      placeId: json['place_id'] as String? ?? '',
      formattedAddress: json['formatted_address'] as String? ?? '',
      line1: json['line1'] as String? ?? '',
      line2: optional('line2'),
      city: json['city'] as String? ?? '',
      region: optional('region'),
      postalCode: optional('postal_code'),
      countryCode: optional('country_code'),
      countryName: optional('country_name'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
