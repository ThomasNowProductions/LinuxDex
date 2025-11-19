import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsBody extends StatefulWidget {
  const StatisticsBody({super.key});

  @override
  State<StatisticsBody> createState() => _StatisticsBodyState();
}

class _StatisticsBodyState extends State<StatisticsBody> {
  List<Map<String, dynamic>> _popularDistros = [];
  double _averageSwitchFrequency = 0.0;
  Map<String, double> _averageLengths = {};
  Map<String, int> _activeUsers = {};
  int _totalUsers = 0;
  int _totalDistros = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all distro history to compute statistics
      final allHistory = await Supabase.instance.client
          .from('distro_history')
          .select('distro_name, user_id, start_date, end_date, current_flag');

      final distroCounts = <String, int>{};
      final userSwitchCounts = <String, int>{};
      final userTotalDays = <String, int>{};
      final distroDurations = <String, List<int>>{};
      final activeUsersMap = <String, int>{};
      final uniqueUsers = <String>{};
      final uniqueDistros = <String>{};

      for (final item in allHistory) {
        final distro = item['distro_name'] as String;
        final userId = item['user_id'] as String;
        uniqueUsers.add(userId);
        uniqueDistros.add(distro);
        distroCounts[distro] = (distroCounts[distro] ?? 0) + 1;

        // Count switches per user
        userSwitchCounts[userId] = (userSwitchCounts[userId] ?? 0) + 1;

        // Calculate total days for average frequency
        final startDate = DateTime.parse(item['start_date']);
        final endDate = item['end_date'] != null ? DateTime.parse(item['end_date']) : DateTime.now();
        final days = endDate.difference(startDate).inDays;
        userTotalDays[userId] = (userTotalDays[userId] ?? 0) + days;

        // For average length per distro (only completed periods)
        if (item['current_flag'] == false && item['end_date'] != null) {
          distroDurations[distro] ??= [];
          distroDurations[distro]!.add(days);
        }

        // For active users per distro (current_flag = true)
        if (item['current_flag'] == true) {
          activeUsersMap[distro] = (activeUsersMap[distro] ?? 0) + 1;
        }
      }

      // Sort popular distros
      final sortedDistros = distroCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Calculate average switch frequency (switches per year)
      double totalFrequency = 0.0;
      int userCount = 0;
      for (final userId in userSwitchCounts.keys) {
        final switches = userSwitchCounts[userId]!;
        final totalDays = userTotalDays[userId]!;
        if (totalDays > 0) {
          final years = totalDays / 365.0;
          final frequency = switches / years;
          totalFrequency += frequency;
          userCount++;
        }
      }
      final avgFrequency = userCount > 0 ? totalFrequency / userCount : 0.0;

      // Compute average lengths
      final averageLengths = <String, double>{};
      for (final entry in distroDurations.entries) {
        final durations = entry.value;
        if (durations.isNotEmpty) {
          final avg = durations.reduce((a, b) => a + b) / durations.length;
          averageLengths[entry.key] = avg;
        }
      }

      setState(() {
        _popularDistros = sortedDistros.take(10).map((e) => {'distro': e.key, 'count': e.value}).toList();
        _averageSwitchFrequency = avgFrequency;
        _averageLengths = averageLengths;
        _activeUsers = activeUsersMap;
        _totalUsers = uniqueUsers.length;
        _totalDistros = uniqueDistros.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load statistics.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Statistics'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      SizedBox(
                        height: 100,
                        child: Row(
                          children: [
                            Expanded(child: _buildSummaryCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue)),
                            Expanded(child: _buildSummaryCard('Total Distros', _totalDistros.toString(), Icons.computer, Colors.green)),
                            Expanded(child: _buildSummaryCard('Avg Switch Freq', '${_averageSwitchFrequency.toStringAsFixed(1)}/year', Icons.swap_horiz, Colors.orange)),
                            Expanded(child: _buildSummaryCard('Active Periods', _popularDistros.length.toString(), Icons.timeline, Colors.purple)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Popular Distros Chart
                      Card(
                        color: Colors.grey[900],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Most Popular Distros',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: _popularDistros.isNotEmpty ? _popularDistros.first['count'] * 1.2 : 10,
                                    barGroups: _popularDistros.asMap().entries.map((e) {
                                      final index = e.key;
                                      final distro = e.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (distro['count'] as int).toDouble(),
                                            color: Colors.green,
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < _popularDistros.length) {
                                              return Text(
                                                _popularDistros[index]['distro'],
                                                style: const TextStyle(fontSize: 10),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: true),
                                      ),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._popularDistros.map((distro) => ListTile(
                                title: Text(distro['distro']),
                                trailing: Text('${distro['count']} users'),
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Distro Details
                      Text(
                        'Distro Details',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      ..._popularDistros.map((distro) {
                        final name = distro['distro'];
                        final avgLength = _averageLengths[name] ?? 0.0;
                        final active = _activeUsers[name] ?? 0;
                        return Card(
                          color: Colors.grey[850],
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text('Avg Length: ${avgLength.toStringAsFixed(1)} days\nActive Users: $active'),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}