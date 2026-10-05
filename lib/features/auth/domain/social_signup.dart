/// A new customer who signed in with Google or Facebook and still needs to
/// add a country and phone before their account is made.
class SocialSignup {
  const SocialSignup({
    required this.signupToken,
    required this.email,
    this.name,
    this.imageUrl,
  });

  final String signupToken;
  final String email;
  final String? name;
  final String? imageUrl;

  factory SocialSignup.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return SocialSignup(
      signupToken: json['signup_token'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: text('name'),
      imageUrl: text('image_url'),
    );
  }
}
