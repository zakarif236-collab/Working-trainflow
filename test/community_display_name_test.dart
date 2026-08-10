import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/auth_service.dart';

void main() {
  group('resolveDisplayName', () {
    test('uses the Google account display name when present', () {
      expect(
        resolveDisplayName(displayName: 'Jane Doe', email: 'jane@gmail.com'),
        'Jane Doe',
      );
    });

    test('falls back to the email local part when display name is null', () {
      expect(
        resolveDisplayName(displayName: null, email: 'jane.doe@gmail.com'),
        'jane.doe',
      );
    });

    test('falls back to Athlete when nothing is available', () {
      expect(resolveDisplayName(), 'Athlete');
    });

    test('ignores blank display names', () {
      expect(
        resolveDisplayName(displayName: '   ', email: 'jane@gmail.com'),
        'jane',
      );
    });
  });
}
