import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:happy_notes/providers/auth_provider.dart';
import 'package:happy_notes/screens/settings/delete_account_page.dart';
import 'package:happy_notes/services/google_auth_service.dart';
import 'package:provider/provider.dart';

import '../test_helpers/seq_logger_setup.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  bool authenticated = true;
  bool shouldDelete = true;
  String? errorMessage;
  String? lastPassword;
  String? lastIdToken;
  Map<String, dynamic>? lastDeleteBody;
  int deleteCalls = 0;

  @override
  String? get token => authenticated ? 'token' : null;

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get isLoading => false;

  @override
  String? get error => errorMessage;

  @override
  bool get isInitialized => true;

  @override
  int? get currentUserId => 123;

  @override
  String? get currentUserEmail => 'test@example.com';

  @override
  Future<void> initAuth() async {}

  @override
  Future<bool> login(String username, String password) async => false;

  @override
  Future<bool> register(String username, String email, String password) async =>
      false;

  @override
  Future<bool> signInWithGoogle(String idToken) async => false;

  @override
  Future<bool> deleteAccount({String? password, String? idToken}) async {
    deleteCalls++;
    lastPassword = password;
    lastIdToken = idToken;
    lastDeleteBody = <String, dynamic>{
      if (password != null) 'password': password,
      if (idToken != null) 'idToken': idToken,
    };
    if (shouldDelete) {
      authenticated = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> retryAuth() async {}
}

class FakeGoogleAuthService extends GoogleAuthService {
  bool available = true;
  bool canceled = false;
  int signInCalls = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String?> signInWithButton() async {
    signInCalls++;
    return canceled ? null : 'fresh-google-id-token';
  }
}

class AuthSwitchHome extends StatelessWidget {
  const AuthSwitchHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          return const Text('Sign in');
        }

        return ElevatedButton(
          key: const ValueKey<String>('open-delete-account'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
            );
          },
          child: const Text('Open delete account'),
        );
      },
    );
  }
}

void main() {
  late FakeGoogleAuthService googleAuthService;

  setUp(() async {
    setupSeqLoggerForTesting();
    await GetIt.instance.reset();
    googleAuthService = FakeGoogleAuthService();
    GetIt.instance.registerSingleton<GoogleAuthService>(googleAuthService);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<void> pumpPage(
      WidgetTester tester, FakeAuthProvider authProvider) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: DeleteAccountPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpNavigationPage(
      WidgetTester tester, FakeAuthProvider authProvider) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(home: AuthSwitchHome()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('open-delete-account')));
    await tester.pumpAndSettle();
  }

  Future<void> confirmDeletion(WidgetTester tester) async {
    await tester.tap(find.text('Delete account permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
  }

  testWidgets('submits exactly the password confirmation', (tester) async {
    final authProvider = FakeAuthProvider();
    await pumpPage(tester, authProvider);

    await tester.enterText(
      find.byKey(const ValueKey<String>('delete-account-password')),
      'correct-password',
    );
    await confirmDeletion(tester);

    expect(authProvider.deleteCalls, 1);
    expect(authProvider.lastPassword, 'correct-password');
    expect(authProvider.lastIdToken, isNull);
    expect(authProvider.lastDeleteBody, {'password': 'correct-password'});
    expect(authProvider.isAuthenticated, isFalse);
  });

  testWidgets('keeps the user signed in when the server rejects the password',
      (tester) async {
    final authProvider = FakeAuthProvider()
      ..shouldDelete = false
      ..errorMessage = 'Wrong password (400)';
    await pumpPage(tester, authProvider);

    await tester.enterText(
      find.byKey(const ValueKey<String>('delete-account-password')),
      'wrong-password',
    );
    await confirmDeletion(tester);

    expect(authProvider.deleteCalls, 1);
    expect(authProvider.isAuthenticated, isTrue);
    expect(find.textContaining('Wrong password'), findsOneWidget);
  });

  testWidgets('submits exactly a fresh Google ID token', (tester) async {
    final authProvider = FakeAuthProvider();
    await pumpPage(tester, authProvider);

    await tester.tap(find.text('Confirm with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google again'));
    await tester.pumpAndSettle();
    await confirmDeletion(tester);

    expect(googleAuthService.signInCalls, 1);
    expect(authProvider.deleteCalls, 1);
    expect(authProvider.lastPassword, isNull);
    expect(authProvider.lastIdToken, 'fresh-google-id-token');
    expect(authProvider.lastDeleteBody, {'idToken': 'fresh-google-id-token'});
    expect(authProvider.isAuthenticated, isFalse);
  });

  testWidgets('does not send a request when Google sign-in is canceled',
      (tester) async {
    googleAuthService.canceled = true;
    final authProvider = FakeAuthProvider();
    await pumpPage(tester, authProvider);

    await tester.tap(find.text('Confirm with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google again'));
    await tester.pumpAndSettle();

    expect(googleAuthService.signInCalls, 1);
    expect(authProvider.deleteCalls, 0);
    expect(authProvider.isAuthenticated, isTrue);
  });

  testWidgets('returns to the sign-in screen after password deletion',
      (tester) async {
    final authProvider = FakeAuthProvider();
    await pumpNavigationPage(tester, authProvider);

    await tester.enterText(
      find.byKey(const ValueKey<String>('delete-account-password')),
      'correct-password',
    );
    await confirmDeletion(tester);

    expect(find.byType(DeleteAccountPage), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('returns to the sign-in screen after Google deletion',
      (tester) async {
    final authProvider = FakeAuthProvider();
    await pumpNavigationPage(tester, authProvider);

    await tester.tap(find.text('Confirm with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google again'));
    await tester.pumpAndSettle();
    await confirmDeletion(tester);

    expect(find.byType(DeleteAccountPage), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
