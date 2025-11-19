import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';

class ProfileScreenBody extends StatefulWidget {
  const ProfileScreenBody({super.key});

  @override
  State<ProfileScreenBody> createState() => _ProfileScreenBodyState();
}

class _ProfileScreenBodyState extends State<ProfileScreenBody> {
  final _usernameController = TextEditingController();

  List<Map<String, dynamic>> _distroHistory = [];
  bool _publicProfile = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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

      setState(() {
        _usernameController.text = response['username'] ?? '';
        _publicProfile = response['public_profile'] ?? false;
      });
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
        _distroHistory = distroResponse.map((item) {
          return {
            'id': item['id'],
            'distro_name': item['distro_name'] as String,
            'start_date': DateTime.parse(item['start_date']),
            'end_date': item['end_date'] != null ? DateTime.parse(item['end_date']) : null,
            'current_flag': item['current_flag'] as bool,
          };
        }).toList();
      });
    } catch (e) {
      // Distro history might not exist yet
    }
  }

  void _showAddDistroDialog() {
    showDialog(
      context: context,
      builder: (context) => AddDistroDialog(
        onSave: (selectedDistro, startDate) {
          _addNewDistro(selectedDistro, startDate);
        },
      ),
    );
  }

  Future<void> _addNewDistro(String distroName, DateTime startDate) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentDate = DateTime.now();
      
      // Find current distro and update its end date and current flag
      final currentDistroIndex = _distroHistory.indexWhere((distro) => distro['current_flag'] == true);
      
      if (currentDistroIndex != -1) {
        final currentDistro = _distroHistory[currentDistroIndex];
        await Supabase.instance.client
            .from('distro_history')
            .update({
              'end_date': currentDate.toIso8601String().split('T')[0],
              'current_flag': false,
            })
            .eq('id', currentDistro['id']);
      }

      // Add new current distro
      await Supabase.instance.client.from('distro_history').insert({
        'user_id': user.id,
        'distro_name': distroName,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': null,
        'current_flag': true,
      });

      // Reload the history
      await _loadProfile();

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Distro switched successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add new distro. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check username uniqueness
      final username = _usernameController.text.trim();
      if (username.isNotEmpty) {
        final existingUser = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', user.id)
          .maybeSingle();
        if (existingUser != null) {
          setState(() {
            _errorMessage = 'Username already taken. Please choose a different one.';
          });
          return;
        }
      }

      // Save profile settings
      await Supabase.instance.client
        .from('profiles')
        .upsert({'id': user.id, 'username': username, 'public_profile': _publicProfile});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!')));
      }
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

  void _exportAsJson() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final historyResponse = await Supabase.instance.client
          .from('distro_history')
          .select('*')
          .eq('user_id', user.id)
          .order('start_date');

      final jsonData = jsonEncode(historyResponse);

      if (kIsWeb) {
        final bytes = utf8.encode(jsonData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'distro_history.json')
          ..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JSON file downloaded!')),
          );
        }
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/distro_history.json');
        await file.writeAsString(jsonData);
        await Share.shareXFiles([XFile(file.path)], text: 'Distro History JSON');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JSON file shared!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export JSON.')),
        );
      }
    }
  }

  void _exportAsCsv() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final historyResponse = await Supabase.instance.client
          .from('distro_history')
          .select('*')
          .eq('user_id', user.id)
          .order('start_date');

      final csvHeader = 'distro_name,start_date,end_date,current_flag\n';
      final csvRows = historyResponse.map((item) {
        final distro = item['distro_name'];
        final start = item['start_date'];
        final end = item['end_date'] ?? '';
        final current = item['current_flag'];
        return '$distro,$start,$end,$current';
      }).join('\n');

      final csvData = csvHeader + csvRows;

      if (kIsWeb) {
        final bytes = utf8.encode(csvData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'distro_history.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file downloaded!')),
          );
        }
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/distro_history.csv');
        await file.writeAsString(csvData);
        await Share.shareXFiles([XFile(file.path)], text: 'Distro History CSV');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file shared!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export CSV.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (Supabase.instance.client.auth.currentUser != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                  ),
                ],
              ),
            Card(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings, color: Colors.green),
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
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green),
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
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.computer, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Linux Distributions', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Current Distro at the top
                    if (_distroHistory.any((distro) => distro['current_flag'] == true)) ...[
                      _buildCurrentDistroItem(
                        _distroHistory.firstWhere((distro) => distro['current_flag'] == true)
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Previous Distros
                    if (_distroHistory.any((distro) => distro['current_flag'] == false)) ...[
                      Text(
                        'Previous Distributions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._distroHistory
                          .where((distro) => distro['current_flag'] == false)
                          .map((distro) => _buildPreviousDistroItem(distro)),
                      const SizedBox(height: 16),
                    ],
                    // Add New Distro Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showAddDistroDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Distro'),
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
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.zero,
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportAsJson,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export JSON'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportAsCsv,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDistroItem(Map<String, dynamic> distro) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.radio_button_checked, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distro['distro_name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Started: ${distro['start_date'].toLocal().toString().split(' ')[0]}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'CURRENT',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousDistroItem(Map<String, dynamic> distro) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.radio_button_unchecked, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distro['distro_name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${distro['start_date'].toLocal().toString().split(' ')[0]} - ${distro['end_date']?.toLocal().toString().split(' ')[0] ?? 'Present'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddDistroDialog extends StatefulWidget {
  final Function(String, DateTime) onSave;

  const AddDistroDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<AddDistroDialog> createState() => _AddDistroDialogState();
}

class _AddDistroDialogState extends State<AddDistroDialog> {
  final _distroController = TextEditingController();
  DateTime? _startDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _distroController.dispose();
    super.dispose();
  }

  void _saveDistro() {
    final distroName = _distroController.text.trim();
    if (distroName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a distribution name')),
      );
      return;
    }

    widget.onSave(distroName, _startDate!);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Add New Distribution',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom Distro Input
          TextFormField(
            controller: _distroController,
            decoration: const InputDecoration(
              labelText: 'Distribution Name',
              hintText: 'e.g., Ubuntu, Arch Linux, Fedora',
              prefixIcon: Icon(Icons.computer),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          // Start Date
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _startDate = date;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Start Date',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                _startDate?.toLocal().toString().split(' ')[0] ?? 'Select date',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: Your current distro will be set to end today',
            style: TextStyle(
              color: Colors.orange[300],
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveDistro,
          child: const Text('Add Distro'),
        ),
      ],
    );
  }
}