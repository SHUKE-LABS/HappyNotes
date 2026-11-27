import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dependency_injection.dart';
import '../../providers/auth_provider.dart';
import '../../services/google_auth_service.dart';
import '../../utils/util.dart';

enum _ConfirmationMethod { password, google }

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final GoogleAuthService _googleAuthService = locator<GoogleAuthService>();

  _ConfirmationMethod _confirmationMethod = _ConfirmationMethod.password;
  String? _googleIdToken;
  bool _isGoogleSigningIn = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _selectConfirmationMethod(_ConfirmationMethod method) {
    setState(() {
      _confirmationMethod = method;
      if (method == _ConfirmationMethod.password) {
        _googleIdToken = null;
      } else {
        _passwordController.clear();
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    if (!_googleAuthService.isAvailable) {
      Util.showError(
        ScaffoldMessenger.of(context),
        'Google sign-in is not available in this build.',
      );
      return;
    }

    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      final idToken = await _googleAuthService.signInWithButton();
      if (!mounted) return;

      if (idToken == null) {
        Util.showInfo(
            ScaffoldMessenger.of(context), 'Google sign-in was canceled.');
        return;
      }

      setState(() {
        _googleIdToken = idToken;
      });
    } catch (e) {
      if (mounted) {
        Util.showError(
            ScaffoldMessenger.of(context), 'Google sign-in failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });
      }
    }
  }

  void _handleWebGoogleIdToken(String idToken) {
    if (!mounted) return;
    setState(() {
      _googleIdToken = idToken;
    });
  }

  Future<void> _requestDeletion() async {
    if (_confirmationMethod == _ConfirmationMethod.password &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_confirmationMethod == _ConfirmationMethod.google &&
        _googleIdToken == null) {
      Util.showError(
        ScaffoldMessenger.of(context),
        'Sign in with Google again before deleting your account.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
          'Your account and all notes will be deleted permanently and at once. '
          'Copies already posted to Telegram, Mastodon, Fanfou, or Ember will not be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final deleted = _confirmationMethod == _ConfirmationMethod.password
        ? await authProvider.deleteAccount(password: _passwordController.text)
        : await authProvider.deleteAccount(idToken: _googleIdToken);

    if (!deleted && mounted) {
      Util.showError(
        ScaffoldMessenger.of(context),
        authProvider.error ?? 'Account deletion failed. Nothing was deleted.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isBusy = authProvider.isLoading || _isGoogleSigningIn;

        return Scaffold(
          appBar: AppBar(title: const Text('Delete account')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Delete your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This permanently deletes your account and all notes immediately. '
                  'Copies already posted to Telegram, Mastodon, Fanfou, or Ember are not removed.',
                ),
                const SizedBox(height: 24),
                const Text('Confirm your identity before continuing.'),
                RadioGroup<_ConfirmationMethod>(
                  groupValue: _confirmationMethod,
                  onChanged: (method) {
                    if (!isBusy && method != null) {
                      _selectConfirmationMethod(method);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<_ConfirmationMethod>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use my account password'),
                        value: _ConfirmationMethod.password,
                        enabled: !isBusy,
                      ),
                      if (_confirmationMethod == _ConfirmationMethod.password)
                        TextFormField(
                          key:
                              const ValueKey<String>('delete-account-password'),
                          controller: _passwordController,
                          obscureText: true,
                          enabled: !isBusy,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                      RadioListTile<_ConfirmationMethod>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Confirm with Google'),
                        value: _ConfirmationMethod.google,
                        enabled: !isBusy,
                      ),
                      if (_confirmationMethod ==
                          _ConfirmationMethod.google) ...[
                        const Text(
                          'Sign in again with the Google account linked to this Happy Notes account.',
                        ),
                        const SizedBox(height: 12),
                        if (kIsWeb)
                          _googleAuthService.isAvailable
                              ? _googleAuthService.buildWebSignInButton(
                                  onIdToken: _handleWebGoogleIdToken,
                                )
                              : const Text(
                                  'Google sign-in is not available in this build.')
                        else
                          OutlinedButton(
                            onPressed: isBusy ? null : _signInWithGoogle,
                            child: _isGoogleSigningIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Sign in with Google again'),
                          ),
                        if (_googleIdToken != null) ...[
                          const SizedBox(height: 8),
                          const Text('Google sign-in complete.'),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: isBusy ? null : _requestDeletion,
                  child: const Text('Delete account permanently'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
