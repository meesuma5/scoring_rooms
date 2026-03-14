import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scoring_rooms/features/auth/providers/auth_providers.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_home_screen.dart';
import 'package:scoring_rooms/features/startup/startup_screen.dart';
import 'package:scoring_rooms/theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    firebaseInitError = error;
  }

  runApp(
    ProviderScope(
      child: MyApp(
        firebaseInitialized: firebaseInitError == null,
        firebaseInitError: firebaseInitError?.toString(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({
    super.key,
    this.firebaseInitialized = false,
    this.firebaseInitError,
  });

  final bool firebaseInitialized;
  final String? firebaseInitError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget home;
    if (!firebaseInitialized) {
      home = FirebaseNotInitializedPage(errorMessage: firebaseInitError);
    } else {
      final authState = ref.watch(authStateProvider);
      home = authState.when(
        data: (user) =>
            user == null ? const StartupScreen() : const CreatorHomeScreen(),
        loading: () => const _LoadingPage(),
        error: (error, _) => _ErrorPage(message: error.toString()),
      );
    }

    return MaterialApp(
      title: 'Scoring Rooms',
      theme: AppTheme.light,
      home: home,
    );
  }
}

class FirebaseNotInitializedPage extends StatelessWidget {
  const FirebaseNotInitializedPage({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Firebase Setup Required'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firebase is not initialized. Run flutterfire configure and restart the app.',
              textAlign: TextAlign.center,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const Center(child: CircularProgressIndicator()));
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Something went wrong')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
