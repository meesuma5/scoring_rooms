import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/auth/providers/auth_providers.dart';

void main() {
  test('firebaseAuthProvider can be overridden', () {
    final mockAuth = MockFirebaseAuth();
    final container = ProviderContainer(
      overrides: [firebaseAuthProvider.overrideWithValue(mockAuth)],
    );
    addTearDown(container.dispose);

    expect(container.read(firebaseAuthProvider), same(mockAuth));
  });
}
