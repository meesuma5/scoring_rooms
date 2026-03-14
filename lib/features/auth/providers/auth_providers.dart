import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:scoring_rooms/firebase_options.dart';

const _androidServerClientId =
  '84494797252-20t3qhpj1k9umii6ihfsrlv771j2ptcq.apps.googleusercontent.com';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final googleSignIn = ref.read(googleSignInProvider);
      await googleSignIn.initialize(
        clientId: _platformClientId,
        serverClientId: _platformServerClientId,
      );
      final account = await googleSignIn.authenticate();
      final authentication = account.authentication;
      if (authentication.idToken == null) {
        throw Exception(
          'Google Sign-In did not return idToken. Verify Firebase Android app config and SHA fingerprints.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: authentication.idToken,
      );
      await ref.read(firebaseAuthProvider).signInWithCredential(credential);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthProvider).signOut();
      await ref.read(googleSignInProvider).signOut();
    });
  }

  String? get _platformClientId {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return DefaultFirebaseOptions.currentPlatform.iosClientId;
    }
    return null;
  }

  String? get _platformServerClientId {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return _androidServerClientId;
    }
    return null;
  }
}
