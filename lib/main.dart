import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/auth_gate.dart';

// TODO: put your real values here
const String supabaseUrl = 'https://liunnxxgomegfjljybrs.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpdW5ueHhnb21lZ2ZqbGp5YnJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5NDc1MDUsImV4cCI6MjA4MDUyMzUwNX0.p_quDFcYGwhpMkoEWDXYolqn7-MrEpqdoWvZZ1ltqbQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
  } catch (e) {
    // If something goes wrong during init you'll see it in the console
    // and we still boot the app so it's not just a blank screen.
    debugPrint('Supabase.initialize error: $e');
  }

  runApp(const VehicleMaintenanceApp());
}

class VehicleMaintenanceApp extends StatelessWidget {
  const VehicleMaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Maintenance',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
