import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
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
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    
    // Add listener to username controller for auto-save
    _usernameController.addListener(() {
      _scheduleAutoSave();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _autoSaveTimer?.cancel();
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

  void _scheduleAutoSave() {
    // Cancel existing timer
    _autoSaveTimer?.cancel();
    
    // Start new timer for auto-save after 2 seconds of inactivity
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _autoSaveProfile();
    });
  }

  Future<void> _autoSaveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
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
          // Don't save if username is taken
          return;
        }
      }

      // Save profile settings
      await Supabase.instance.client
        .from('profiles')
        .upsert({'id': user.id, 'username': username, 'public_profile': _publicProfile});

    } catch (e) {
      // Silently fail for auto-save
    } finally {
      if (mounted) {
        setState(() {
        });
      }
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
      final bool hasCurrentDistro = currentDistroIndex != -1;
      
      if (hasCurrentDistro) {
        final currentDistro = _distroHistory[currentDistroIndex];
        try {
          final updateResult = await Supabase.instance.client
              .from('distro_history')
              .update({
                'end_date': currentDate.toIso8601String().split('T')[0],
                'current_flag': false,
              })
              .eq('id', currentDistro['id']);
          
          if (updateResult.isEmpty) {
            // Log warning but continue - this might happen if record was already updated
            debugPrint('Warning: Could not update current distro (might be already updated)');
          }
        } catch (updateError) {
          debugPrint('Error updating current distro: $updateError');
          // Continue anyway - we still want to add the new distro
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Could not update previous distro end date, but new distro will be added.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
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
          SnackBar(
            content: Text(hasCurrentDistro 
              ? 'Distro switched successfully!' 
              : 'First distro added successfully!'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add new distro. Please try again.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _showDeleteAccountDialog() {
    Navigator.of(context).pop(); // Close the settings bottom sheet
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account deletion is a permanent action that cannot be undone.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'To delete your account, please email:',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'thomasnowprod@proton.me',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Please include:\n'
              '• Your registered email address\n'
              '• Subject: "Account Deletion Request"\n'
              '• Confirmation that you want to delete your account',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Note: You will receive a confirmation email before the deletion is processed.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please check your email app to send the deletion request.'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Open Email'),
          ),
        ],
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Username Section
              Card(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Username',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
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
              const SizedBox(height: 16),
              
              // Profile Settings Section
              Card(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Profile Settings',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Make profile public'),
                        subtitle: const Text('Allow others to view your distro history'),
                        value: _publicProfile,
                        onChanged: (value) {
                          setState(() => _publicProfile = value);
                          _scheduleAutoSave();
                        },
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Export and Action Buttons
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
              
              // Account Actions
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Supabase.instance.client.auth.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Delete Account Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showDeleteAccountDialog,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      floatingActionButton: FloatingActionButton(
        onPressed: _showSettingsBottomSheet,
        backgroundColor: Colors.green,
        child: const Icon(Icons.settings, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildCurrentDistroItem(
                            _distroHistory.firstWhere((distro) => distro['current_flag'] == true)
                          ),
                        ),
                      ],
                      // Previous Distros
                      if (_distroHistory.any((distro) => distro['current_flag'] == false)) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Previous Distributions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        ..._distroHistory
                            .where((distro) => distro['current_flag'] == false)
                            .map((distro) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: _buildPreviousDistroItem(distro),
                                )),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentDistroItem(Map<String, dynamic> distro) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 8),
            Text(
              'Started: ${distro['start_date'].toLocal().toString().split(' ')[0]}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'CURRENT',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousDistroItem(Map<String, dynamic> distro) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 8),
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