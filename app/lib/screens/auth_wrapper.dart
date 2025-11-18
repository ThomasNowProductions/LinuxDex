import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'profile_viewer.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const ProfileViewer();
    } else {
      return StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final session = snapshot.data?.session;
          if (session != null) {
            return const ProfileScreen();
          } else {
            return const AuthScreen();
          }
        },
      );
    }
  }
}