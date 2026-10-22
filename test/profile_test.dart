import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/features/profile/domain/user_profile.dart';

void main() {
  group('validation', () {
    test('name required, 2–60 chars', () {
      expect(ProfileValidators.name(''), isNotNull);
      expect(ProfileValidators.name('   '), isNotNull);
      expect(ProfileValidators.name('A'), isNotNull);
      expect(ProfileValidators.name('A' * 61), isNotNull);
      expect(ProfileValidators.name('Asha Rao'), isNull);
    });
    test('email optional but must be valid', () {
      expect(ProfileValidators.email(''), isNull);
      expect(ProfileValidators.email(null), isNull);
      for (final bad in ['asha', 'asha@', '@x.com', 'asha@x', 'a b@x.com', 'asha@x.c']) {
        expect(ProfileValidators.email(bad), isNotNull, reason: bad);
      }
      expect(ProfileValidators.email('asha.rao+1@stellarone.in'), isNull);
    });
    test('other profession needs text', () {
      expect(ProfileValidators.otherProfession(''), isNotNull);
      expect(ProfileValidators.otherProfession('Artist'), isNull);
      expect(ProfileValidators.otherProfession('x' * 41), isNotNull);
    });
    test('phone formatting', () {
      expect(ProfileValidators.formatPhone('+919876543210'), '+91 98765 43210');
    });
  });

  group('completeness', () {
    test('empty is 0, phone only is 13', () {
      expect(const UserProfile().completeness, 0);
      expect(const UserProfile(phone: '+919876543210').completeness, 13);
    });
    test('name+phone+age = 38, all 8 = 100', () {
      expect(const UserProfile(name: 'Asha', phone: '+91', ageRange: '25–34').completeness, 38);
      const full = UserProfile(
          name: 'Asha',
          phone: '+91',
          email: 'a@b.in',
          profession: 'IT/Tech',
          ageRange: '25–34',
          gender: 'Prefer not to say',
          city: 'Pune',
          hasAvatar: true);
      expect(full.completeness, 100);
    });
    test('blank strings do not count', () {
      expect(const UserProfile(name: '  ', city: ' ').completeness, 0);
    });
  });

  test('patch stores empty optionals as null, initials fallback', () {
    final m = const UserProfile(name: ' Asha Rao ', email: '').toPatch();
    expect(m['name'], 'Asha Rao');
    expect(m['email'], isNull);
    expect(m.containsKey('phone'), isFalse); // phone is never written from Profile
    expect(const UserProfile(name: 'asha rao').initials, 'AR');
    expect(const UserProfile().initials, '?');
  });

  test('fromMap round trip', () {
    final p = UserProfile.fromMap({'name': 'Asha', 'profession': 'Potter', 'gender': 'Female'}, phone: '+91');
    expect(p.profession, 'Potter');
    expect(p.gender, 'Female');
  });
}
