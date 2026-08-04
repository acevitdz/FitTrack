import 'dart:convert';
import 'dart:typed_data';

import 'package:fittrack/services/firebase_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseGateway local fallback', () {
    test('normalizes email and keeps a stable UID', () async {
      final gateway = FirebaseGateway(available: false);

      final first = await gateway.register('  User@Example.com ', '123456');
      await gateway.signOut();
      final second = await gateway.signIn('user@example.com', '123456');

      expect(first, second);
      expect(gateway.currentUid, second);
      expect(second, startsWith('local-'));
    });

    test('sign out clears the local session', () async {
      final gateway = FirebaseGateway(available: false);
      await gateway.signIn('user@example.com', '123456');

      await gateway.signOut();

      expect(gateway.currentUid, isNull);
    });

    test('rejects invalid credentials before reaching Firebase', () async {
      final gateway = FirebaseGateway(available: false);

      expect(
        () => gateway.signIn('invalid-email', '123456'),
        throwsArgumentError,
      );
      expect(
        () => gateway.register('user@example.com', '123'),
        throwsArgumentError,
      );
      expect(() => gateway.resetPassword('invalid-email'), throwsArgumentError);
    });

    test('uses a data URL for local image fallback', () async {
      final gateway = FirebaseGateway(available: false);
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);

      final result = await gateway.uploadUserImage(
        uid: 'local-user',
        path: 'profile/avatar.png',
        bytes: bytes,
        contentType: 'image/png',
      );

      expect(result, 'data:image/png;base64,${base64Encode(bytes)}');
    });
  });

  test('cloud snapshot excludes shared catalogs without mutating local data', () {
    final local = <String, dynamic>{
      'profile': <String, dynamic>{'name': 'Hải'},
      'exercises': <Object>[
        <String, dynamic>{'id': 'exercise-1'},
      ],
      'target': <String, dynamic>{
        'programs': <Object>[
          <String, dynamic>{'id': 'program-1'},
        ],
        'programVersions': <Object>[
          <String, dynamic>{'id': 'version-1'},
        ],
        'enrollment': <String, dynamic>{'id': 'enrollment-1'},
      },
    };

    final cloud = compactSnapshotForCloud(local);

    expect(cloud, isNot(contains('exercises')));
    expect(cloud['target'], isNot(contains('programs')));
    expect(cloud['target'], isNot(contains('programVersions')));
    expect(cloud['target'], contains('enrollment'));
    expect(local, contains('exercises'));
    expect(local['target'], contains('programs'));
  });
}
