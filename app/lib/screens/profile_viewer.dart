import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfileViewer extends StatefulWidget {
  const ProfileViewer({super.key});

  @override
  State<ProfileViewer> createState() => _ProfileViewerState();
}

class _ProfileViewerState extends State<ProfileViewer> {
  final _usernameController = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loadProfile() async {
    final username = _usernameController.text.trim();
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
      final response = await http.get(Uri.parse('/api/$username'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Failed to load profile';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please try again.';
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
      appBar: AppBar(title: const Text('View Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username (Email)'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _loadProfile, child: const Text('View Profile')),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_isLoading)
              const CircularProgressIndicator(),
            if (_history.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Card(
                      color: item['current_flag'] ? Colors.green[50] : null,
                      child: ListTile(
                        title: Text(item['distro_name']),
                        subtitle: Text('${item['start_date']} - ${item['end_date'] ?? 'Current'}'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}