import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:happy_notes/entities/user_settings.dart';
import 'package:happy_notes/providers/auth_provider.dart';
import 'package:happy_notes/services/account_service.dart';
import 'package:happy_notes/services/google_auth_service.dart';
import 'package:happy_notes/screens/account/user_session.dart';
import 'package:get_it/get_it.dart';

import 'auth_provider_test.mocks.dart';
import '../test_helpers/seq_logger_setup.dart';

@GenerateMocks([AccountService, GoogleAuthService])
void main() {
  group('AuthProvider', () {
    late AuthProvider authProvider;
    late MockAccountService mockAccountService;
    late MockGoogleAuthService mockGoogleAuthService;

    setUp(() {
      // Initialize SeqLogger for testing
      setupSeqLoggerForTesting();

      mockAccountService = MockAccountService();
      mockGoogleAuthService = MockGoogleAuthService();

      // Reset GetIt and register fresh mocks
      if (GetIt.instance.isRegistered<AccountService>()) {
        GetIt.instance.unregister<AccountService>();
      }
      GetIt.instance.registerSingleton<AccountService>(mockAccountService);

      if (GetIt.instance.isRegistered<GoogleAuthService>()) {
        GetIt.instance.unregister<GoogleAuthService>();
      }
      GetIt.instance.registerSingleton<GoogleAuthService>(mockGoogleAuthService);

      // Clear UserSession
      UserSession().id = null;
      UserSession().email = null;
      UserSession().userSettings = null;
    });

    tearDown(() {
      if (GetIt.instance.isRegistered<AccountService>()) {
        GetIt.instance.unregister<AccountService>();
      }
      if (GetIt.instance.isRegistered<GoogleAuthService>()) {
        GetIt.instance.unregister<GoogleAuthService>();
      }
    });

    test('initial state should be correct', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();

      expect(authProvider.token, null);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.isLoading, true); // Loading during initialization
      expect(authProvider.error, null);
      expect(authProvider.isInitialized, false);

      // Wait for initialization to complete
      await Future.delayed(Duration.zero);

      expect(authProvider.isLoading, false);
      expect(authProvider.isInitialized, true);
    });

    test('initAuth should handle valid token correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => 'valid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => true);
      when(mockAccountService.setUserSession(token: 'valid_token')).thenAnswer((_) async {});

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      expect(authProvider.isAuthenticated, true);
      expect(authProvider.token, 'valid_token');
      expect(authProvider.isLoading, false);
      expect(authProvider.isInitialized, true);
      verify(mockAccountService.setUserSession(token: 'valid_token')).called(1);
    });

    test('initAuth should handle invalid token correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => 'invalid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => false);
      when(mockAccountService.logout()).thenAnswer((_) async {});

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.isLoading, false);
      expect(authProvider.isInitialized, true);
      verify(mockAccountService.logout()).called(1);
    });

    test('initAuth should handle no stored token correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.isLoading, false);
      expect(authProvider.isInitialized, true);
    });

    test('initAuth should fail when session setup fails without cached settings', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => 'valid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => true);
      when(mockAccountService.setUserSession(token: 'valid_token')).thenThrow(Exception('settings fetch failed'));

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero);

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.isInitialized, true);
      expect(authProvider.error, contains('settings fetch failed'));
    });

    test('initAuth should keep auth state when cached settings exist and session refresh fails', () async {
      UserSession().userSettings = [
        UserSettings(id: 1, userId: 123, settingName: 'privateNoteOnlyIsEnabled', settingValue: '1'),
      ];
      when(mockAccountService.getToken()).thenAnswer((_) async => 'valid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => true);
      when(mockAccountService.setUserSession(token: 'valid_token')).thenThrow(Exception('settings fetch failed'));

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero);

      expect(authProvider.isAuthenticated, true);
      expect(authProvider.token, 'valid_token');
      expect(authProvider.error, null);
      expect(authProvider.isInitialized, true);
    });

    test('login should handle successful login correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.login('user', 'pass')).thenAnswer((_) async => {});
      when(mockAccountService.getToken()).thenAnswer((_) async => 'new_token');

      final result = await authProvider.login('user', 'pass');

      expect(result, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.token, 'new_token');
      expect(authProvider.error, null);
      expect(authProvider.isLoading, false);
      verify(mockAccountService.login('user', 'pass')).called(1);
    });

    test('login should handle failed login correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.login('user', 'wrong_pass')).thenThrow(Exception('Invalid credentials'));

      final result = await authProvider.login('user', 'wrong_pass');

      expect(result, false);
      expect(authProvider.error, contains('Invalid credentials'));
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.error, contains('Invalid credentials'));
      expect(authProvider.isLoading, false);
    });

    test('signInWithGoogle should handle successful sign-in correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.googleLogin('id_token')).thenAnswer((_) async => {});
      when(mockAccountService.getToken()).thenAnswer((_) async => 'google_token');

      final result = await authProvider.signInWithGoogle('id_token');

      expect(result, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.token, 'google_token');
      expect(authProvider.error, null);
      expect(authProvider.isLoading, false);
      verify(mockAccountService.googleLogin('id_token')).called(1);
    });

    test('signInWithGoogle should handle failed sign-in correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.googleLogin('bad_token')).thenThrow(Exception('Invalid idToken'));

      final result = await authProvider.signInWithGoogle('bad_token');

      expect(result, false);
      expect(authProvider.error, contains('Invalid idToken'));
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.isLoading, false);
    });

    test('register should handle successful registration correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.register('user', 'email@test.com', 'pass')).thenAnswer((_) async => {});
      when(mockAccountService.getToken()).thenAnswer((_) async => 'reg_token');

      final result = await authProvider.register('user', 'email@test.com', 'pass');

      expect(result, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.token, 'reg_token');
      expect(authProvider.error, null);
      expect(authProvider.isLoading, false);
      verify(mockAccountService.register('user', 'email@test.com', 'pass')).called(1);
    });

    test('register should handle failed registration correctly', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.register('user', 'invalid_email', 'pass')).thenThrow(Exception('Invalid email'));

      final result = await authProvider.register('user', 'invalid_email', 'pass');

      expect(result, false);
      expect(authProvider.error, contains('Invalid email'));
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.error, contains('Invalid email'));
      expect(authProvider.isLoading, false);
    });

    test('logout should clear authentication state', () async {
      // Setup authenticated state
      when(mockAccountService.getToken()).thenAnswer((_) async => 'valid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => true);
      when(mockAccountService.setUserSession(token: 'valid_token')).thenAnswer((_) async {});

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      when(mockAccountService.logout()).thenAnswer((_) async {});
      when(mockGoogleAuthService.signOut()).thenAnswer((_) async {});

      await authProvider.logout();

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.token, null);
      expect(authProvider.error, null);
      expect(authProvider.isLoading, false);
      verify(mockAccountService.logout()).called(1);
      verify(mockGoogleAuthService.signOut()).called(1);
    });

    test('deleteAccount logs out only after the API succeeds', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => 'valid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => true);
      when(mockAccountService.setUserSession(token: 'valid_token')).thenAnswer((_) async {});

      authProvider = AuthProvider();
      await Future.delayed(Duration.zero);

      when(mockAccountService.deleteAccount(password: 'correct-password')).thenAnswer((_) async => {});
      when(mockAccountService.logout()).thenAnswer((_) async {});
      when(mockGoogleAuthService.signOut()).thenAnswer((_) async {});

      final result = await authProvider.deleteAccount(password: 'correct-password');

      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      verify(mockAccountService.deleteAccount(password: 'correct-password')).called(1);
      verify(mockAccountService.logout()).called(1);
      verify(mockGoogleAuthService.signOut()).called(1);
    });

    test('deleteAccount keeps the session when the API rejects confirmation', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => 'valid_token');
      when(mockAccountService.isValidToken()).thenAnswer((_) async => true);
      when(mockAccountService.setUserSession(token: 'valid_token')).thenAnswer((_) async {});
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero);

      when(mockAccountService.deleteAccount(password: 'wrong-password'))
          .thenThrow(Exception('Wrong password'));

      final result = await authProvider.deleteAccount(password: 'wrong-password');

      expect(result, isFalse);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.error, contains('Wrong password'));
      verifyNever(mockAccountService.logout());
      verifyNever(mockGoogleAuthService.signOut());
    });

    test('should notify listeners on state changes', () async {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();
      await Future.delayed(Duration.zero); // Let initAuth complete

      bool notified = false;
      authProvider.addListener(() {
        notified = true;
      });

      when(mockAccountService.login('user', 'pass')).thenAnswer((_) async => {});
      when(mockAccountService.getToken()).thenAnswer((_) async => 'token');

      await authProvider.login('user', 'pass');
      expect(notified, true);
    });

    test('currentUserId should return UserSession id', () {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();

      UserSession().id = 123;
      expect(authProvider.currentUserId, 123);
    });

    test('currentUserEmail should return UserSession email', () {
      when(mockAccountService.getToken()).thenAnswer((_) async => null);
      authProvider = AuthProvider();

      UserSession().email = 'test@example.com';
      expect(authProvider.currentUserEmail, 'test@example.com');
    });
  });
}
