import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'login_controller.dart';
import 'package:happy_notes/screens/account/registration.dart';

class Login extends StatefulWidget {
  const Login({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formModel = LoginController();
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _formModel.onSubmittingStateChanged = (isSubmitting) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = isSubmitting;
      });
    };
  }

  @override
  void dispose() {
    _formModel.onSubmittingStateChanged = null;
    _formModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Form(
          key: _formModel.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon/app_icon.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 32),
              TextFormField(
                key: const ValueKey<String>('e2e-login-username'),
                controller: _formModel.emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Username",
                ),
                validator: _formModel.validateUsername,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('e2e-login-password'),
                controller: _formModel.passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: _formModel.validatePassword,
                onFieldSubmitted: (_) => _formModel.submitForm(context),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey<String>('e2e-login-submit'),
                onPressed: _isSubmitting ? null : () => _formModel.submitForm(context),
                child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit'),
              ),
              if (_formModel.googleSignInAvailable) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                if (kIsWeb)
                  _formModel.googleAuthService.buildWebSignInButton(
                    onIdToken: (idToken) => _formModel.handleGoogleIdToken(context, idToken),
                  )
                else
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _formModel.submitGoogleSignIn(context),
                    child: const Text('Sign in with Google'),
                  ),
              ],
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Registration(title: 'Registration'),
                    ),
                  );
                },
                child: const Text("Don't have an account? Register here"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
