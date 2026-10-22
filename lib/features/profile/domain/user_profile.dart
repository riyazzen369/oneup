/// Profile details. Minimal data: everything except name is optional.
class UserProfile {
  const UserProfile({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.profession = '',
    this.ageRange,
    this.gender,
    this.city = '',
    this.hasAvatar = false,
  });

  final String name, phone, email, profession, city;
  final String? ageRange, gender;
  final bool hasAvatar;

  static const professions = [
    'Student',
    'Salaried',
    'Self-employed',
    'Business owner',
    'Homemaker',
    'Healthcare',
    'IT/Tech',
    'Education',
    'Retired',
    'Other',
  ];
  static const ageRanges = ['18–24', '25–34', '35–44', '45–54', '55–64', '65+'];
  static const genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];

  factory UserProfile.fromMap(Map<String, dynamic>? m, {String phone = '', bool hasAvatar = false}) => UserProfile(
        name: (m?['name'] as String?) ?? '',
        phone: phone,
        email: (m?['email'] as String?) ?? '',
        profession: (m?['profession'] as String?) ?? '',
        ageRange: m?['age_range'] as String?,
        gender: m?['gender'] as String?,
        city: (m?['city'] as String?) ?? '',
        hasAvatar: hasAvatar,
      );

  /// Only editable columns; empty optional values are stored as null.
  Map<String, dynamic> toPatch() => {
        'name': name.trim(),
        'email': _n(email),
        'profession': _n(profession),
        'age_range': ageRange,
        'gender': gender,
        'city': _n(city),
      };
  static String? _n(String s) => s.trim().isEmpty ? null : s.trim();

  UserProfile copyWith(
          {String? name, String? email, String? profession, String? ageRange, String? gender, String? city, bool? hasAvatar}) =>
      UserProfile(
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        profession: profession ?? this.profession,
        ageRange: ageRange ?? this.ageRange,
        gender: gender ?? this.gender,
        city: city ?? this.city,
        hasAvatar: hasAvatar ?? this.hasAvatar,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final s = parts.length == 1 ? parts.first[0] : '${parts.first[0]}${parts.last[0]}';
    return s.toUpperCase();
  }

  /// 8 fields, equal weight → 0–100.
  int get completeness {
    final filled = [
      name.trim().isNotEmpty,
      phone.isNotEmpty,
      email.trim().isNotEmpty,
      profession.trim().isNotEmpty,
      ageRange != null,
      gender != null,
      city.trim().isNotEmpty,
      hasAvatar,
    ].where((b) => b).length;
    return (filled / 8 * 100).round();
  }
}

class ProfileValidators {
  static String? name(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Please enter your name';
    if (s.length < 2) return 'Name is too short';
    if (s.length > 60) return 'Keep it under 60 characters';
    return null;
  }

  static final _email = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$");
  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // optional
    if (s.length > 120 || !_email.hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  static String? otherProfession(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Tell us your profession';
    if (s.length > 40) return 'Keep it under 40 characters';
    return null;
  }

  static String? city(String? v) => (v ?? '').trim().length > 60 ? 'Keep it under 60 characters' : null;

  /// +91 display of a stored E.164 number.
  static String formatPhone(String p) {
    final d = p.replaceAll(RegExp(r'\D'), '');
    final local = d.length > 10 ? d.substring(d.length - 10) : d;
    if (local.length != 10) return p;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }
}
