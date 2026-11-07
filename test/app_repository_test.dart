import 'package:flutter_test/flutter_test.dart';
import 'package:hatyaiwit_borrow_sports/services/app_repository.dart';

void main() {
  group('school email validation', () {
    test('accepts a Hatyaiwit account', () {
      expect(validateSchoolEmail('52972@hatyaiwit.ac.th'), isNull);
    });

    test('rejects an outside account', () {
      expect(validateSchoolEmail('52972@gmail.com'), isNotNull);
    });

    test('rejects lookalike domains', () {
      expect(
        validateSchoolEmail('52972@hatyaiwit.ac.th.example.com'),
        isNotNull,
      );
    });
  });
}
