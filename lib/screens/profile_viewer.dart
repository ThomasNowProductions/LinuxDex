import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ProfileViewerBody extends StatefulWidget {
  const ProfileViewerBody({super.key});

  @override
  State<ProfileViewerBody> createState() => _ProfileViewerBodyState();
}

class _ProfileViewerBodyState extends State<ProfileViewerBody> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loadProfile() async {
    final username = _searchController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First, find the user by username
      final profileResponse = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .eq('public_profile', true)
        .single();

      final userId = profileResponse['id'];

      // Then, get their distro history
      final historyResponse = await Supabase.instance.client
        .from('distro_history')
        .select('distro_name, start_date, end_date, current_flag')
        .eq('user_id', userId)
        .order('start_date');

      setState(() {
        _history = List<Map<String, dynamic>>.from(historyResponse);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getDistroIcon(String distroName) {
    final name = distroName.toLowerCase();
    if (name.contains('ubuntu')) return FontAwesomeIcons.ubuntu;
    if (name.contains('fedora')) return FontAwesomeIcons.fedora;
    if (name.contains('centos')) return FontAwesomeIcons.centos;
    if (name.contains('red hat') || name.contains('rhel')) return FontAwesomeIcons.redhat;
    if (name.contains('opensuse') || name.contains('suse')) return FontAwesomeIcons.suse;
    // Default icon for others
    return FontAwesomeIcons.linux;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  'View User Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter username to view distro history',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[300],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.account_circle),
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.search),
                      label: const Text('View Profile'),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: _history.isNotEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: _history.isNotEmpty
                      ? Column(
                          children: [
                            const SizedBox(height: 32),
                            Text(
                              'Distro History',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            ..._history.map((item) {
                              final isCurrent = item['current_flag'] == true;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Card(
                                  color: Colors.black,
                                  child: ListTile(
                                    leading: Icon(
                                      _getDistroIcon(item['distro_name']),
                                      color: Colors.green,
                                    ),
                                    title: Text(
                                      item['distro_name'],
                                      style: TextStyle(
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${item['start_date']} - ${item['end_date'] ?? 'Current'}',
                                    ),
                                    trailing: isCurrent
                                        ? const Icon(Icons.star, color: Colors.green)
                                        : null,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final username = _searchController.text.trim();
                                  final shareText = 'Check out $username\'s Linux distro journey on LinuxDex! Username: $username';
                                  await Share.share(shareText);
                                },
                                icon: const Icon(Icons.share),
                                label: const Text('Share Profile'),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}