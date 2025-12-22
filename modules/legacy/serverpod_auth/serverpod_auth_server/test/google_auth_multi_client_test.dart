import 'package:serverpod_auth_server/src/business/google_auth.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleClientSecret multi-client ID support', () {
    test('isValidClientId returns true for primary clientId', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
      );

      expect(secret.isValidClientId('primary-id.apps.googleusercontent.com'),
          isTrue);
    });

    test('isValidClientId returns true for additional clientIds', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: [
          'ios-id.apps.googleusercontent.com',
          'android-id.apps.googleusercontent.com',
        ],
      );

      expect(secret.isValidClientId('ios-id.apps.googleusercontent.com'),
          isTrue);
      expect(secret.isValidClientId('android-id.apps.googleusercontent.com'),
          isTrue);
    });

    test('isValidClientId returns false for unknown clientId', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: ['ios-id.apps.googleusercontent.com'],
      );

      expect(secret.isValidClientId('unknown-id.apps.googleusercontent.com'),
          isFalse);
      expect(secret.isValidClientId(''), isFalse);
    });

    test('isValidClientId works with empty additional client IDs', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: [],
      );

      expect(secret.isValidClientId('primary-id.apps.googleusercontent.com'),
          isTrue);
      expect(secret.isValidClientId('ios-id.apps.googleusercontent.com'),
          isFalse);
    });

    test('isValidClientId works when additional client IDs not specified', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
      );

      expect(secret.isValidClientId('primary-id.apps.googleusercontent.com'),
          isTrue);
      expect(secret.isValidClientId('ios-id.apps.googleusercontent.com'),
          isFalse);
    });

    test('allClientIds returns all configured IDs', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: [
          'ios-id.apps.googleusercontent.com',
          'android-id.apps.googleusercontent.com',
        ],
      );

      final allIds = secret.allClientIds;
      expect(allIds.length, equals(3));
      expect(
        allIds,
        containsAll([
          'primary-id.apps.googleusercontent.com',
          'ios-id.apps.googleusercontent.com',
          'android-id.apps.googleusercontent.com',
        ]),
      );
    });

    test('allClientIds returns only primary ID when no additional IDs', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
      );

      final allIds = secret.allClientIds;
      expect(allIds.length, equals(1));
      expect(allIds, contains('primary-id.apps.googleusercontent.com'));
    });

    test('allClientIds returns copy not reference', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: ['ios-id.apps.googleusercontent.com'],
      );

      final allIds1 = secret.allClientIds;
      final allIds2 = secret.allClientIds;

      // Both should have same content but be different instances
      expect(allIds1, equals(allIds2));
      expect(identical(allIds1, allIds2), isFalse);
    });

    test('additionalClientIds cannot be reassigned', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'primary-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: ['ios-id.apps.googleusercontent.com'],
      );

      // The field is final, so it cannot be reassigned
      // This test just verifies the field exists and is accessible
      expect(secret.additionalClientIds, isNotEmpty);
      expect(secret.additionalClientIds.first,
          equals('ios-id.apps.googleusercontent.com'));
    });

    test('validates multiple platform client IDs', () {
      final secret = GoogleClientSecret.forTest(
        clientId: 'web-id.apps.googleusercontent.com',
        clientSecret: 'test-secret',
        redirectUris: ['http://localhost'],
        additionalClientIds: [
          'ios-id.apps.googleusercontent.com',
          'macos-id.apps.googleusercontent.com',
          'android-id.apps.googleusercontent.com',
        ],
      );

      // All platform IDs should be valid
      expect(secret.isValidClientId('web-id.apps.googleusercontent.com'),
          isTrue);
      expect(secret.isValidClientId('ios-id.apps.googleusercontent.com'),
          isTrue);
      expect(secret.isValidClientId('macos-id.apps.googleusercontent.com'),
          isTrue);
      expect(secret.isValidClientId('android-id.apps.googleusercontent.com'),
          isTrue);

      // Unknown ID should be invalid
      expect(secret.isValidClientId('unknown-id.apps.googleusercontent.com'),
          isFalse);
    });
  });
}
