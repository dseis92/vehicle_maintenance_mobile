import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'sign_in_page.dart';
import 'vehicles_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = _authService.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    // Check if already authenticated
    if (_authService.isAuthenticated) {
      return const VehiclesPage();
    }

    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final session = data?.session;

        if (session != null || _authService.isAuthenticated) {
          return const VehiclesPage();
        }

        return const SignInPage();
      },
    );
  }
}
