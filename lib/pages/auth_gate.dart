import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sign_in_page.dart';
import 'vehicles_page.dart';

final supabase = Supabase.instance.client;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = supabase.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;
    if (session != null) {
      return const VehiclesPage();
    }

    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final session = data?.session ?? supabase.auth.currentSession;

        if (session == null) {
          return const SignInPage();
        }

        return const VehiclesPage();
      },
    );
  }
}
