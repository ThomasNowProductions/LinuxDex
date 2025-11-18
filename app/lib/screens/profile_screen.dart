import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_viewer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();

  final List<String> linuxDistros = [
    'AlmaLinux',
    'Alpine Linux',
    'Arch Linux',
    'CentOS',
    'Debian',
    'Elementary OS',
    'Fedora',
    'Gentoo',
    'Kali Linux',
    'Linux Mint',
    'Manjaro',
    'MX Linux',
    'NixOS',
    'openSUSE',
    'Pop!_OS',
    'Rocky Linux',
    'Slackware',
    'Solus',
    'Ubuntu',
    'Ubuntu Budgie',
    'Ubuntu Kylin',
    'Ubuntu MATE',
    'Ubuntu Server',
    'Ubuntu Studio',
    'Void Linux',
    'Xubuntu',
    'Zorin OS',
  ];

  String? _currentDistro;
  DateTime? _currentStartDate;
  List<Map<String, dynamic>> _previousDistros = [];
  bool _publicProfile = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
        .from('profiles')
        .select('username, public_profile')
        .eq('id', user.id)
        .single();

      if (response != null) {
        setState(() {
          _usernameController.text = response['username'] ?? '';
          _publicProfile = response['public_profile'] ?? false;
        });
      }
    } catch (e) {
      // Profile might not exist yet, that's fine
    }

    // Load distro history
    try {
      final distroResponse = await Supabase.instance.client
        .from('distro_history')
        .select('*')
        .eq('user_id', user.id)
        .order('start_date', ascending: false);

      setState(() {
        _currentDistro = null;
        _currentStartDate = null;
        _previousDistros = [];
        for (final item in distroResponse) {
          if (item['current_flag'] == true) {
            _currentDistro = item['distro_name'];
            _currentStartDate = DateTime.parse(item['start_date']);
          } else {
            _previousDistros.add({
              'distro': item['distro_name'],
              'startDate': DateTime.parse(item['start_date']),
              'endDate': item['end_date'] != null ? DateTime.parse(item['end_date']) : null,
            });
          }
        }
      });
    } catch (e) {
      // Distro history might not exist yet
    }
  }

  void _addPreviousDistro() {
    setState(() {
      _previousDistros.add({
        'distro': null,
        'startDate': null,
        'endDate': null,
      });
    });
  }

  void _removePreviousDistro(int index) {
    setState(() {
      _previousDistros.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Validation
    if (_currentDistro != null && _currentStartDate == null) {
      setState(() {
        _errorMessage = 'Please select a start date for your current distro.';
      });
      return;
    }

    for (final prev in _previousDistros) {
      if (prev['distro'] != null) {
        if (prev['startDate'] == null || prev['endDate'] == null) {
          setState(() {
            _errorMessage = 'Please provide both start and end dates for previous distros.';
          });
          return;
        }
        if (prev['startDate'].isAfter(prev['endDate'])) {
          setState(() {
            _errorMessage = 'Start date must be before end date.';
          });
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save profile settings
      await Supabase.instance.client
        .from('profiles')
        .upsert({'id': user.id, 'username': _usernameController.text.trim(), 'public_profile': _publicProfile});

      // Delete existing distro history
      await Supabase.instance.client.from('distro_history').delete().eq('user_id', user.id);

      final inserts = <Map<String, dynamic>>[];

      // Current distro
      if (_currentDistro != null && _currentStartDate != null) {
        inserts.add({
          'user_id': user.id,
          'distro_name': _currentDistro,
          'start_date': _currentStartDate!.toIso8601String().split('T')[0],
          'end_date': null,
          'current_flag': true,
        });
      }

      // Previous distros
      for (final prev in _previousDistros) {
        if (prev['distro'] != null && prev['startDate'] != null && prev['endDate'] != null) {
          inserts.add({
            'user_id': user.id,
            'distro_name': prev['distro'],
            'start_date': prev['startDate'].toIso8601String().split('T')[0],
            'end_date': prev['endDate'].toIso8601String().split('T')[0],
            'current_flag': false,
          });
        }
      }

      if (inserts.isNotEmpty) {
        await Supabase.instance.client.from('distro_history').insert(inserts);
      }

      // Navigate to view or something, but for now, show success
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!')));
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'View Other Profiles',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileViewer())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings, color: Color(0xFFE95420)),
                          const SizedBox(width: 8),
                          Text('Profile Settings', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Make profile public'),
                        subtitle: const Text('Allow others to view your distro history'),
                        value: _publicProfile,
                        onChanged: (value) => setState(() => _publicProfile = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Color(0xFFE95420)),
                          const SizedBox(width: 8),
                          Text('Username', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Choose a unique username',
                          prefixIcon: Icon(Icons.account_circle),
                          helperText: 'This will be used for others to find your profile',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.computer, color: Color(0xFFE95420)),
                          const SizedBox(width: 8),
                          Text('Current Ubuntu Distribution', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _currentDistro,
                        decoration: const InputDecoration(
                          labelText: 'Select current distro',
                          prefixIcon: Icon(Icons.laptop),
                        ),
                        items: linuxDistros.map((distro) => DropdownMenuItem(value: distro, child: Text(distro))).toList(),
                        onChanged: (value) => setState(() => _currentDistro = value),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _currentStartDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _currentStartDate = date);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _currentStartDate == null
                                ? 'Select start date'
                                : '${_currentStartDate!.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Color(0xFFE95420)),
                          const SizedBox(width: 8),
                          Text('Previous Distributions', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._previousDistros.asMap().entries.map((entry) {
                        final index = entry.key;
                        final prev = entry.value;
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: prev['distro'],
                                  decoration: const InputDecoration(
                                    labelText: 'Distro',
                                    prefixIcon: Icon(Icons.laptop),
                                  ),
                                  items: linuxDistros.map((distro) => DropdownMenuItem(value: distro, child: Text(distro))).toList(),
                                  onChanged: (value) => setState(() => _previousDistros[index]['distro'] = value),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: prev['startDate'] ?? DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime.now(),
                                          );
                                          if (date != null) setState(() => _previousDistros[index]['startDate'] = date);
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Start Date',
                                            prefixIcon: Icon(Icons.calendar_today),
                                          ),
                                          child: Text(
                                            prev['startDate'] == null
                                                ? 'Select'
                                                : '${prev['startDate'].toLocal().toString().split(' ')[0]}',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: prev['endDate'] ?? DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime.now(),
                                          );
                                          if (date != null) setState(() => _previousDistros[index]['endDate'] = date);
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'End Date',
                                            prefixIcon: Icon(Icons.calendar_today),
                                          ),
                                          child: Text(
                                            prev['endDate'] == null
                                                ? 'Select'
                                                : '${prev['endDate'].toLocal().toString().split(' ')[0]}',
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removePreviousDistro(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addPreviousDistro,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Previous Distro'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE95420)),
                            foregroundColor: const Color(0xFFE95420),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}