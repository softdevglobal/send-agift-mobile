/// Where a gift is going and when it should arrive.
///
/// Set once from the gift search on home or explore, then carried: shown
/// while browsing so the choice is not forgotten, used to narrow the gifts to
/// the ones a shop can actually deliver there, and used to fill in checkout so
/// the same two questions are not asked twice.
class DeliveryIntent {
  const DeliveryIntent({
    this.address,
    this.line1,
    this.line2,
    this.countryCode,
    this.countryName,
    this.city,
    this.region,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.date,
  });

  /// What to show the shopper, e.g. "12 Galle Road, Colombo". Null when only
  /// a date was given — a date alone is still worth remembering.
  final String? address;

  /// Street line copied onto the checkout recipient form.
  final String? line1;
  final String? line2;

  /// ISO-3166-1 alpha-2, when the place lookup gave one.
  final String? countryCode;
  final String? countryName;
  final String? city;
  final String? region;
  final String? postalCode;
  final double? latitude;
  final double? longitude;

  /// The day it should arrive, as a local date with no time.
  final DateTime? date;

  bool get hasAddress => address != null && address!.trim().isNotEmpty;

  /// Only a picked place has a map point; a typed address does not, and
  /// cannot be checked against a shop's delivery zones.
  bool get hasPoint => latitude != null && longitude != null;

  bool get isEmpty => !hasAddress && date == null;

  /// "Colombo, Sri Lanka · arrives 5 Oct" — the one-line summary.
  String describe() {
    final parts = <String>[];
    if (hasAddress) parts.add(address!.trim());
    if (date != null) parts.add('arrives ${shortDate(date!)}');
    return parts.join(' · ');
  }

  DeliveryIntent withDate(DateTime? next) => DeliveryIntent(
    address: address,
    line1: line1,
    line2: line2,
    countryCode: countryCode,
    countryName: countryName,
    city: city,
    region: region,
    postalCode: postalCode,
    latitude: latitude,
    longitude: longitude,
    date: next,
  );

  /// The same date with no address.
  DeliveryIntent withoutAddress() => DeliveryIntent(date: date);

  Map<String, dynamic> toJson() => {
    if (address != null) 'address': address,
    if (line1 != null) 'line1': line1,
    if (line2 != null) 'line2': line2,
    if (countryCode != null) 'countryCode': countryCode,
    if (countryName != null) 'countryName': countryName,
    if (city != null) 'city': city,
    if (region != null) 'region': region,
    if (postalCode != null) 'postalCode': postalCode,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (date != null) 'date': dateOnly(date!),
  };

  factory DeliveryIntent.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    final rawDate = text('date');
    return DeliveryIntent(
      address: text('address'),
      line1: text('line1'),
      line2: text('line2'),
      countryCode: text('countryCode'),
      countryName: text('countryName'),
      city: text('city'),
      region: text('region'),
      postalCode: text('postalCode'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      date: rawDate == null ? null : DateTime.tryParse(rawDate),
    );
  }

  /// `yyyy-mm-dd`, the format the API takes for a day.
  static String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String shortDate(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]}';
}
