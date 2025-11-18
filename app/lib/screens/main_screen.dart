import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'profile_viewer.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        final isLoggedIn = session != null;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'View Profiles'),
                    Tab(text: 'My Profile'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      const ProfileViewerBody(),
                      isLoggedIn
                          ? const ProfileScreenBody()
                          : const AuthScreenBody(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}