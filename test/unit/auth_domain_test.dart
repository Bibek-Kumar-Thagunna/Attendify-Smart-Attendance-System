import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Institution Email Domain Validation Tests', () {
    bool validateEmailDomain(String email, String expectedDomain) {
      if (!email.contains('@')) return false;
      final userDomain = email.split('@').last.toLowerCase().trim();
      return userDomain == expectedDomain.toLowerCase().trim();
    }

    test('Valid institutional email passes validation', () {
      expect(validateEmailDomain('student@thapar.edu', 'thapar.edu'), isTrue);
      expect(validateEmailDomain('faculty.cs@thapar.edu', 'thapar.edu'), isTrue);
      expect(validateEmailDomain('ADMIN@THAPAR.EDU', 'thapar.edu'), isTrue);
    });

    test('Invalid domains or consumer emails are rejected', () {
      expect(validateEmailDomain('student@gmail.com', 'thapar.edu'), isFalse);
      expect(validateEmailDomain('student@yahoo.com', 'thapar.edu'), isFalse);
      expect(validateEmailDomain('student@othercollege.edu', 'thapar.edu'), isFalse);
      expect(validateEmailDomain('invalid-email-format', 'thapar.edu'), isFalse);
    });

    test('Subdomain matching strictness', () {
      expect(validateEmailDomain('student@cs.thapar.edu', 'thapar.edu'), isFalse);
    });
  });
}
