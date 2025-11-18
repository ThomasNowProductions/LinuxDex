import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> ubuntuDistros = [
    'Ubuntu',
    'Kubuntu',
    'Xubuntu',
    'Lubuntu',
    'Ubuntu MATE',
    'Ubuntu Budgie',
    'Ubuntu Studio',
    'Ubuntu Server',
    'Ubuntu Core',
    'Ubuntu Kylin',
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
        .select('public_profile')
        .eq('id', user.id)
        .single();

      if (response != null) {
        setState(() {
          _publicProfile = response['public_profile'] ?? false;
        });
      }
    } catch (e) {
      // Profile might not exist yet, that's fine
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
        .upsert({'id': user.id, 'public_profile': _publicProfile});

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
        await Supabase.instance.client.from('distro_history').upsert(inserts, onConflict: 'user_id,distro_name,start_date');
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
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
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
              const Text('Profile Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('Make profile public'),
                subtitle: const Text('Allow others to view your distro history'),
                value: _publicProfile,
                onChanged: (value) => setState(() => _publicProfile = value),
              ),
              const SizedBox(height: 20),
              const Text('Current Ubuntu Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _currentDistro,
                hint: const Text('Select current distro'),
                items: ubuntuDistros.map((distro) => DropdownMenuItem(value: distro, child: Text(distro))).toList(),
                onChanged: (value) => setState(() => _currentDistro = value),
              ),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _currentStartDate = date);
                },
                child: Text(_currentStartDate == null ? 'Select Start Date' : 'Start: ${_currentStartDate!.toLocal().toString().split(' ')[0]}'),
              ),
              const SizedBox(height: 20),
              const Text('Previous Distributions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ..._previousDistros.asMap().entries.map((entry) {
                final index = entry.key;
                final prev = entry.value;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        DropdownButton<String>(
                          value: prev['distro'],
                          hint: const Text('Select distro'),
                          items: ubuntuDistros.map((distro) => DropdownMenuItem(value: distro, child: Text(distro))).toList(),
                          onChanged: (value) => setState(() => _previousDistros[index]['distro'] = value),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) setState(() => _previousDistros[index]['startDate'] = date);
                                },
                                child: Text(prev['startDate'] == null ? 'Start Date' : prev['startDate'].toLocal().toString().split(' ')[0]),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) setState(() => _previousDistros[index]['endDate'] = date);
                                },
                                child: Text(prev['endDate'] == null ? 'End Date' : prev['endDate'].toLocal().toString().split(' ')[0]),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removePreviousDistro(index),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ElevatedButton(onPressed: _addPreviousDistro, child: const Text('Add Previous Distro')),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(onPressed: _saveProfile, child: const Text('Save Profile')),
            ],
          ),
        ),
      ),
    );
  }
}