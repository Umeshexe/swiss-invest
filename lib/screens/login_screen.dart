import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF4EF), Color(0xFFF5F7F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B5D52), Color(0xFF4C9F70)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Welcome Back',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in with your platform account to securely sync approved health and location data.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFD8E0D6)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'you@example.com',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your email.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Password',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter your password.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              AnimatedBuilder(
                                animation: controller,
                                builder: (context, _) {
                                  return FilledButton(
                                    onPressed: controller.isBusy
                                        ? null
                                        : () async {
                                            if (!_formKey.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            await controller.login(
                                              email: _emailController.text
                                                  .trim(),
                                              password:
                                                  _passwordController.text,
                                            );
                                          },
                                    child: controller.isBusy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sign In'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          final message = controller.lastSyncMessage;
                          if (message == null) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.error.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colorScheme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    message,
                                    style: TextStyle(color: colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Secured with HTTPS and bearer-token authentication.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
